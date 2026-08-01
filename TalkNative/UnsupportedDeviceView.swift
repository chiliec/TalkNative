import SwiftUI
import UIKit
import EnhancerCore

/// The button lands on TalkNative's own settings pane, not Apple Intelligence &
/// Siri, because no public API reaches that pane: `openSettingsURLString` means
/// *this app's* settings by definition, and the only other public constants
/// cover notifications and default apps. The undocumented `App-Prefs:`/
/// `prefs:root=` schemes are not a way out either — Apple broke their path
/// forms in iOS 18.1 so they land on the Settings root regardless, which is an
/// App Store rejection risk bought for nothing.
///
/// So the screen compensates with `steps`: an explicit numbered path including
/// the back-tap the button forces, rather than a vague "go to Settings". The
/// button stays despite landing imprecisely because `appleIntelligenceNotEnabled`
/// cannot resolve on its own — no download starts until the user turns Apple
/// Intelligence on, so a screen with no way out would strand them.
struct UnsupportedDeviceView: View {
    let reason: LanguageModelAvailability.Reason

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 56)).foregroundStyle(.secondary)
            Text(title).font(.title2.bold()).multilineTextAlignment(.center)
            Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)

            if !steps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        Text("\(index + 1). \(step)")
                    }
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let actionLabel, let url = URL(string: UIApplication.openSettingsURLString) {
                Link(actionLabel, destination: url).buttonStyle(.borderedProminent)

                Text("iOS can't link straight to that screen, so step 2 is needed.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .accessibilityIdentifier("unsupportedDevice")
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
            return "TalkNative needs it turned on:"
        case .modelNotReady:
            return "Come back in a few minutes. To check progress:"
        case .other(let s):
            return s
        }
    }

    /// Step 2 is the back-tap out of TalkNative's own pane — see the note above
    /// on why the button cannot land any closer.
    private var steps: [String] {
        switch reason {
        case .appleIntelligenceNotEnabled:
            return [
                "Open Settings",
                "Tap ‹ Settings to go back",
                "Apple Intelligence & Siri",
                "Turn on Apple Intelligence",
            ]
        case .modelNotReady:
            return [
                "Open Settings",
                "Tap ‹ Settings to go back",
                "Apple Intelligence & Siri",
            ]
        case .deviceNotEligible, .other:
            return []
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
