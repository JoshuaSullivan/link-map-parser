import Foundation

struct Analyzer {

    enum Error: Swift.Error {
        case couldNotLoadLinkMap
    }

    static func analyze(linkMapUrl: URL, printFileSymbols: String? = nil, verbose: Bool = false) throws {
        print("Loading map file...")
        let linkMapString = try String(contentsOf: linkMapUrl, encoding: .ascii)
        print("Splitting into lines...")
        let lines = linkMapString.split(separator: "\n")
        print("Got \(lines.count) lines.")
        let directives = lines.enumerated()
            .filter { index, line -> Bool in line.prefix(1) == "#" }
            .compactMap { index, text -> Directive? in
                guard let type = DirectiveType.from(string: String(text)) else { return nil }
                return Directive(type: type, offset: index)
            }
        
        // Parse the Object Files
        guard
            let objDir = directives.first(where: { $0.type == .objectFiles }),
            let sectionsOffset = directives.first(where: { $0.type == .sections })?.offset
        else {
            fatalError("Could not find the Object Files directive!")
        }
        let objStart = objDir.offset + 2
        let objRange = objStart..<sectionsOffset
        let objectFiles = parse(objLines: lines[objRange])
        
        print("Found \(objectFiles.count) relevant object files.")
        
        print("Creating Object File map...")
        let objMap: [Int : ObjectFile] = objectFiles.reduce(into: [:]) { (map, obj) in
            map[obj.index] = obj
        }
        
        guard
            let symDir = directives.first(where: { $0.type == .symbols }),
            let deadOffset = directives.first(where: { $0.type == .deadStrippedSymbols })?.offset
        else {
            fatalError("Could not find the Symbols directive!")
        }

        let symStart = symDir.offset + 2
        let symRange = symStart..<deadOffset

        print("Finding symbols...")
        let symbols = parse(symbolLines: lines[symRange])
        print("Parsed \(symbols.count) symbols from \(symRange.count) lines.")

        print("Grouping symbols...")
        let groupedSymbols = Dictionary(grouping: symbols, by: \.fileIndex)
        print("Created \(groupedSymbols.keys.count) groups.")
        
        print("Adding symbols to file objects...")
        let filesWithSymbols = groupedSymbols.compactMap { index, symbols -> ObjectFile? in
            guard var obj = objMap[index] else { return nil }
            obj.add(symbols: symbols)
            return obj
        }
        
        print("Grouping files by module name...")
        let groupedFiles = Dictionary(grouping: filesWithSymbols) { $0.module }
        
        print("Creating Modules...")
        let modules = groupedFiles.map { name, files in Module(name: name, files: files.sorted().reversed()) }.sorted()
        
        print("\n===========\nSIZE REPORT\n===========")
        modules.forEach { print($0.sizeReport) }
    }
    
    private static func parse(objLines: ArraySlice<Substring>) -> [ObjectFile] {
        print("Re-joining object lines...")
        let objStr = objLines.joined(separator: "\n")
        print("Finding object files in the app...")
        let appObjs = objStr.matches(of: ObjectFile.appObjRegex)
            .map { match -> ObjectFile in
                let (_, index, module, file) = match.output
                return ObjectFile(index: index, module: module, file: file, symbols: [])
            }
        print("Found \(appObjs.count) in app.")

        print("Finding object files in the libraries...")
        let libObjs = objStr.matches(of: ObjectFile.libObjRegex)
            .map { match -> ObjectFile in
                let (_, index, module, file) = match.output
                return ObjectFile(index: index, module: module, file: file, symbols: [])
            }
        print("Found \(libObjs.count) in libs.")

        return appObjs + libObjs
    }
    
    private static func parse(symbolLines: ArraySlice<Substring>) -> [Symbol] {
        symbolLines.compactMap { line -> Symbol? in
            guard let output = line.matches(of: Symbol.symbolRegex).first?.output else { return nil }
            let (_, address, size, fileIndex, name) = output
            return Symbol(address: address, size: size, fileIndex: fileIndex, name: name)
        }
    }
}
