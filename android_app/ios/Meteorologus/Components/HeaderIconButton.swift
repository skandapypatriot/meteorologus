import SwiftUI

/// Small frosted circular icon button used in the dashboard header,
/// mirroring `_HeaderIconButton` in `dashboard_screen.dart`.
struct HeaderIconButton: View {
    let systemImage: String
    let tooltip: String
    let textColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textColor)
                .frame(width: 30, height: 26)
                .glassEffect(.regular.interactive(), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tooltip)
        .help(tooltip)
    }
}