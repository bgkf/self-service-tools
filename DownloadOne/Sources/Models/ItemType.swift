import Foundation

enum ItemType: String, CaseIterable, Identifiable {
    case script = "Script"
    case extensionAttribute = "Extension Attribute"

    var id: String { rawValue }

    var apiPath: String {
        switch self {
        case .script:
            return "JSSResource/scripts/id"
        case .extensionAttribute:
            return "JSSResource/computerextensionattributes/id"
        }
    }

    var rootElement: String {
        switch self {
        case .script:
            return "script"
        case .extensionAttribute:
            return "computer_extension_attribute"
        }
    }
}

struct DownloadResult {
    let name: String
    let xmlRecord: String
    let scriptBody: String
    let fileExtension: String
    let outputURL: URL
}
