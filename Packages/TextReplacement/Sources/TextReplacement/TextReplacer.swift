import Foundation

public enum TextReplacer {
    public static func apply(_ plan: ReplacementPlan, to proxy: any TextDocumentProxying) {
        for _ in 0..<max(0, plan.deleteCount) {
            proxy.deleteBackward()
        }
        proxy.insertText(plan.insert)
    }
}
