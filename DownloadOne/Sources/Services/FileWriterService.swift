import Foundation

struct FileWriterService {
    func write(result: DownloadResult, loggedInUser: String) throws {
        let fm = FileManager.default
        let dirPath = result.outputURL.path

        try fm.createDirectory(atPath: dirPath, withIntermediateDirectories: true)

        let xmlPath = result.outputURL.appendingPathComponent("record.xml").path
        try result.xmlRecord.write(toFile: xmlPath, atomically: true, encoding: .utf8)

        let scriptPath = result.outputURL.appendingPathComponent("script.\(result.fileExtension)").path
        try result.scriptBody.write(toFile: scriptPath, atomically: true, encoding: .utf8)

        chown(path: dirPath, user: loggedInUser)
        chown(path: xmlPath, user: loggedInUser)
        chown(path: scriptPath, user: loggedInUser)
    }

    private func chown(path: String, user: String) {
        try? FileManager.default.setAttributes(
            [.ownerAccountName: user],
            ofItemAtPath: path
        )
    }
}
