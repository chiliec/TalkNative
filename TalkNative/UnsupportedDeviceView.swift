import SwiftUI
import UIKit
import EnhancerCore

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
            return "Turn on Apple Intelligence in Settings → Apple Intelligence & Siri."
        case .modelNotReady:
            return "The model is still downloading. Come back in a few minutes."
        case .other(let s):
            return s
        }
    }

    private var actionLabel: String? {
        switch reason {
        case .appleIntelligenceNotEnabled: return "Open Settings"
        default: return nil
        }
    }
}
