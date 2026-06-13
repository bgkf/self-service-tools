import Foundation

struct ShellResult {
    let exitCode: Int32
    let output: String
}

@discardableResult
func shell(_ command: String) -> ShellResult {
    let process = Process()
    let pipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-c", command]
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return ShellResult(exitCode: -1, output: error.localizedDescription)
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    return ShellResult(exitCode: process.terminationStatus, output: output.trimmingCharacters(in: .whitespacesAndNewlines))
}
