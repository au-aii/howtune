import SwiftUI

struct ForYouView: View {
    @Binding var nowPlayingContext: NowPlayingContext?
    @ObservedObject var playback: PlaybackViewModel
    @StateObject private var dashboard = HomeDashboardViewModel()
    @AppStorage("prefersDarkTheme") var prefersDarkTheme = true
    @State private var searchQuery = ""
    @State private var selectedArtist: Artist?
    @State private var selectedComment: HomeDashboardComment?
    @State private var dashboardReloadNonce = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        searchBar
                        featuredArtistsSection
                        recommendedCommentsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
                .refreshable {
                    await dashboard.load(force: true)
                }
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    withAnimation { prefersDarkTheme.toggle() }
                } label: {
                    Image(systemName: prefersDarkTheme ? "moon.fill" : "sun.max.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.trailing, 16)
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedArtist) { artist in
                MusicFeedView(
                    artist: artist,
                    highlightedComment: selectedComment,
                    onPlaybackContext: { context in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            nowPlayingContext = context
                        }
                    },
                    playback: playback
                )
            }
        }
        .task(id: dashboardReloadNonce) {
            await dashboard.load(force: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .howCardDidChange)) { _ in
            dashboardReloadNonce &+= 1
        }
    }

    private var filteredArtists: [Artist] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return dashboard.featuredArtists }
        return dashboard.featuredArtists.filter { artist in
            artist.name.localizedCaseInsensitiveContains(query)
                || artist.songs.contains { $0.title.localizedCaseInsensitiveContains(query) }
        }
    }

    private var filteredComments: [HomeDashboardComment] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return dashboard.comments }
        return dashboard.comments.filter { item in
            item.artist.name.localizedCaseInsensitiveContains(query)
                || item.song.title.localizedCaseInsensitiveContains(query)
                || item.howCard.comment.localizedCaseInsensitiveContains(query)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.42))
            TextField("アーティスト、曲、コメント", text: $searchQuery)
                .foregroundStyle(.white)
                .submitLabel(.search)
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var featuredArtistsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "For You", subtitle: "今聴きたいアーティスト")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(filteredArtists) { artist in
                        Button {
                            selectedComment = nil
                            selectedArtist = artist
                        } label: {
                            ArtistDashboardCard(artist: artist)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 16)
            }
            .scrollClipDisabled()
        }
    }

    private var recommendedCommentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Comment Dashboard", subtitle: "みんなの聴きどころ")

            if dashboard.isLoading {
                VStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { index in
                        CommentSkeletonRow(index: index)
                    }
                }
            } else if let errorMessage = dashboard.errorMessage, dashboard.comments.isEmpty {
                CommentDashboardMessage(
                    title: "コメントを読み込めません",
                    message: errorMessage,
                    actionTitle: "再読み込み",
                    action: {
                        Task { await dashboard.load(force: true) }
                    }
                )
            } else if filteredComments.isEmpty {
                CommentDashboardMessage(
                    title: "コメントがありません",
                    message: searchQuery.isEmpty ? "まだおすすめコメントが届いていません。" : "検索条件に一致するコメントがありません。",
                    actionTitle: nil,
                    action: nil
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredComments) { comment in
                        Button {
                            selectedComment = comment
                            selectedArtist = comment.artist
                        } label: {
                            RecommendedCommentCard(item: comment)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.46))
        }
    }
}

private struct ArtistDashboardCard: View {
    let artist: Artist

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ArtworkBackground(url: artist.artworkURL, gradientColors: artist.gradientColors)

            LinearGradient(
                colors: [.black.opacity(0.05), .black.opacity(0.74)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading) {
                HStack {
                    Spacer()
                    Image(systemName: "play.fill")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.20), in: Circle())
                }

                Spacer()

                VStack(alignment: .leading, spacing: 6) {
                    Text(artist.tag)
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                    Text(artist.name)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                    Text(artist.listeningCount)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
            }
            .padding(16)
        }
        .frame(width: 238, height: 238)
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct RecommendedCommentCard: View {
    let item: HomeDashboardComment

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ArtworkThumb(url: item.artworkURL, gradientColors: item.song.gradientColors, size: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.artist.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(item.song.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.28))
            }

            Text(item.howCard.comment)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white.opacity(0.90))
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Label(formatRange(start: item.howCard.songStart, end: item.howCard.songEnd), systemImage: "waveform")
                Label("\(max(item.howCard.goods, 0))", systemImage: "heart.fill")
                Spacer()
                Text("開く")
                    .font(.caption.weight(.heavy))
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.white.opacity(0.54))
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func formatRange(start: TimeInterval, end: TimeInterval) -> String {
        let safeEnd = end > start ? end : start
        return "\(formatTime(start))-\(formatTime(safeEnd))"
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let value = max(0, Int(time.rounded()))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}

private struct CommentSkeletonRow: View {
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 7) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: [120, 156, 104, 138][index % 4], height: 12)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                        .frame(width: [92, 116, 130, 98][index % 4], height: 10)
                }
                Spacer()
            }
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.white.opacity(0.09))
                .frame(height: 12)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: [220, 250, 190, 236][index % 4], height: 12)
        }
        .padding(16)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .redacted(reason: .placeholder)
    }
}

private struct CommentDashboardMessage: View {
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.bubble")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white.opacity(0.54))
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.58))
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.white, in: Capsule())
                    .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 18)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ArtworkBackground: View {
    let url: URL?
    let gradientColors: [Color]

    var body: some View {
        ZStack {
            LinearGradient(colors: gradientColors, startPoint: .topTrailing, endPoint: .bottomLeading)

            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallbackIcon
                    case .empty:
                        Color.black.opacity(0.12)
                    @unknown default:
                        fallbackIcon
                    }
                }
            } else {
                fallbackIcon
            }
        }
    }

    private var fallbackIcon: some View {
        Image(systemName: "music.note")
            .font(.system(size: 46, weight: .semibold))
            .foregroundStyle(.white.opacity(0.24))
    }
}

private struct ArtworkThumb: View {
    let url: URL?
    let gradientColors: [Color]
    let size: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)

            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallbackIcon
                    case .empty:
                        ProgressView()
                            .tint(.white.opacity(0.7))
                    @unknown default:
                        fallbackIcon
                    }
                }
            } else {
                fallbackIcon
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var fallbackIcon: some View {
        Image(systemName: "music.note")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white.opacity(0.45))
    }
}

#Preview {
    ForYouView(nowPlayingContext: .constant(nil), playback: PlaybackViewModel())
}
