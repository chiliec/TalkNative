import SwiftUI
import PresetKit

public struct PresetChip: View {
    public let preset: Preset
    public let isActive: Bool
    public let onTap: () -> Void

    public init(preset: Preset, isActive: Bool, onTap: @escaping () -> Void) {
        self.preset = preset
        self.isActive = isActive
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            Text(preset.label)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    isActive ? Color.accentColor : Color.secondary.opacity(0.2),
                    in: Capsule()
                )
                .foregroundStyle(isActive ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
