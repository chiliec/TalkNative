import UIKit
import SwiftUI
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        Task { await loadText() }
    }

    private func loadText() async {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first else {
            complete(with: nil); return
        }

        let text: String
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil)
            text = (loaded as? String) ?? (loaded as? URL)?.absoluteString ?? ""
        } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil)
            text = (loaded as? String) ?? ""
        } else {
            await MainActor.run { self.showTextOnlyMessage() }
            return
        }

        await MainActor.run { self.present(initialText: text) }
    }

    private func present(initialText: String) {
        let host = ExtensionHostView(
            initialText: initialText,
            mode: .share,
            onCopyAndDismiss: { [weak self] text in
                UIPasteboard.general.string = text
                self?.complete(with: nil)
            },
            onUseAndReturn: { _ in },
            onDismiss: { [weak self] in self?.complete(with: nil) }
        )
        let hosting = UIHostingController(rootView: host)
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hosting.didMove(toParent: self)
    }

    private func showTextOnlyMessage() {
        let alert = UIAlertController(
            title: "TalkNative works with text only",
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in self?.complete(with: nil) })
        present(alert, animated: true)
    }

    private func complete(with items: [Any]?) {
        extensionContext?.completeRequest(returningItems: items ?? [], completionHandler: nil)
    }
}
