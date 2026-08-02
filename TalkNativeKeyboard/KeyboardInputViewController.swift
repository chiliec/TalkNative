import UIKit
import SwiftUI
import KeyboardUI
import EnhancerUI
import HistoryKit

final class KeyboardInputViewController: UIInputViewController {
    private static let panelHeight: CGFloat = 290
    private static let promptDismissedKey = "keyboard.fullAccessPromptDismissed.v1"

    private var viewModel: KeyboardPanelViewModel?
    private var services: KeyboardServices?

    override func viewDidLoad() {
        super.viewDidLoad()
        installHeightConstraint()
        installNextKeyboardButton()
        installPanel()
    }

    /// The document context is not reliably readable during `viewDidLoad`, and
    /// switching into our keyboard delivers no text-change event to recover on,
    /// so the capture is re-run once the input view is actually up.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel?.inputViewDidAppear()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        viewModel?.textDidChange()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        viewModel?.selectionDidChange()
    }

    // MARK: - Setup

    private func installHeightConstraint() {
        let height = view.heightAnchor.constraint(equalToConstant: Self.panelHeight)
        // Below `.required` so the system can resize during rotation without
        // producing an unsatisfiable constraint.
        height.priority = .required - 1
        height.isActive = true
    }

    private func installNextKeyboardButton() {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "globe"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        button.accessibilityIdentifier = "keyboardPanel.nextKeyboard"
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            button.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            button.heightAnchor.constraint(equalToConstant: 32),
            button.widthAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func installPanel() {
        let services = KeyboardServices.make(hasFullAccess: hasFullAccess)
        self.services = services
        let enhancement = services.makeEnhancementViewModel()
        let model = KeyboardPanelViewModel(
            proxy: LiveTextDocumentProxy(textDocumentProxy),
            enhancement: enhancement,
            availability: { services.provider.availability },
            activePresets: services.presets.activePresets,
            hasFullAccess: hasFullAccess
        )
        viewModel = model

        Task { [weak self] in
            await enhancement.waitForCompletion()
            self?.recordCompletedRun(from: enhancement)
        }

        let defaults = UserDefaults.standard
        let panel = KeyboardPanel(
            viewModel: model,
            isFullAccessPromptDismissed: defaults.bool(forKey: Self.promptDismissedKey),
            onDismissFullAccessPrompt: { defaults.set(true, forKey: Self.promptDismissedKey) }
        )

        let hosting = UIHostingController(rootView: panel)
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.view.backgroundColor = .clear
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -48),
        ])
        hosting.didMove(toParent: self)
    }

    private func recordCompletedRun(from enhancement: EnhancementViewModel) {
        let variants = enhancement.variantStates.compactMap { state -> SavedVariant? in
            guard case .completed = state.phase else { return nil }
            return SavedVariant(
                presetID: state.presetID,
                presetLabelSnapshot: state.presetLabel,
                outputText: state.text
            )
        }
        services?.record(inputText: enhancement.inputText, variants: variants)
    }
}
