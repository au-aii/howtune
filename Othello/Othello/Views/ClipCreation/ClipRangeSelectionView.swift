import SwiftUI

struct ClipRangeSelectionView: View {
    let waveformData: [CGFloat]
    let totalDuration: Double
    let clipStart: Double
    let clipEnd: Double
    let clipStartFormatted: String
    let clipEndFormatted: String
    let clipDurationSeconds: Int
    let onDrag: (Double, Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("好きな部分を選ぶ")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                Spacer()
                Text("\(clipStartFormatted) – \(clipEndFormatted)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color(.secondaryLabel))
            }

            ClipRangeWaveformView(
                waveformData: waveformData,
                totalDuration: totalDuration,
                clipStart: clipStart,
                clipEnd: clipEnd,
                onDrag: onDrag
            )
            .frame(height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            HStack(spacing: 8) {
                Image(systemName: "scissors")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color(red: 0.75, green: 0.62, blue: 1.0))
                Text("選択中")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(.secondaryLabel))
                Spacer()
                Text("\(clipDurationSeconds)s")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.3, green: 0.2, blue: 0.55), in: Capsule())
            }
        }
    }
}
