import SwiftUI

struct TimelineBar: View {
    let events: [ReactionEvent]
    let duration: TimeInterval
    let selectedEventID: UUID?

    private let barHeight: CGFloat = 48
    private let labelCount = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let width = geo.size.width

                ZStack(alignment: .leading) {
                    // ベースライン
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: barHeight)

                    // 反応区間の帯
                    ForEach(events) { event in
                        let x = xPosition(time: event.startTime, width: width)
                        let w = max(6, barWidth(event: event, width: width))
                        let isSelected = event.id == selectedEventID

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        event.tags.first?.color ?? Color(red: 1.0, green: 0.3, blue: 0.3),
                                        (event.tags.first?.color ?? Color(red: 1.0, green: 0.3, blue: 0.3)).opacity(0.5)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .opacity(isSelected ? 1.0 : event.intensity * 0.85 + 0.15)
                            .frame(width: w, height: barHeight)
                            .offset(x: x)
                            .overlay(alignment: .top) {
                                // 心拍トレンドアイコン
                                Image(systemName: event.heartRateTrend.systemImage)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(event.heartRateTrend.color)
                                    .offset(x: x + w / 2 - 6, y: -14)
                            }
                            .scaleEffect(isSelected ? 1.05 : 1.0, anchor: .center)
                            .animation(.spring(duration: 0.2), value: isSelected)
                    }
                }
                .frame(height: barHeight)
            }
            .frame(height: barHeight + 14) // 心拍アイコン分の余白

            // 時刻ラベル
            HStack(spacing: 0) {
                ForEach(0..<labelCount, id: \.self) { i in
                    let t = duration * Double(i) / Double(labelCount - 1)
                    Text(formatTime(t))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.gray)
                    if i < labelCount - 1 { Spacer() }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func xPosition(time: TimeInterval, width: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(time / duration) * width
    }

    private func barWidth(event: ReactionEvent, width: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(event.duration / duration) * width
    }

    private func formatTime(_ t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        TimelineBar(
            events: ReactionEvent.mockSamples(trackDuration: 268),
            duration: 268,
            selectedEventID: nil
        )
        .padding(.vertical, 40)
    }
}
