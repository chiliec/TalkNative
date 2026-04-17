import Testing
@testable import PresetKit

@Suite("PresetValidation")
struct PresetValidationTests {
    @Test func acceptsValidLabels() throws {
        try PresetValidation.validate(label: "A", instructions: "ok")
        try PresetValidation.validate(label: String(repeating: "x", count: 24), instructions: "ok")
    }

    @Test func rejectsEmptyLabel() {
        #expect(throws: PresetValidation.Error.emptyLabel) {
            try PresetValidation.validate(label: "   ", instructions: "ok")
        }
    }

    @Test func rejectsOverlongLabel() {
        #expect(throws: PresetValidation.Error.labelTooLong) {
            try PresetValidation.validate(label: String(repeating: "x", count: 25), instructions: "ok")
        }
    }

    @Test func rejectsEmptyInstructions() {
        #expect(throws: PresetValidation.Error.emptyInstructions) {
            try PresetValidation.validate(label: "A", instructions: "")
        }
    }

    @Test func rejectsOverlongInstructions() {
        #expect(throws: PresetValidation.Error.instructionsTooLong) {
            try PresetValidation.validate(label: "A", instructions: String(repeating: "x", count: 401))
        }
    }

    @Test func activeSelectionMustBeExactlyThree() {
        #expect(throws: PresetValidation.Error.activeSelectionWrongSize) {
            try PresetValidation.validateActiveSelection(count: 2)
        }
        #expect(throws: PresetValidation.Error.activeSelectionWrongSize) {
            try PresetValidation.validateActiveSelection(count: 4)
        }
        // 3 does not throw
        try? PresetValidation.validateActiveSelection(count: 3)
    }
}
