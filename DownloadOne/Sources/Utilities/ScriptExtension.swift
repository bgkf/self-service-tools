import Foundation

func scriptExtension(forShebang shebang: String) -> String {
    switch true {
    case shebang.contains("python"):     return "py"
    case shebang.contains("swift"):      return "swift"
    case shebang.contains("perl"):       return "pl"
    case shebang.contains("ruby"):       return "rb"
    case shebang.contains("osascript"):  return "applescript"
    case shebang.contains("zsh"):        return "zsh"
    default:                             return "sh"
    }
}
