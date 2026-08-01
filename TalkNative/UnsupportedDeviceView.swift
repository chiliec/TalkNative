import SwiftUI
import UIKit
import EnhancerCore

/// The button is shown only for reasons the user can act on, and it lands on
/// TalkNative's own settings pane rather than Apple Intelligence & Siri: iOS 26
/// has no public deep link to that pane — `UIApplication.openSettingsURLString`
/// means *this app's* settings, and the only other public constants cover
/// notifications and default apps. Jumping straight there needs the private
/// `App-Prefs:` scheme, so the button gets the user into Settings (one back-tap
/// from the root) and `message` names the exact path to follow.
///
/// It is kept despite that imprecision because `appleIntelligenceNotEnabled`
/// cannot resolve on its own — no download starts until the user turns Apple
/// Intelligence on, so a screen with no way out would strand them.
struct UnsupportedDeviceView: View {
    let reason: LanguageModelAvailability.Reason

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 56)).foregroundStyle(.secondary)
            Text(title).font(.title2.bold()).multilineTextAlignment(.center)
            Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if let actionLabel, let url = URL(string: UIApplication.openSettingsURLString) {
                Link(actionLabel, destination: url).buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
    }

    private var icon: String {
        switch reason {
        case .deviceNotEligible: return "exclamationmark.iphone"
        case .appleIntelligenceNotEnabled: return "gearshape"
        case .modelNotReady: return "icloud.and.arrow.down"
        case .other: return "exclamationmark.circle"
        }
    }

    private var title: String {
        switch reason {
        case .deviceNotEligible: return "This device doesn't support Apple Intelligence"
        case .appleIntelligenceNotEnabled: return "Apple Intelligence is off"
        case .modelNotReady: return "Apple Intelligence is downloading"
        case .other: return "Couldn't start TalkNative"
        }
    }

    private var message: String {
        switch reason {
        case .deviceNotEligible:
            return "TalkNative needs an iPhone 15 Pro, iPhone 16 or newer, or an iPad with M1 or newer."
        case .appleIntelligenceNotEnabled:
            return """
                Open Settings → Apple Intelligence & Siri and turn on Apple \
                Intelligence, then come back here.
                """
        case .modelNotReady:
            return """
                The model is still downloading. Come back in a few minutes — \
                Settings → Apple Intelligence & Siri shows the progress.
                """
        case .other(let s):
            return s
        }
    }

    /// `deviceNotEligible` and `other` get no button: no amount of tapping
    /// through Settings changes either one.
    private var actionLabel: String? {
        switch reason {
        case .appleIntelligenceNotEnabled, .modelNotReady: return "Open Settings"
        case .deviceNotEligible, .other: return nil
        }
    }
}
