import Foundation
import ArgumentParser

@main
struct LinkMapParser: ParsableCommand {
    
    enum Error: Swift.Error {
        case couldNotFindLinkMap
    }

    static var configuration = CommandConfiguration(
        commandName: "link-map-parser",
        abstract: "Parse and analyze compiler-generated link map to determine per-module/per-file size contributions."
    )

    /// Path to the link map, relative to the execution director of the command.
    @Argument(help: "The path to the link map.")
    var linkMapPath: String

    @Argument(help: ArgumentHelp("The output file path. If omitted, the result will be printed to stdout.", valueName: "output-file"))
    var outputPath: String? = nil   

    /// When present, indicates that the provided file should have its symbols printed.
    @Option(help: ArgumentHelp("The file to print symbols for. Do not include '.swift' extension.", valueName: "file-name"))
    var printSymbolsForFile: String? = nil

    @Flag(help: "Print out progress information as app works.")
    var verbose: Bool = false


    mutating func run() throws {
        let appUrl = URL(filePath: FileManager.default.currentDirectoryPath)
        let mapUrl = appUrl.appending(path: linkMapPath)

        try Analyzer.analyze(linkMapUrl: mapUrl, verbose: true)
    }
}
