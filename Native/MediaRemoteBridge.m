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

static void *mr(const char *name) {
    static void *handle = NULL;
    if (!handle) {
        handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY);
    }
    return handle ? dlsym(handle, name) : NULL;
}

static NSString *lastArtworkDigest = nil;
static NSString *lastArtworkPath = nil;
static NSString *lastItemID = nil;
static NSString *lastIdentity = nil;
static NSString *blockedArtwork = nil;

static void snapshot(void (^done)(void));

static NSString *resolvedName(const char *symbol) {
    CFStringRef *slot = (CFStringRef *)mr(symbol);
    return (slot && *slot) ? (__bridge NSString *)(*slot) : [NSString stringWithUTF8String:symbol];
}

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
    NSString *itemID = info[@"kMRMediaRemoteNowPlayingInfoContentItemIdentifier"] ?: @"";
    NSString *identity = [NSString stringWithFormat:@"%@|%@|%@|%@", title ?: @"", artist ?: @"", album ?: @"", itemID];
    BOOL sameItem = lastIdentity.length > 0 && [identity isEqualToString:lastIdentity];
    for (id key in info) {
        id value = info[key];
        if ([value isKindOfClass:[NSURL class]]) {
            out[@"url"] = [(NSURL *)value absoluteString];
            break;
        }
        if ([value isKindOfClass:[NSString class]] && [(NSString *)value hasPrefix:@"http"]) {
            out[@"url"] = value;
            break;
        }
    }
    NSString *art = artworkPath(info[@"kMRMediaRemoteNowPlayingInfoArtworkData"], info[@"kMRMediaRemoteNowPlayingInfoArtworkMIMEType"] ?: @"");
    if (sameItem) {
        // Pause/resume of the same session must keep the poster. Empty snapshots are common.
        if (!art) art = lastArtworkPath;
        if (art) out[@"artwork"] = art;
        blockedArtwork = nil;
    } else {
        BOOL reusedPrevious = art && lastArtworkPath && [art isEqualToString:lastArtworkPath];
        if (!art || reusedPrevious) {
            out[@"artworkStale"] = @YES;
            if (reusedPrevious) {
                blockedArtwork = art;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ snapshot(nil); });
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ snapshot(nil); });
            }
        } else {
            blockedArtwork = nil;
            out[@"artwork"] = art;
        }
        lastIdentity = identity;
    }
    lastItemID = itemID;
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
        // A notification that arrives during the quiet period used to be discarded, which is
        // how a new title kept the previous video's poster.
        __block BOOL waiting = NO;
        __block BOOL again = NO;
        __weak __block void (^weakRefresh)(void) = nil;
        void (^refresh)(void) = ^{
            if (waiting) {
                again = YES;
                return;
            }
            waiting = YES;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 80 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                waiting = NO;
                snapshot(nil);
                if (again) {
                    again = NO;
                    weakRefresh();
                }
            });
        };
        weakRefresh = refresh;
        NSMutableArray *names = [NSMutableArray arrayWithObjects:
            @"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
            @"kMRMediaRemoteNowPlayingApplicationPlaybackStateDidChangeNotification",
            @"kMRPlaybackQueueContentItemArtworkChangedNotification",
            @"kMRPlayerPlaybackQueueContentItemArtworkChangedNotification",
            nil];
        for (NSUInteger index = 0; index < names.count; index++) {
            names[index] = resolvedName([names[index] UTF8String]);
        }
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
        MRRegister reg = (MRRegister)mr("MRMediaRemoteRegisterForNowPlayingNotifications");
        if (reg) reg(dispatch_get_main_queue());
        // The command is delivered to mediaremoted asynchronously. Returning here used to let
        // perl exit before that message left the process, so play, pause and next did nothing.
        dispatch_async(dispatch_get_main_queue(), ^{
            MRSendCommand send = (MRSendCommand)mr("MRMediaRemoteSendCommand");
            if (send && [command hasPrefix:@"seek:"]) {
                // Command 24 is SeekToPlaybackPosition, which Chrome and YouTube advertise.
                NSString *key = resolvedName("kMRMediaRemoteOptionPlaybackPosition");
                NSDictionary *options = @{key: @([command substringFromIndex:5].doubleValue)};
                send(24, (__bridge CFDictionaryRef)options);
            } else if (send) {
                send(command.intValue, NULL);
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                exit(0);
            });
        });
        dispatch_main();
    }
}
