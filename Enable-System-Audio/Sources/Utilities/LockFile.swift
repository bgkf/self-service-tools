import Foundation

enum LockFile {
    static let path = "/tmp/notion-audio-enabler.lock"

    static func acquire() -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: path) {
            if let contents = try? String(contentsOfFile: path, encoding: .utf8),
               let pid = Int32(contents.trimmingCharacters(in: .whitespacesAndNewlines)) {
                if kill(pid, 0) == 0 {
                    return false
                }
            }
        }
        try? "\(ProcessInfo.processInfo.processIdentifier)".write(
            toFile: path, atomically: true, encoding: .utf8
        )
        return true
    }

    static func release() {
        try? FileManager.default.removeItem(atPath: path)
    }
}
