import Foundation
import RegexBuilder

enum DirectiveType: CustomStringConvertible {
    case path
    case arch
    case objectFiles
    case sections
    case symbols
    case deadStrippedSymbols
    
    public static func from(string: String) -> Self? {
        let trimmed = string.dropFirst(2)
        switch trimmed.prefix(4) {
        case "Path":
            return .path
        case "Arch":
            return .arch
        case "Obje":
            return .objectFiles
        case "Sect":
            return .sections
        case "Symb":
            return .symbols
        case "Dead":
            return .deadStrippedSymbols
        default:
            return nil
        }
    }
    
    public var description: String {
        switch self {
            
        case .path: return "Path"
        case .arch: return "Arch"
        case .objectFiles: return "Object Files"
        case .sections: return "Sections"
        case .symbols: return "Symbols"
        case .deadStrippedSymbols: return "Dead Stripped Symbols"
        }
    }
}

struct Directive: CustomStringConvertible {
    public let type: DirectiveType
    public let offset: Int
    
    var description: String { "[\(offset)] \(type)" }
}

struct ObjectFile: CustomStringConvertible, Equatable, Comparable {
    
    // A Regex that matches files in the main app bundle.
    static let appObjRegex = Regex {
        "["
        ZeroOrMore(.whitespace)
        Capture {
          OneOrMore(.digit)
        } transform: { Int($0)! }
        "]"
        OneOrMore(.any, .reluctant)
        "/Intermediates.noindex/"
        Capture {
          OneOrMore(.word)
        } transform: { String($0) }
        ".build"
        OneOrMore(.any, .reluctant)
        "/arm64/"
        Capture {
          OneOrMore(.word)
        } transform: { String($0) }
        ".o"
      }

    /// A Regex that matches files found in libraries.
    static let libObjRegex = Regex {
        "["
        ZeroOrMore(.whitespace)
        Capture {
          OneOrMore(.digit)
        } transform: { Int($0)! }
        "]"
        OneOrMore(.any, .reluctant)
        ChoiceOf {
            "Debug-iphoneos/"
            "Debug-iphonesimulator/"
        }
        Capture {
          OneOrMore(.word)
        } transform: { String($0) }
        "/"
        OneOrMore(.any, .reluctant)
        "("
        Capture {
          OneOrMore(.word)
        } transform: { String($0) }
        ".o)"
      }

    let index: Int
    let module: String
    let file: String
    var symbols: [Symbol] = []
    
    private(set) var size: Int = 0
    
    var sizeReport: String {
        "\(file) (\(size))"
    }
    
    mutating func add(symbols: [Symbol]) {
        self.symbols.append(contentsOf: symbols)
        self.size = self.symbols.map(\.size).reduce(0, +)
    }
    
    var description: String { "ObjectFile { index: \(index), module: \(module), file: \(file), symbols.count: \(symbols.count) }" }
    
    static func == (lhs: ObjectFile, rhs: ObjectFile) -> Bool { lhs.index == rhs.index }
    static func < (lhs: ObjectFile, rhs: ObjectFile) -> Bool { rhs.file < lhs.file }
}

struct Symbol: CustomStringConvertible {
    
    /// A Regex that matches key fields in the Link Map's Symbols section.
    static let symbolRegex = Regex {
        "0x"
        Capture {
            OneOrMore(.hexDigit)
        } transform: { str in
            Int(str, radix: 16)!
        }
        OneOrMore(.whitespace)
        "0x"
        Capture {
            OneOrMore(.hexDigit)
        } transform: { str in
            Int(str, radix: 16)!
        }
        OneOrMore(.whitespace)
        "["
        ZeroOrMore(.whitespace)
        Capture {
            OneOrMore(.digit)
        } transform: { str in
            Int(str)!
        }
        "] "
        Capture {
            OneOrMore(.anyNonNewline)
        } transform: { String($0) }
    }
    
    let address: Int
    let size: Int
    let fileIndex: Int
    let name: String
    
    public var description: String { "Symbol { address: \(String(address, radix: 16)), size: \(size), fileIndex: \(fileIndex) }"}
}

struct Module: CustomStringConvertible, Comparable {
    let name: String
    let files: [ObjectFile]
    
    private(set) var size: Int = 0
    
    func sizeReport(includeFiles: Bool = true, csvOutput: Bool = false) -> String {
        if csvOutput {
            if includeFiles {
                return files.reduce(into: "") { partialResult, file in
                    partialResult += "\(name),\(file.file),\(file.size)\n"
                }
            } else {
                return "\(name),,\(size)"
            }
        } else {
            var str = "\(name) (\(size))"
            if includeFiles {
                files.forEach { str += "\n\t\($0.sizeReport)" }
            }
            return str
        }
    }
    
    init(name: String, files: [ObjectFile]) {
        self.name = name
        self.files = files
        self.size = files.map(\.size).reduce(0, +)
    }
    
    var description: String { "Module { name: \(name), files.count: \(files.count) }" }
    
    static func < (lhs: Module, rhs: Module) -> Bool { lhs.name < rhs.name }
}

