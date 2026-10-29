#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#include <CommonCrypto/CommonDigest.h>
#include <dlfcn.h>
#include <stdio.h>

// MediaRemote only answers entitled processes since macOS 15.4. /usr/bin/perl is
// one of them, so the app runs this library inside perl (Resources/mediaremote.pl)
// and reads newline-delimited JSON from its stdout.

typedef void (*MRGetInfo)(dispatch_queue_t, void (^)(CFDictionaryRef));
typedef void (*MRGetPID)(dispatch_queue_t, void (^)(int));
typedef void (*MRGetIsPlaying)(dispatch_queue_t, void (^)(Boolean));
typedef void (*MRRegister)(dispatch_queue_t);
typedef Boolean (*MRSendCommand)(int, CFDictionaryRef);
typedef void (*MRSetElapsed)(double);

static void *mr(const char *name) {
    static void *handle = NULL;
    if (!handle) {
        handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY);
    }
    return handle ? dlsym(handle, name) : NULL;
}

static NSString *lastArtworkDigest = nil;
static NSString *lastArtworkPath = nil;

static NSString *artworkPath(NSData *data, NSString *mime) {
    if (data.length == 0) return nil;
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hex = [NSMutableString string];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
    if ([hex isEqualToString:lastArtworkDigest]) return lastArtworkPath;
    NSString *ext = [mime containsString:@"png"] ? @"png" : @"jpg";
    NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"mochy-artwork"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    if (lastArtworkPath) [[NSFileManager defaultManager] removeItemAtPath:lastArtworkPath error:nil];
    NSString *path = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", hex, ext]];
    [data writeToFile:path atomically:YES];
    lastArtworkDigest = hex;
    lastArtworkPath = path;
    return path;
}

static void emit(NSDictionary *info, int pid, BOOL playing) {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    out[@"playing"] = @(playing);
    out[@"pid"] = @(pid);
    NSRunningApplication *app = pid > 0 ? [NSRunningApplication runningApplicationWithProcessIdentifier:pid] : nil;
    if (app.bundleIdentifier) out[@"bundle"] = app.bundleIdentifier;
    if (app.localizedName) out[@"app"] = app.localizedName;
    NSString *title = info[@"kMRMediaRemoteNowPlayingInfoTitle"];
    if (title) out[@"title"] = title;
    NSString *artist = info[@"kMRMediaRemoteNowPlayingInfoArtist"];
    if (artist) out[@"artist"] = artist;
    NSString *album = info[@"kMRMediaRemoteNowPlayingInfoAlbum"];
    if (album) out[@"album"] = album;
    NSNumber *duration = info[@"kMRMediaRemoteNowPlayingInfoDuration"];
    if (duration) out[@"duration"] = duration;
    NSNumber *elapsed = info[@"kMRMediaRemoteNowPlayingInfoElapsedTime"];
    if (elapsed) out[@"elapsed"] = elapsed;
    NSNumber *rate = info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"];
    if (rate) out[@"rate"] = rate;
    NSDate *stamp = info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
    out[@"timestamp"] = @((stamp ?: [NSDate date]).timeIntervalSince1970);
    NSString *art = artworkPath(info[@"kMRMediaRemoteNowPlayingInfoArtworkData"], info[@"kMRMediaRemoteNowPlayingInfoArtworkMIMEType"] ?: @"");
    if (art) out[@"artwork"] = art;
    NSData *json = [NSJSONSerialization dataWithJSONObject:out options:0 error:nil];
    if (!json) return;
    fwrite(json.bytes, 1, json.length, stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

static void snapshot(void (^done)(void)) {
    MRGetInfo getInfo = (MRGetInfo)mr("MRMediaRemoteGetNowPlayingInfo");
    MRGetPID getPID = (MRGetPID)mr("MRMediaRemoteGetNowPlayingApplicationPID");
    MRGetIsPlaying getPlaying = (MRGetIsPlaying)mr("MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    if (!getInfo) {
        fputs("{\"error\":\"MediaRemote unavailable\"}\n", stdout);
        fflush(stdout);
        if (done) done();
        return;
    }
    dispatch_queue_t queue = dispatch_get_main_queue();
    getInfo(queue, ^(CFDictionaryRef raw) {
        NSDictionary *info = [(__bridge NSDictionary *)raw copy] ?: @{};
        void (^finish)(int) = ^(int pid) {
            if (getPlaying) {
                getPlaying(queue, ^(Boolean playing) {
                    emit(info, pid, playing);
                    if (done) done();
                });
            } else {
                NSNumber *rate = info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"];
                emit(info, pid, rate.doubleValue > 0);
                if (done) done();
            }
        };
        if (getPID) getPID(queue, ^(int pid) { finish(pid); });
        else finish(0);
    });
}

void mochy_get(void *interp, void *cv) {
    @autoreleasepool {
        snapshot(^{ exit(0); });
        dispatch_main();
    }
}

void mochy_stream(void *interp, void *cv) {
    @autoreleasepool {
        MRRegister reg = (MRRegister)mr("MRMediaRemoteRegisterForNowPlayingNotifications");
        if (reg) reg(dispatch_get_main_queue());
        NSArray *names = @[
            @"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
            @"kMRMediaRemoteNowPlayingApplicationClientStateDidChange",
        ];
        __block BOOL pending = NO;
        void (^refresh)(void) = ^{
            if (pending) return;
            pending = YES;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 80 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                pending = NO;
                snapshot(nil);
            });
        };
        for (NSString *name in names) {
            [[NSNotificationCenter defaultCenter] addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *note) { refresh(); }];
        }
        // Exit when the app closes our stdin pipe.
        dispatch_source_t input = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, STDIN_FILENO, 0, dispatch_get_main_queue());
        dispatch_source_set_event_handler(input, ^{
            char buffer[64];
            if (read(STDIN_FILENO, buffer, sizeof buffer) <= 0) exit(0);
        });
        dispatch_resume(input);
        snapshot(nil);
        dispatch_main();
    }
}

void mochy_send(void *interp, void *cv) {
    @autoreleasepool {
        const char *arg = getenv("MOCHY_ARG");
        NSString *command = arg ? [NSString stringWithUTF8String:arg] : @"";
        if ([command hasPrefix:@"seek:"]) {
            MRSetElapsed setElapsed = (MRSetElapsed)mr("MRMediaRemoteSetElapsedTime");
            if (setElapsed) setElapsed([[command substringFromIndex:5] doubleValue]);
        } else {
            MRSendCommand send = (MRSendCommand)mr("MRMediaRemoteSendCommand");
            if (send) send(command.intValue, NULL);
        }
        // Give mediaremoted a moment to receive the message before perl exits.
        usleep(150 * 1000);
    }
}
