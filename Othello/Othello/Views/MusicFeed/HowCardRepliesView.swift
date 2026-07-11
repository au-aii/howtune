import SwiftUI

struct HowCardRepliesView: View {
    let post: FeedPost
    let onReplyCountChanged: (Int) -> Void
    @StateObject private var viewModel: HowCardRepliesViewModel
    @Environment(\.dismiss) private var dismiss

    init(post: FeedPost, onReplyCountChanged: @escaping (Int) -> Void) {
        self.post = post
        self.onReplyCountChanged = onReplyCountChanged
        self._viewModel = StateObject(wrappedValue: HowCardRepliesViewModel(post: post))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        originalPost
                        repliesContent
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                Divider().overlay(Color(.separator))
                composer
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle("返信")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .foregroundStyle(.white)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await viewModel.load()
            }
        }
    }

    private var originalPost: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(post.avatarColor)
                    .frame(width: 34, height: 34)
                    .overlay {
                        Text(post.avatarLetter)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.userName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.label))
                    Text("\(post.song.title) · \(formatRange(start: post.howCardComment?.songStart ?? 0, end: post.howCardComment?.songEnd ?? 0))")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                Spacer()
                Label("\(viewModel.replyCount)", systemImage: "bubble.left.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Text(post.comment)
                .font(.subheadline)
                .foregroundStyle(Color(.label))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var repliesContent: some View {
        if viewModel.isLoading {
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else if viewModel.replies.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.replies) { reply in
                    HowCardReplyRow(reply: reply)
                }
            }
        }

        if let errorMessage = viewModel.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.35))
                .padding(.top, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.title2)
                .foregroundStyle(Color(.secondaryLabel))
            Text("まだ返信はありません")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var composer: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.draft)
                    .font(.subheadline)
                    .foregroundStyle(Color(.label))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 72, maxHeight: 104)
                    .padding(8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .onChange(of: viewModel.draft) { _, newValue in
                        if newValue.count > 180 {
                            viewModel.draft = String(newValue.prefix(180))
                        }
                    }

                if viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("この聴き方に返信する")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }

            HStack {
                Text("\(viewModel.draft.count)/180")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color(.secondaryLabel))
                Spacer()
                Button {
                    Task {
                        if let replyCount = await viewModel.postReply() {
                            onReplyCountChanged(replyCount)
                        }
                    }
                } label: {
                    if viewModel.isPosting {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Label("送信", systemImage: "paperplane.fill")
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(viewModel.canPost ? .white : Color.gray.opacity(0.5), in: Capsule())
                .disabled(!viewModel.canPost)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
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
