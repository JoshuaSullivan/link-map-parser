import Foundation
import ArgumentParser

@main
struct LinkMapParser: AsyncParsableCommand {
    
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

    /// The output path, if any.
    @Argument(help: ArgumentHelp("The output file path. If omitted, the result will be printed to stdout.", valueName: "output-file"))
    var outputPath: String? = nil   

//    /// When present, indicates that the provided file should have its symbols printed.
//    @Option(help: ArgumentHelp("The file to print symbols for. Do not include '.swift' extension.", valueName: "file-name"))
//    var printSymbolsForFile: String? = nil

    @Flag(name: .shortAndLong, help: "Include only module sizes in the final report.")
    var moduleOnly: Bool = false
    
    /// When `true`, progress will be printed as the app works.
    @Flag(name: .shortAndLong, help: "Print out progress information as app works.")
    var verbose: Bool = false
    
    @Flag(name: .customLong("csv", withSingleDash: true), help: "Output will be in CSV format for easier importing into spreadsheets.")
    var csvOutput: Bool = false


    mutating func run() async throws {
        let appUrl = URL(filePath: FileManager.default.currentDirectoryPath)
        let mapUrl = appUrl.appending(path: linkMapPath)

        let report = try await Analyzer.analyze(linkMapUrl: mapUrl, verbose: verbose, moduleOnly: moduleOnly, csvOutput: csvOutput)
        
        if let outputPath {
            let outputUrl = appUrl.appending(path: outputPath)
            if verbose { print("Writing to \(outputUrl.path())") }
            try? FileManager.default.removeItem(at: outputUrl)
            try report.data(using: .utf8)?.write(to: outputUrl)
        } else {
            print(report)
        }
    }
}
