import SwiftUI

/// Frosted "glass" card, mirroring `utils/glass_container.dart`.
/// On iOS 26+ this renders with the system Liquid Glass effect, keeping a
/// subtle themed tint so the content stays readable over the gradient.
struct GlassCard<Content: View>: View {
    let padding: EdgeInsets
    let cornerRadius: CGFloat
    let backgroundColor: Color
    let borderColor: Color
    let content: Content

    init(
        padding: EdgeInsets = EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20),
        cornerRadius: CGFloat = 20,
        backgroundColor: Color = Color.black.opacity(0.22),
        borderColor: Color = Color.white.opacity(0.12),
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            )
            .glassEffect(
                .regular.tint(backgroundColor),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
            .padding(.bottom, 12)
    }
}