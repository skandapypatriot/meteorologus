import SwiftUI

/// Mirrors `page_indicator.dart`: animated capsule indicators for the slides.
struct PageIndicatorView: View {
    let count: Int
    let currentIndex: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(color.opacity(index == currentIndex ? 0.86 : 0.29))
                    .frame(width: index == currentIndex ? 18 : 6, height: 6)
                    .animation(.easeInOut(duration: 0.3), value: currentIndex)
            }
        }
    }
}