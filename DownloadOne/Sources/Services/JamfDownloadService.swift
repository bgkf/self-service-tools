import Foundation

struct JamfDownloadService {
    private let baseURL = "https://acmedev.jamfcloud.com"

    func download(itemType: ItemType, id: Int, token: String) async throws -> DownloadResult {
        var request = URLRequest(url: URL(string: "\(baseURL)/\(itemType.apiPath)/\(id)")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/xml", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DownloadOneError.downloadFailed("No HTTP response.")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                throw DownloadOneError.itemNotFound(id)
            }
            throw DownloadOneError.downloadFailed("HTTP \(httpResponse.statusCode)")
        }

        let xmlDoc = try XMLDocument(data: data, options: [])

        guard let root = xmlDoc.rootElement() else {
            throw DownloadOneError.xmlParsingFailed
        }

        let name = try extractName(from: root)
        let scriptBody = try extractScript(from: root, itemType: itemType)
        let shebang = scriptBody.components(separatedBy: "\n").first ?? ""
        let ext = scriptExtension(forShebang: shebang)

        let cleanedXML = try buildCleanedXML(xmlDoc: xmlDoc, itemType: itemType)

        let outputURL = URL(fileURLWithPath: "/Users/Shared/\(name)")

        return DownloadResult(
            name: name,
            xmlRecord: cleanedXML,
            scriptBody: scriptBody.replacingOccurrences(of: "\r", with: ""),
            fileExtension: ext,
            outputURL: outputURL
        )
    }

    private func extractName(from root: XMLElement) throws -> String {
        guard let nameNode = try root.nodes(forXPath: "name").first,
              let name = nameNode.stringValue, !name.isEmpty else {
            throw DownloadOneError.xmlParsingFailed
        }
        return name
    }

    private func extractScript(from root: XMLElement, itemType: ItemType) throws -> String {
        let xpath: String
        switch itemType {
        case .script:
            xpath = "script_contents"
        case .extensionAttribute:
            xpath = "input_type/script"
        }

        guard let node = try root.nodes(forXPath: xpath).first,
              let script = node.stringValue, !script.isEmpty else {
            throw DownloadOneError.xmlParsingFailed
        }
        return script
    }

    private func buildCleanedXML(xmlDoc: XMLDocument, itemType: ItemType) throws -> String {
        let copy = try XMLDocument(xmlString: xmlDoc.xmlString, options: [])
        guard let root = copy.rootElement() else {
            throw DownloadOneError.xmlParsingFailed
        }

        let nodesToRemove: [String]
        switch itemType {
        case .script:
            nodesToRemove = ["id", "script_contents", "script_contents_encoded", "filename"]
        case .extensionAttribute:
            nodesToRemove = ["id", "input_type/script"]
        }

        for xpath in nodesToRemove {
            if let nodes = try? root.nodes(forXPath: xpath) {
                for node in nodes {
                    node.detach()
                }
            }
        }

        return copy.xmlString(options: [.nodePrettyPrint])
    }
}
