import UIKit
import SwiftUI
import KeyboardUI

final class KeyboardInputViewController: UIInputViewController {
    private static let panelHeight: CGFloat = 290
    private static let promptDismissedKey = "keyboard.fullAccessPromptDismissed.v1"

    private var viewModel: KeyboardPanelViewModel?

    override func viewDidLoad() {
        super.viewDidLoad()
        installHeightConstraint()
        installNextKeyboardButton()
        installPanel()
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
        let model = KeyboardPanelViewModel(
            proxy: LiveTextDocumentProxy(textDocumentProxy),
            enhancement: services.makeEnhancementViewModel(),
            availability: services.provider.availability,
            activePresets: services.presets.activePresets,
            hasFullAccess: hasFullAccess
        )
        viewModel = model

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
}
