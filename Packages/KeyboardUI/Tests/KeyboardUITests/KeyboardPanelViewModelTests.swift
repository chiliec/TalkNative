import Testing
import Foundation
import EnhancerCore
import PresetKit
import EnhancerUI
import TextReplacement
@testable import KeyboardUI

@MainActor
@Suite("KeyboardPanelViewModel")
struct KeyboardPanelViewModelTests {
    private func makePresets() -> [Preset] {
        [Preset(label: "Professional", instructions: "Be professional.", isBuiltIn: true, sortOrder: 0)]
    }

    private func makeViewModel(
        proxy: StubTextDocumentProxy,
        availability: LanguageModelAvailability = .available,
        chunks: [String] = ["polished text"],
        hasFullAccess: Bool = true,
        maxChars: Int = TextCapture.defaultMaxChars
    ) -> KeyboardPanelViewModel {
        let provider = StubLanguageModelProvider(availability: availability, scriptedChunks: chunks)
        return KeyboardPanelViewModel(
            proxy: proxy,
            enhancement: EnhancementViewModel(enhancer: Enhancer(provider: provider)),
            availability: { availability },
            activePresets: makePresets(),
            hasFullAccess: hasFullAccess,
            maxChars: maxChars
        )
    }

    @Test func unavailableShortCircuitsBeforeCapture() async {
        let proxy = StubTextDocumentProxy(before: "some text")
        let vm = makeViewModel(proxy: proxy, availability: .unavailable(.deviceNotEligible))
        await vm.onAppear()
        #expect(vm.state == .unavailable(.deviceNotEligible))
    }

    /// A live availability source, so a test can move the model from
    /// unavailable to available the way the system does at runtime.
    private func makeViewModel(
        proxy: StubTextDocumentProxy,
        availabilitySource: @escaping @MainActor () -> LanguageModelAvailability
    ) -> KeyboardPanelViewModel {
        KeyboardPanelViewModel(
            proxy: proxy,
            enhancement: EnhancementViewModel(
                enhancer: Enhancer(
                    provider: StubLanguageModelProvider(scriptedChunks: ["polished text"]))),
            availability: availabilitySource,
            activePresets: makePresets(),
            hasFullAccess: true
        )
    }

    @Test func unavailablePanelRecoversWhenTheModelBecomesReady() async {
        var current = LanguageModelAvailability.unavailable(.modelNotReady)
        let proxy = StubTextDocumentProxy(before: "i has went to the store")
        let vm = makeViewModel(proxy: proxy, availabilitySource: { current })

        await vm.onAppear()
        #expect(vm.state == .unavailable(.modelNotReady))

        current = .available
        vm.textDidChange()

        // Asserted as "no longer unavailable" rather than a concrete state: the
        // recovery kicks off a generation, so `.ready` and `.enhancing` are both
        // legitimate outcomes depending on task scheduling.
        if case .unavailable = vm.state {
            Issue.record("panel stayed unavailable after the model became ready")
        }
    }

    @Test func unavailableReasonTracksTheCurrentReason() async {
        var current = LanguageModelAvailability.unavailable(.appleIntelligenceNotEnabled)
        let proxy = StubTextDocumentProxy(before: "some text")
        let vm = makeViewModel(proxy: proxy, availabilitySource: { current })

        await vm.onAppear()
        #expect(vm.state == .unavailable(.appleIntelligenceNotEnabled))

        // The real sequence after a user grants Apple Intelligence: still
        // unavailable, but now because assets are downloading.
        current = .unavailable(.modelNotReady)
        vm.textDidChange()
        #expect(vm.state == .unavailable(.modelNotReady))
    }

    @Test func emptyFieldLandsInNeedsText() async {
        let vm = makeViewModel(proxy: StubTextDocumentProxy())
        await vm.onAppear()
        #expect(vm.state == .needsText)
    }

