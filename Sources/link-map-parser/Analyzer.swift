import Foundation

struct Analyzer {

    enum Error: Swift.Error {
        case couldNotLoadLinkMap
    }
    
    private enum MapSection {
        case objectFiles
        case symbols
        case other
    }
    
    private static var verbose: Bool = false
    
    static func asyncAnalyze(linkMapUrl: URL, printFileSymbols: String? = nil, verbose: Bool = false) async throws -> String {
        self.verbose = verbose
        
        var currentSection = MapSection.other
        var files: [ObjectFile] = []
        var symbols: [Symbol] = []
        
        for try await line in linkMapUrl.lines
        {
            if line.first == "#" {
                switch line.prefix(6) {
                case "# Obje":
                    log("Starting Object Files section...")
                    currentSection = .objectFiles
                    continue
                case "# Symb":
                    log("Starting Symbols section...")
                    currentSection = .symbols
                    continue
                case "# Dead":
                    /// We're done once we get to dead stripped symbols.
                    log("Finished parsing lines.")
                    currentSection = .other
                    break
                default:
                    continue
                }
            }
            if currentSection == .other {
                continue
            } else if currentSection == .symbols {
                guard let match = line.matches(of: Symbol.symbolRegex).first else {
                    log("WARNING: Could not parse line into symbol: \(line)")
                    continue
                }
                let (_, address, size, fileIndex, name) = match.output
                symbols.append(Symbol(address: address, size: size, fileIndex: fileIndex, name: name))
            } else if currentSection == .objectFiles {
                if let match = line.matches(of: ObjectFile.appObjRegex).first {
                    let (_, index, module, file) = match.output
                    files.append(ObjectFile(index: index, module: module, file: file))
                } else if let match = line.matches(of: ObjectFile.libObjRegex).first {
                    let (_, index, module, file) = match.output
                    files.append(ObjectFile(index: index, module: module, file: file))
                }
            }
        }
        
        log("Creating Object File map...")
        let objMap: [Int : ObjectFile] = files.reduce(into: [:]) { (map, obj) in
            map[obj.index] = obj
        }

        log("Grouping symbols...")
        let groupedSymbols = Dictionary(grouping: symbols, by: \.fileIndex)
        log("Created \(groupedSymbols.keys.count) groups.")
        
        log("Adding symbols to file objects...")
        let filesWithSymbols = groupedSymbols.compactMap { index, symbols -> ObjectFile? in
            guard var obj = objMap[index] else { return nil }
            obj.add(symbols: symbols)
            return obj
        }

        log("Grouping files by module name...")
        let groupedFiles = Dictionary(grouping: filesWithSymbols) { $0.module }
        
        log("Creating Modules...")
        let modules = groupedFiles.map { name, files in Module(name: name, files: files.sorted().reversed()) }.sorted()
        
        let output = "\n===========\nSIZE REPORT\n==========="
        return modules.reduce(into: output) { partialResult, module in
            partialResult += "\n\(module.sizeReport)"
        }
    }
    
    private static func log(_ string: String) {
        guard verbose else { return }
        print(string)
    }
}
