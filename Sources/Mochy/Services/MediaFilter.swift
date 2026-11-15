import Foundation

/// Expands each hidden-site entry so a name the person typed also covers the site's other addresses.
enum MediaFilter {
    private static let groups: [[String]] = [
        ["x.com", "twitter.com", "mobile.twitter.com", "x", "twitter"],
        ["reddit.com", "old.reddit.com", "reddit"],
        ["instagram.com", "instagr.am", "instagram"],
        ["youtube.com", "youtu.be", "m.youtube.com", "youtube"],
        ["tiktok.com", "tiktok"],
        ["facebook.com", "fb.com", "fb.watch", "facebook"],
        ["threads.net", "threads"],
        ["snapchat.com", "snapchat"],
        ["twitch.tv", "twitch"],
        ["vimeo.com", "vimeo"],
    ]

    /// True when the page address belongs to one of the allowed sites, including known aliases such as youtu.be for youtube.com.
    static func allows(entries: [String], page: String) -> Bool {
        let host = normalize(page)
        guard !host.isEmpty, !entries.isEmpty else { return false }
        let allowed = Set(entries.flatMap(tokens(for:)))
        let address = page.lowercased()
        return allowed.contains { token in
            host == token || host.hasSuffix("." + token) || (token.contains(".") && address.contains(token))
        }
    }

    static func blocks(entries: [String], fields: [String]) -> Bool {
        let haystack = fields.joined(separator: "\n").lowercased()
        guard !haystack.isEmpty else { return false }
        let tokens = Set(entries.flatMap(tokens(for:)))
        return tokens.contains { matches(haystack, token: $0) }
    }

    static func tokens(for raw: String) -> [String] {
        let host = normalize(raw)
        guard !host.isEmpty else { return [] }
        var tokens = [host]
        let parts = host.split(separator: ".").map(String.init)
        if parts.count >= 2 {
            tokens.append(parts.suffix(2).joined(separator: "."))
            tokens.append(parts[0])
        }
        let core = Set(tokens)
        for group in groups where group.contains(where: { core.contains($0) }) {
            tokens.append(contentsOf: group)
        }
        return tokens.map { $0.lowercased() }.filter { $0.count >= 1 && $0 != "www" && $0 != "com" }
    }

    static func normalize(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else { return "" }
        let candidate = value.contains("://") ? value : "https://\(value)"
        if let host = URL(string: candidate)?.host, !host.isEmpty {
            value = host
        } else {
            value = value.split(separator: "/").first.map(String.init) ?? value
        }
        if value.hasPrefix("www.") { value = String(value.dropFirst(4)) }
        return value
    }

    private static func matches(_ haystack: String, token: String) -> Bool {
        if token.contains(".") || token.count >= 4 { return haystack.contains(token) }
        let pattern = "(^|[^a-z0-9])\(NSRegularExpression.escapedPattern(for: token))([^a-z0-9]|$)"
        return haystack.range(of: pattern, options: .regularExpression) != nil
    }
}

/// Finds the browser tab that matches the current Now Playing title so a hidden site still matches when the player omits the page address.
enum BrowserPage {
    private static let chromium: [String: String] = [
        "com.google.Chrome": "Google Chrome",
        "com.google.Chrome.beta": "Google Chrome Beta",
        "com.brave.Browser": "Brave Browser",
        "com.microsoft.edgemac": "Microsoft Edge",
        "com.operasoftware.Opera": "Opera",
        "company.thebrowser.Browser": "Arc",
    ]

    static func isBrowser(_ bundleID: String) -> Bool {
        bundleID == "com.apple.Safari" || chromium[bundleID] != nil
    }

    static func lookup(bundleID: String, mediaTitle: String) -> String? {
        let needle = mediaTitle
            .replacingOccurrences(of: "\\", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .prefix(80)
        guard needle.count >= 3 else { return nil }
        let script: String
        if bundleID == "com.apple.Safari" {
            script = """
            tell application "Safari"
              if (count of windows) is 0 then return ""
              repeat with w in windows
                repeat with t in tabs of w
                  try
                    set n to name of t
                    if (count of n) >= 4 and (n contains "\(needle)" or "\(needle)" contains n) then return URL of t
                  end try
                end repeat
              end repeat
              return ""
            end tell
            """
        } else if let app = chromium[bundleID] {
            script = """
            tell application "\(app)"
              if (count of windows) is 0 then return ""
              repeat with w in windows
                repeat with t in tabs of w
                  try
                    set n to title of t
                    if (count of n) >= 4 and (n contains "\(needle)" or "\(needle)" contains n) then return URL of t
                  end try
                end repeat
              end repeat
              return ""
            end tell
            """
        } else {
            return nil
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do { try task.run() } catch { return nil }
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return nil }
        let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }
}
