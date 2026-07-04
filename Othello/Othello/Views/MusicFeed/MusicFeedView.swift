import SwiftUI

struct MusicFeedView: View {
    let artist: Artist
    let highlightedComment: HomeDashboardComment?
    let onPlaybackContext: (NowPlayingContext) -> Void
    @ObservedObject private var playback: PlaybackViewModel
    @StateObject private var viewModel: MusicFeedViewModel
    @State private var selectedPlaybackCardID: String?
    @Environment(\.dismiss) private var dismiss
    @State private var replyTarget: FeedPost?
    @State private var replyCountsByCardID: [String: Int] = [:]
    @State private var reloadNonce = 0

    init(
        artist: Artist,
        highlightedComment: HomeDashboardComment? = nil,
        onPlaybackContext: @escaping (NowPlayingContext) -> Void,
        playback: PlaybackViewModel
    ) {
        self.artist = artist
        self.highlightedComment = highlightedComment
        self.onPlaybackContext = onPlaybackContext
        self.playback = playback
        self._viewModel = StateObject(
            wrappedValue: MusicFeedViewModel(
                artist: artist,
                initialSong: highlightedComment?.song
            )
        )
        self._selectedPlaybackCardID = State(
            initialValue: highlightedComment.map { Self.highlightedSelectionID(for: $0) }
        )
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                navigationBar
                songTabBar
                feedList
            }
        }
        .navigationBarHidden(true)
        .task(id: loadPostsTaskID) {
            await viewModel.loadPosts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .howCardDidChange)) { _ in
            reloadNonce &+= 1
        }
    }

    private var loadPostsTaskID: String {
        "\(viewModel.selectedSong?.howCardLookupSongID ?? ""):\(reloadNonce)"
    }

    private var navigationBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.white)
                    .font(.title3)
            }
            Spacer()
            Text(artist.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Spacer()
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white)
                .font(.title3)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var songTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(artist.songs.enumerated()), id: \.element.id) { index, song in
                    songTabButton(index: index, song: song)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func songTabButton(index: Int, song: Song) -> some View {
        let isSelected: Bool = viewModel.selectedSongIndex == index
        let gradient = LinearGradient(colors: song.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
        let bgColor: Color = isSelected ? Color.white.opacity(0.12) : Color.clear
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedSongIndex = index
            }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(gradient)
                    .frame(width: 24, height: 24)
                Text(song.title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundStyle(isSelected ? .white : Color.gray)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(bgColor, in: Capsule())
        }
    }

    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let highlightedComment {
                    HighlightedHowCardCommentCard(
                        item: highlightedComment,
                        isSelected: selectedPlaybackCardID == highlightedSelectionID(for: highlightedComment),
                        replyCount: currentReplyCount(for: highlightedComment.howCard),
                        onSongTap: {
                            play(comment: highlightedComment)
                        },
                        onReply: {
                            replyTarget = FeedPost(howCard: highlightedComment.howCard, song: highlightedComment.song)
                        }
                    )
                }

                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .padding(.vertical, 24)
                } else if let errorMessage = viewModel.errorMessage {
                    feedStatusMessage(errorMessage, systemImage: "wifi.exclamationmark")
                } else if viewModel.posts.isEmpty {
                    feedStatusMessage("この曲のHowカードはまだありません", systemImage: "music.note.list")
                }

                ForEach(viewModel.posts) { post in
                    FeedPostCard(
                        post: post,
                        isSelected: selectedPlaybackCardID == selectionID(for: post),
                        onSongTap: {
                            play(post: post)
                        },
                        onLike: {
                            like(post: post)
                        },
                        onReply: {
                            replyTarget = post
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .sheet(item: $replyTarget) { post in
            HowCardRepliesView(post: post) { replyCount in
                if let cardID = post.cardID {
                    updateReplyCount(cardID: cardID, replyCount: replyCount)
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func feedStatusMessage(_ message: String, systemImage: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.gray)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func play(post: FeedPost) {
        let selectionID = selectionID(for: post)
        Task {
            let context = post.playbackContext
            guard let track = await playback.select(song: post.song, initialPlaybackTime: context.initialPlaybackTime) else { return }
            let resolvedSong = Song(playbackTrack: track, fallback: post.song)
            selectedPlaybackCardID = selectionID
            onPlaybackContext(context.replacingSong(resolvedSong))
        }
    }

    private func play(comment: HomeDashboardComment) {
        let selectionID = highlightedSelectionID(for: comment)
        Task {
            let context = NowPlayingContext(song: comment.song, howCardComment: comment.howCard)
            guard let track = await playback.select(song: comment.song, initialPlaybackTime: context.initialPlaybackTime) else { return }
            let resolvedSong = Song(playbackTrack: track, fallback: comment.song)
            selectedPlaybackCardID = selectionID
            onPlaybackContext(context.replacingSong(resolvedSong))
        }
    }

    private func highlightedSelectionID(for comment: HomeDashboardComment) -> String {
        Self.highlightedSelectionID(for: comment)
    }

    private static func highlightedSelectionID(for comment: HomeDashboardComment) -> String {
        "highlight:\(comment.id)"
    }

    private func selectionID(for post: FeedPost) -> String {
        "post:\(post.selectionID)"
    }

    private func like(post: FeedPost) {
        guard let cardID = post.cardID else { return }
        Task {
            try? await FirebaseAPI.shared.incrementGoods(cardID: cardID)
        }
    }

    private func currentReplyCount(for howCard: HowCardComment) -> Int {
        guard let cardID = howCard.documentID else {
            return howCard.replyCount
        }
        return replyCountsByCardID[cardID] ?? howCard.replyCount
    }

    private func updateReplyCount(cardID: String, replyCount: Int) {
        viewModel.updateReplyCount(cardID: cardID, replyCount: replyCount)
        replyCountsByCardID[cardID] = replyCount
    }
}

#Preview {
    MusicFeedView(artist: Artist.catalog[0], onPlaybackContext: { _ in }, playback: PlaybackViewModel())
}
