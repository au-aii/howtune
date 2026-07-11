import SwiftUI

struct ReactionTimelineView: View {
    @StateObject private var viewModel: ReactionTimelineViewModel
    @Environment(\.dismiss) private var dismiss

    init(trackTitle: String, trackArtist: String, duration: TimeInterval, events: [ReactionEvent] = []) {
        _viewModel = StateObject(wrappedValue: ReactionTimelineViewModel(
            trackTitle: trackTitle,
            trackArtist: trackArtist,
            duration: duration,
            events: events
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        trackInfo
                        timelineSection
                        eventsSection
                    }
                }
            }
            .navigationTitle("振り返り")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Color(red: 1.0, green: 0.3, blue: 0.3))
                }
            }
        }
        .sheet(isPresented: $viewModel.showDialogueSheet) {
            if let event = viewModel.selectedEvent {
                HowChatView(event: event)
            }
        }
    }

    // MARK: - トラック情報
    private var trackInfo: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.6, green: 0.05, blue: 0.1), Color.black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                Image(systemName: "music.note")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.trackTitle)
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)
                Text(viewModel.trackArtist)
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(viewModel.events.count)件の反応")
                    .font(.caption.bold())
                    .foregroundStyle(Color(red: 1.0, green: 0.3, blue: 0.3))
                Text(formatTime(viewModel.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - タイムラインバー
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("反応タイムライン")
                    .font(.caption.bold())
                    .foregroundStyle(Color(.secondaryLabel))
                    .kerning(0.5)
                Spacer()
                // 凡例
                HStack(spacing: 10) {
                    ForEach([HowTag.groove, .chill, .neutral], id: \.self) { tag in
                        HStack(spacing: 4) {
                            Circle().fill(tag.color).frame(width: 6, height: 6)
                            Text(tag.label).font(.caption2).foregroundStyle(.gray)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)

            TimelineBar(
                events: viewModel.events,
                duration: viewModel.duration,
                selectedEventID: viewModel.selectedEvent?.id
            )
        }
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - 反応イベントリスト
    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("反応地点")
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(Color(red: 1.0, green: 0.3, blue: 0.3))
                    Text("タップで解説")
                        .font(.caption.bold())
                        .foregroundStyle(Color(red: 1.0, green: 0.3, blue: 0.3))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider().overlay(Color(.separator))

            if viewModel.events.isEmpty {
                // 反応なしフォールバック
                VStack(spacing: 12) {
                    Image(systemName: "waveform.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.gray.opacity(0.4))
                    Text("反応区間が検出されませんでした")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.events) { event in
                        ReactionEventRow(event: event) {
                            viewModel.selectEvent(event)
                        }
                    }
                }
            }
        }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

#Preview {
    ReactionTimelineView(
        trackTitle: "夜行性のアパート",
        trackArtist: "草野ノエル",
        duration: 196,
        events: ReactionEvent.mockSamples(trackDuration: 196)
    )
}
