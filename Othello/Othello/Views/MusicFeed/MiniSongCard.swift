import SwiftUI

struct MiniSongCard: View {
    let context: NowPlayingContext
    let onTap: () -> Void
    @State private var isPlaying: Bool = false

    private var song: Song { context.song }

    var body: some View {
        Button {
            startPlayback()
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(song.title)を再生")
    }

    private var cardContent: some View {
        HStack(spacing: 12) {
            CircularArtworkView(song: song, size: 52, isPlaying: isPlaying)
            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.label))
                Text(song.artistName)
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                if context.hasHighlight {
                    Text("How \(formatTime(context.highlightStart ?? context.initialPlaybackTime)) - \(formatTime(context.highlightEnd ?? context.initialPlaybackTime))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(HowTuneDesign.accent)
                }
            }
            Spacer()
            playbackGlyph
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    private var playbackGlyph: some View {
        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
            .font(.system(size: 36))
            .foregroundStyle(LinearGradient(colors: song.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private func startPlayback() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isPlaying.toggle()
        }
        onTap()
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let safeTime = max(0, Int(time.rounded()))
        return "\(safeTime / 60):\(String(format: "%02d", safeTime % 60))"
    }
}
