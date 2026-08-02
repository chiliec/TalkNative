import Foundation
import Observation
import EnhancerCore
import PresetKit
import EnhancerUI
import TextReplacement

@Observable
@MainActor
public final class KeyboardPanelViewModel {
    public private(set) var state: KeyboardPanelState = .needsText
    public let enhancement: EnhancementViewModel
    public let hasFullAccess: Bool

    private let proxy: any TextDocumentProxying
    /// Read on demand rather than captured once. Availability is genuinely
    /// mutable at runtime — the model finishes downloading, or the user toggles
    /// Apple Intelligence in Settings — and a keyboard extension can outlive
    /// such a change, so a snapshot taken at init goes stale.
    private let availability: @MainActor () -> LanguageModelAvailability
    private let activePresets: [Preset]
    private let maxChars: Int

    /// True while we are the ones editing the document. The host fires
    /// `textDidChange` for our own `insertText`/`deleteBackward` calls, and
    /// re-capturing mid-replacement would corrupt the plan.
    private var isApplyingEdit = false

    /// The text the visible variants were generated from. Guards regeneration so
    /// a re-capture that lands on the same text is free, and so undo — which
    /// restores exactly what we generated from — does not re-run the model.
    private var lastGeneratedText: String?

    public init(
        proxy: any TextDocumentProxying,
        enhancement: EnhancementViewModel,
        availability: @escaping @MainActor () -> LanguageModelAvailability,
        activePresets: [Preset],
        hasFullAccess: Bool,
        maxChars: Int = TextCapture.defaultMaxChars
    ) {
        self.proxy = proxy
        self.enhancement = enhancement
        self.availability = availability
        self.activePresets = activePresets
        self.hasFullAccess = hasFullAccess
        self.maxChars = maxChars
    }

    public func onAppear() async {
        if case .unavailable(let reason) = availability() {
            state = .unavailable(reason)
            return
        }
        recapture()
        await startIfReady()
    }

    public func textDidChange() { handleExternalChange() }
    public func selectionDidChange() { handleExternalChange() }

    /// The input view just became visible.
    ///
    /// Switching *into* our keyboard is not a text change, so the host delivers
    /// no `textDidChange` for it. Without this hook the panel keeps whatever the
    /// proxy reported while the extension was still loading — which is usually
    /// nothing, leaving `.needsText` on screen over a field full of text.
    public func inputViewDidAppear() { handleExternalChange() }

    /// Replace the captured span with `variantText` and arm the undo plan.
    public func select(variantText: String) {
        guard case .ready(let captured) = state else { return }
        let plan = ReplacementPlan.replacing(captured, with: variantText)
        applyingEdit { TextReplacer.apply(plan, to: proxy) }
        state = .replaced(undo: .undoing(plan, restoring: captured), original: captured)
    }

    /// Restore the text as it was before the last replacement.
    ///
    /// The restored capture is re-sourced to `.contextBefore` because the text
    /// is no longer selected, even when the original capture came from a
    /// selection. Keeping `.selection` here would make the next replacement
    /// emit `deleteCount == 1` against an unselected field, deleting a single
    /// character instead of the whole span.
    public func undo() {
        guard case .replaced(let undoPlan, let original) = state else { return }
        applyingEdit { TextReplacer.apply(undoPlan, to: proxy) }
        state = .ready(CapturedText(text: original.text, source: .contextBefore))
    }

    private func applyingEdit(_ body: () -> Void) {
        isApplyingEdit = true
        body()
        isApplyingEdit = false
    }

    private func handleExternalChange() {
        guard !isApplyingEdit else { return }
        switch state {
        case .enhancing:
            return
        case .unavailable:
            // Re-check rather than staying stuck: if Apple Intelligence came on
            // or the model finished downloading while the panel was up, recover
            // in place instead of waiting for iOS to rebuild the extension.
            // Only this direction is re-checked — entering `.unavailable` from a
            // working state would discard a live undo plan, and a generation
            // that fails mid-session already surfaces its own error.
            if case .unavailable(let reason) = availability() {
                state = .unavailable(reason)
                return
            }
            recapture()
            Task { await startIfReady() }
        case .needsText, .selectionTooLong, .ready, .replaced:
            // Falling through from `.replaced` is deliberate: any external edit
            // invalidates the undo plan, whose delete count assumes the inserted
            // text is still immediately behind the cursor.
            recapture()
            startIfCapturedTextChanged()
        }
    }

    /// Re-target means re-generate. Capturing new text without regenerating
    /// leaves the rows showing variants of the *previous* text — actively
    /// misleading, and the panel has no button to trigger a run by hand.
    private func startIfCapturedTextChanged() {
        guard case .ready(let captured) = state, captured.text != lastGeneratedText else { return }
        Task { await startIfReady() }
    }

    private func recapture() {
        switch TextCapture.capture(from: proxy, maxChars: maxChars) {
        case .captured(let captured):
            state = .ready(captured)
        case .selectionTooLong(let count):
            state = .selectionTooLong(count: count)
        case .empty:
            state = .needsText
        }
    }

    private func startIfReady() async {
        guard case .ready(let captured) = state else { return }
        lastGeneratedText = captured.text
        state = .enhancing(captured)
        await enhancement.start(inputText: captured.text, activePresets: activePresets)
        await enhancement.waitForCompletion()
        if case .enhancing = state {
            state = .ready(captured)
        }
    }
}
