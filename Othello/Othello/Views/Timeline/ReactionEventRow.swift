import SwiftUI

struct ReactionEventRow: View {
    let event: ReactionEvent
    let onDialogueTap: () -> Void
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.spring(duration: 0.25)) { isExpanded.toggle() } } label: {
                HStack(alignment: .top, spacing: 12) {
                    // 時刻バッジ
                    Text(formatTime(event.startTime))
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(Color(.label))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 6))
                        .frame(width: 52)

                    VStack(alignment: .leading, spacing: 6) {
                        // HowTagバッジ群
                        HStack(spacing: 6) {
                            ForEach(event.tags, id: \.self) { tag in
                                Text(tag.label)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(tag.color, in: Capsule())
                            }
                            // 心拍トレンド
                            HStack(spacing: 3) {
                                Image(systemName: event.heartRateTrend.systemImage)
                                    .font(.caption2)
                                Text(event.heartRateTrend.label)
                                    .font(.caption2)
                            }
                            .foregroundStyle(event.heartRateTrend.color)
                        }

                        // 歌詞行（FR-LYRIC-01/02）
                        if let lyric = event.lyricLine {
                            Text(lyric)
                                .font(.subheadline)
                                .foregroundStyle(Color(.label))
                            if let translation = event.lyricTranslation {
                                Text(translation)
                                    .font(.caption)
                                    .foregroundStyle(Color(.secondaryLabel))
                            }
                        } else {
                            // FR-LYRIC-02: 歌詞なしフォールバック
                            Text("歌詞なし")
                                .font(.caption)
                                .foregroundStyle(.gray.opacity(0.6))
                                .italic()
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            // 展開: AI対話導線
            if isExpanded {
                Button(action: onDialogueTap) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.subheadline)
                        Text("この地点についてAIと話す")
                            .font(.subheadline.bold())
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.85, green: 0.15, blue: 0.2), Color(red: 0.6, green: 0.05, blue: 0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider()
                .overlay(Color.white.opacity(0.07))
                .padding(.leading, 20)
        }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 0) {
            ReactionEventRow(
                event: ReactionEvent.mockSamples(trackDuration: 268)[1],
                onDialogueTap: {}
            )
            ReactionEventRow(
                event: ReactionEvent.mockSamples(trackDuration: 268)[3],
                onDialogueTap: {}
            )
        }
    }
}
