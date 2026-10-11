import SwiftUI

/// A live audio waveform: a row of monochrome bars driven by recent RMS levels.
struct WaveformView: View {
    let levels: [Float]
    var barCount: Int = 22
    var tint: Color = Theme.ink

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(tint)
                        .frame(height: height(for: index, maxHeight: geo.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .animation(.linear(duration: 0.08), value: levels)
        }
    }

    private func height(for index: Int, maxHeight: CGFloat) -> CGFloat {
        let minHeight: CGFloat = 3
        let count = levels.count
        guard count > 0 else { return minHeight }
        // Right-align newest levels into the bar row.
        let sourceIndex = count - barCount + index
        let level = (sourceIndex >= 0 && sourceIndex < count) ? levels[sourceIndex] : 0
        return minHeight + CGFloat(level) * max(0, maxHeight - minHeight)
    }
}
