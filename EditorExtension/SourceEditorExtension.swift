import Client
import Foundation
import XcodeKit
import Preferences

class SourceEditorExtension: NSObject, XCSourceEditorExtension {
    var commandDefinitions: [[XCSourceEditorCommandDefinitionKey: Any]] {
        [
            GetSuggestionsCommand(),
            AcceptSuggestionCommand(),
            RejectSuggestionCommand(),
            NextSuggestionCommand(),
            PreviousSuggestionCommand(),
            ToggleRealtimeSuggestionsCommand(),
            RealtimeSuggestionsCommand(),
            PrefetchSuggestionsCommand(),
            ChatWithSelectionCommand(),
            
            SeparatorCommand("# Custom Commands:"),
        ].map(makeCommandDefinition)
        
        + customCommands().map(makeCommandDefinition)
    }

    func extensionDidFinishLaunching() {
        #if DEBUG
        // In a debug build, we usually want to use the XPC service run from Xcode.
        #else
        // When the source extension is initialized
        // we can call a random command to wake up the XPC service.
        Task.detached {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let service = try getService()
            _ = try await service.checkStatus()
            await service.boostQoS()
        }
        #endif
    }
}

private let identifierPrefix: String = Bundle.main.bundleIdentifier ?? ""

protocol CommandType: AnyObject {
    var commandClassName: String { get }
    var identifier: String { get }
    var name: String { get }
}

extension CommandType where Self: NSObject {
    var commandClassName: String { Self.className() }
    var identifier: String { commandClassName }
}

extension CommandType {
    func makeCommandDefinition() -> [XCSourceEditorCommandDefinitionKey: Any] {
        [.classNameKey: commandClassName,
         .identifierKey: identifierPrefix + identifier,
         .nameKey: name]
    }
}

func makeCommandDefinition(_ commandType: CommandType)
    -> [XCSourceEditorCommandDefinitionKey: Any]
{
    commandType.makeCommandDefinition()
}

func customCommands() -> [CustomCommand] {
    UserDefaults.shared.value(for: \.customCommands).map {
        CustomCommand(name: $0.name)
    }
}
