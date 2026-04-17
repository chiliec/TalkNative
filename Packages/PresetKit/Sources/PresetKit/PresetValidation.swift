import Foundation

public enum PresetValidation {
    public static let labelMax = 24
    public static let instructionsMax = 400
    public static let customPresetCap = 20
    public static let activeSelectionSize = 3

    public enum Error: Swift.Error, Equatable {
        case emptyLabel
        case labelTooLong
        case emptyInstructions
        case instructionsTooLong
        case customPresetCapReached
        case activeSelectionWrongSize
    }

    public static func validate(label: String, instructions: String) throws {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedLabel.isEmpty { throw Error.emptyLabel }
        if label.count > labelMax { throw Error.labelTooLong }
        if instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw Error.emptyInstructions
        }
        if instructions.count > instructionsMax { throw Error.instructionsTooLong }
    }

    public static func validateActiveSelection(count: Int) throws {
        if count != activeSelectionSize { throw Error.activeSelectionWrongSize }
    }
}
