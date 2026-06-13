import Foundation
import SystemConfiguration

enum ElevationError: Error, CustomStringConvertible {
    case promotionFailed(String)
    case reversionFailed(String)
    case noConsoleUser

    var description: String {
        switch self {
        case .promotionFailed(let msg): return "Admin promotion failed: \(msg)"
        case .reversionFailed(let msg): return "Admin reversion failed: \(msg)"
        case .noConsoleUser: return "Could not determine the logged-in user"
        }
    }
}

enum ElevationManager {

    static func consoleUsername() throws -> String {
        var uid: uid_t = 0
        guard let user = SCDynamicStoreCopyConsoleUser(nil, &uid, nil) as String?,
              user != "loginwindow", !user.isEmpty else {
            throw ElevationError.noConsoleUser
        }
        return user
    }

    static func elevate() throws {
        let user = try consoleUsername()
        let result = shell("/usr/bin/sudo /usr/sbin/dseditgroup -o edit -a \(user) -t user admin")
        guard result.exitCode == 0 else {
            throw ElevationError.promotionFailed(result.output)
        }
        NSLog("NotionAudioEnabler: Elevated user '%@' to admin", user)
    }

    static func revert() throws {
        let user = try consoleUsername()
        let result = shell("/usr/bin/sudo /usr/sbin/dseditgroup -o edit -d \(user) -t user admin")
        guard result.exitCode == 0 else {
            throw ElevationError.reversionFailed(result.output)
        }
        NSLog("NotionAudioEnabler: Reverted user '%@' to standard", user)
    }

    static func isAdmin() -> Bool {
        guard let user = try? consoleUsername() else { return false }
        let result = shell("/usr/sbin/dseditgroup -o checkmember -m \(user) admin")
        return result.exitCode == 0
    }
}