    @Test func overLongSelectionLandsInSelectionTooLong() async {
        let proxy = StubTextDocumentProxy(selected: String(repeating: "z", count: 30))
        let vm = makeViewModel(proxy: proxy, maxChars: 10)
        await vm.onAppear()
        #expect(vm.state == .selectionTooLong(count: 30))
    }

    @Test func capturedTextAutoStartsAndReturnsToReady() async {
        let proxy = StubTextDocumentProxy(before: "Hi ", selected: "there", after: "")
        let vm = makeViewModel(proxy: proxy)
        await vm.onAppear()
        #expect(vm.state == .ready(CapturedText(text: "there", source: .selection)))
        #expect(vm.enhancement.inputText == "there")
        #expect(vm.enhancement.variantStates.count == 1)
    }

    @Test func selectionChangeRetargetsCapture() async {
        let proxy = StubTextDocumentProxy(before: "first draft")
        let vm = makeViewModel(proxy: proxy)
        await vm.onAppear()
        #expect(vm.state == .ready(CapturedText(text: "first draft", source: .contextBefore)))

        proxy.before = "first "
        proxy.selected = "draft"
        vm.selectionDidChange()
        #expect(vm.state == .ready(CapturedText(text: "draft", source: .selection)))
    }

    @Test func selectingAVariantReplacesTextAndOffersUndo() async {
        let proxy = StubTextDocumentProxy(before: "Say ", selected: "hello", after: " now")
        let vm = makeViewModel(proxy: proxy)
        await vm.onAppear()

        vm.select(variantText: "greetings")
        #expect(proxy.document == "Say greetings now")
        guard case .replaced(_, let original) = vm.state else {
            Issue.record("expected .replaced, got \(vm.state)"); return
        }
        #expect(original.text == "hello")
    }

    @Test func undoRestoresTheOriginalDocument() async {
        let proxy = StubTextDocumentProxy(before: "Say ", selected: "hello", after: " now")
        let vm = makeViewModel(proxy: proxy)
        await vm.onAppear()

        vm.select(variantText: "greetings")
        vm.undo()
        #expect(proxy.document == "Say hello now")
    }

    @Test func undoReSourcesTheCaptureToContextBefore() async {
        let proxy = StubTextDocumentProxy(before: "Say ", selected: "hello", after: "")
        let vm = makeViewModel(proxy: proxy)
        await vm.onAppear()

        vm.select(variantText: "greetings")
        vm.undo()

        // The restored text is no longer selected. Carrying `.selection`
        // forward would make the next replacement delete exactly one character.
        #expect(vm.state == .ready(CapturedText(text: "hello", source: .contextBefore)))

        vm.select(variantText: "howdy")
        #expect(proxy.document == "Say howdy")
    }

    @Test func externalEditWhileReplacedInvalidatesUndo() async {
        let proxy = StubTextDocumentProxy(before: "Say ", selected: "hello", after: "")
        let vm = makeViewModel(proxy: proxy)
        await vm.onAppear()

        vm.select(variantText: "greetings")
        // The user types a word before tapping undo.
        proxy.before += " everyone"
        vm.textDidChange()

        guard case .ready = vm.state else {
            Issue.record("expected .ready after external edit, got \(vm.state)"); return
        }
        vm.undo()  // must be a no-op now
        #expect(proxy.document == "Say greetings everyone")
    }

    @Test func ourOwnEditsDoNotTriggerRecapture() async {
        let proxy = StubTextDocumentProxy(before: "Say ", selected: "hello", after: "")
        let vm = makeViewModel(proxy: proxy)
        await vm.onAppear()

        vm.select(variantText: "greetings")
        guard case .replaced = vm.state else {
            Issue.record("expected .replaced, got \(vm.state)"); return
        }
    }

    @Test func selectIsIgnoredWhenNotReady() async {
        let vm = makeViewModel(proxy: StubTextDocumentProxy())
        await vm.onAppear()
        #expect(vm.state == .needsText)
        vm.select(variantText: "anything")
        #expect(vm.state == .needsText)
    }
}
