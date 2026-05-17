import Foundation

public enum SlashCommand: Equatable {
    case trace
    case eval(String)
    case screenshot(String)
    case html(String)
    case human
    case interrupt
    case quit

    public static func parse(_ line: String) throws -> SlashCommand {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else {
            throw SlashCommandError.notACommand
        }

        let parts = trimmed.dropFirst().split(maxSplits: 1, whereSeparator: \.isWhitespace)
        guard let name = parts.first.map(String.init) else {
            throw SlashCommandError.empty
        }
        let argument = parts.dropFirst().first.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        switch name {
        case "trace":
            return .trace
        case "eval":
            guard !argument.isEmpty else { throw SlashCommandError.missingArgument("/eval") }
            return .eval(argument)
        case "screenshot":
            guard !argument.isEmpty else { throw SlashCommandError.missingArgument("/screenshot") }
            return .screenshot(argument)
        case "html":
            guard !argument.isEmpty else { throw SlashCommandError.missingArgument("/html") }
            return .html(argument)
        case "human":
            return .human
        case "interrupt":
            return .interrupt
        case "quit":
            return .quit
        default:
            throw SlashCommandError.unknown("/\(name)")
        }
    }
}

public enum SlashCommandError: Error, Equatable, CustomStringConvertible {
    case notACommand
    case empty
    case missingArgument(String)
    case unknown(String)

    public var description: String {
        switch self {
        case .notACommand:
            return "input is not a slash command"
        case .empty:
            return "empty slash command"
        case .missingArgument(let command):
            return "\(command) requires an argument"
        case .unknown(let command):
            return "unknown slash command: \(command)"
        }
    }
}
