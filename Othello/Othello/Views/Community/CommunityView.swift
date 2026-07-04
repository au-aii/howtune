import SwiftUI

// FR-COMM-01〜04 / US-06 / AC-06
struct CommunityView: View {
    @StateObject private var viewModel = CommunityViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        tagFilterSection
                        statusSection
                        if !viewModel.isLoading && viewModel.errorMessage == nil {
                            myHowSection
                            listenersSection
                            popularTracksSection
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("コミュニティ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await viewModel.load()
            }
        }
    }

    // MARK: - FR-COMM-03: Howタグ絞り込み

    private var tagFilterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("人気 How タグ")
                    .font(.caption.bold())
                    .foregroundStyle(.gray)
                    .kerning(0.5)
                Spacer()
                if viewModel.selectedTag != nil {
                    Button("クリア") { viewModel.selectedTag = nil }
                        .font(.caption.bold())
                        .foregroundStyle(Color(red: 1.0, green: 0.3, blue: 0.3))
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.popularTags, id: \.0) { tag, count in
                        HowTagChip(
                            tag: tag,
                            count: count,
                            isSelected: viewModel.selectedTag == tag
                        ) {
                            withAnimation(.spring(duration: 0.2)) {
                                viewModel.selectedTag = viewModel.selectedTag == tag ? nil : tag
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private var statusSection: some View {
        if viewModel.isLoading {
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        } else if let errorMessage = viewModel.errorMessage {
            emptyState(message: errorMessage, icon: "wifi.exclamationmark")
                .padding(.bottom, 20)
        }
    }

    // MARK: - FR-COMM-01: 自分のHowカード

    private var myHowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "自分のHowカード", icon: "person.fill")

            if viewModel.myHowCards.isEmpty {
                emptyState(message: "まだHowカードがありません\nリスニングして作ってみよう", icon: "music.note.list")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.myHowCards) { card in
                            MyHowCardView(card: card)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.bottom, 28)
    }

    // MARK: - FR-COMM-02: 同じHowのリスナー一覧

    private var listenersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: viewModel.selectedTag.map { "「\($0.label)」なリスナー" } ?? "同じHowのリスナー",
                icon: "person.2.fill"
            )

            if viewModel.filteredListeners.isEmpty {
                emptyState(message: "このHowのリスナーはまだいません", icon: "person.2.slash")
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.filteredListeners) { listener in
                        ListenerRow(listener: listener)
                    }
                }
                .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 28)
    }

    // MARK: - FR-COMM-02: 同じHowで聴かれている曲

    private var popularTracksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: viewModel.selectedTag.map { "「\($0.label)」で人気の曲" } ?? "同じHowで人気の曲",
                icon: "music.note.list"
            )

            if viewModel.filteredTracks.isEmpty {
                emptyState(message: "該当する曲が見つかりません", icon: "waveform.slash")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.filteredTracks.enumerated()), id: \.element.id) { index, track in
                        PopularTrackRow(track: track, rank: index + 1)
                    }
                }
                .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 28)
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(Color(red: 1.0, green: 0.3, blue: 0.3))
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
    }

    private func emptyState(message: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.gray.opacity(0.4))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - HowTagChip

private struct HowTagChip: View {
    let tag: HowTag
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Circle()
                    .fill(tag.color)
                    .frame(width: 7, height: 7)
                Text(tag.label)
                    .font(.caption.bold())
                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : .gray)
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                isSelected
                    ? tag.color.opacity(0.25)
                    : Color.white.opacity(0.07),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? tag.color.opacity(0.6) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MyHowCardView

private struct MyHowCardView: View {
    let card: CommunityViewModel.MyHowCard

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(card.tag.label)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(card.tag.color, in: Capsule())
                Spacer()
                Text(card.createdAt)
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }

            Text(card.title)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(card.description)
                .font(.caption)
                .foregroundStyle(.gray)
                .lineLimit(3)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "music.note")
                    .font(.caption2)
                    .foregroundStyle(.gray)
                Text(card.trackTitle)
                    .font(.caption2)
                    .foregroundStyle(.gray)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(width: 200, height: 160)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(card.tag.color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - ListenerRow

private struct ListenerRow: View {
    let listener: CommunityViewModel.CommunityListener

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(listener.howTag.color.opacity(0.2))
                    .frame(width: 38, height: 38)
                Text(String(listener.name.prefix(1)).uppercased())
                    .font(.subheadline.bold())
                    .foregroundStyle(listener.howTag.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(listener.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(listener.howTitle)
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(listener.howTag.label)
                    .font(.caption2.bold())
                    .foregroundStyle(listener.howTag.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(listener.howTag.color.opacity(0.12), in: Capsule())
                if listener.mutualCount > 0 {
                    Text("共通 \(listener.mutualCount)")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Divider().overlay(Color.white.opacity(0.06)).padding(.leading, 14)
        }
    }
}

// MARK: - PopularTrackRow

private struct PopularTrackRow: View {
    let track: CommunityViewModel.HowTrack
    let rank: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(rank <= 3 ? Color(red: 1.0, green: 0.3, blue: 0.3) : .gray)
                .frame(width: 20)

            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 38, height: 38)
                Image(systemName: "music.note")
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.5))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(track.trackTitle)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(track.trackArtist)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(track.howTag.label)
                    .font(.caption2.bold())
                    .foregroundStyle(track.howTag.color)
                Text("\(track.howCount) How")
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Divider().overlay(Color.white.opacity(0.06)).padding(.leading, 14)
        }
    }
}

#Preview {
    CommunityView()
}
