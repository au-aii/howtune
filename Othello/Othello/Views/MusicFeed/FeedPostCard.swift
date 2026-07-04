import SwiftUI

struct FeedPostCard: View {
    let post: FeedPost
    let isSelected: Bool
    let onSongTap: () -> Void
    let onLike: () -> Void
    let onReply: () -> Void
    @State private var isLiked: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(post.avatarColor)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(post.avatarLetter)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(post.userName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color(.label))
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(HowTuneDesign.accent)
                    }
                    Text("\(post.userHandle) · \(post.timeAgo)")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                Spacer()
                if isSelected {
                    Text("選択中")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(HowTuneDesign.accent, in: Capsule())
                } else {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Color(.secondaryLabel))
                        .font(.subheadline)
                }
            }

            Text(post.comment)
                .font(.subheadline)
                .foregroundStyle(Color(.label))
                .lineLimit(3)

            MiniSongCard(context: post.playbackContext, onTap: onSongTap)

            HStack(spacing: 20) {
                Button {
                    guard !isLiked else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isLiked = true
                    }
                    onLike()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundStyle(isLiked ? HowTuneDesign.accent : Color(.secondaryLabel))
                        Text("\(post.likeCount + (isLiked ? 1 : 0))")
                            .font(.subheadline)
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
                Button(action: onReply) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left")
                            .foregroundStyle(Color(.secondaryLabel))
                        Text("\(post.commentCount)")
                            .font(.subheadline)
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
                Spacer()
                Image(systemName: "paperplane")
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
        .padding(16)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    HowTuneDesign.accent.opacity(isSelected ? 0.24 : 0),
                    lineWidth: 1
                )
        )
    }

    private var cardBackground: Color {
        isSelected
            ? HowTuneDesign.accent.opacity(0.14)
            : Color(.secondarySystemBackground)
    }
}
