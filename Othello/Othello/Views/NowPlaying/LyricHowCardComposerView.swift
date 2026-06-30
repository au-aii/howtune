import SwiftUI

struct LyricHowCardDraft: Identifiable, Equatable {
    let lyricText: String
    let songStart: TimeInterval
    let songEnd: TimeInterval
    let isEstimatedRange: Bool

    var id: String {
        "\(songStart)-\(songEnd)-\(lyricText)"
    }
}

struct LyricHowCardComposerView: View {
    let song: Song
    let draft: LyricHowCardDraft

    @Environment(\.dismiss) private var dismiss
    @State private var commentText = ""
    @State private var isPosting = false
    @State private var postErrorMessage: String?
    @State private var didPost = false
    @State private var showResonance = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        selectedLyricSection
                        commentSection
                        postButton
                        if didPost {
                            resonanceButton
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("閉じる")
                }
            }
            .navigationTitle("歌詞にコメント")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showResonance) {
                ResonanceMatchView(
                    songId: song.firestoreSongID,
                    songTitle: song.title,
                    myInterval: (draft.songStart, draft.songEnd)
                )
            }
        }
    }

    private var selectedLyricSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "quote.bubble.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.38, blue: 0.38))
                Text(rangeText)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
            }

            Text(draft.lyricText)
                .font(.title3.weight(.heavy))
                .foregroundStyle(.white)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            miniRangeBar
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var miniRangeBar: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let duration = max(song.duration, 1)
            let startRatio = min(max(draft.songStart / duration, 0), 1)
            let endRatio = min(max(draft.songEnd / duration, startRatio), 1)
            let selectionX = width * startRatio
            let selectionWidth = max(width * (endRatio - startRatio), 6)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.32, blue: 0.32),
                                Color(red: 0.32, green: 0.68, blue: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: selectionWidth)
                    .offset(x: selectionX)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("感想")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.gray)
                Spacer()
                Text("\(commentText.count)/140")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.gray)
            }

            ZStack(alignment: .topLeading) {
                if commentText.isEmpty {
                    Text("この一行で感じたこと")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.32))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                }

                TextEditor(text: $commentText)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: 104)
                    .disabled(isPosting || didPost)
                    .onChange(of: commentText) { _, newValue in
                        if newValue.count > 140 {
                            commentText = String(newValue.prefix(140))
                        }
                    }
            }
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            if let postErrorMessage {
                Label(postErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.42))
            } else if didPost {
                Label("Howカードを投稿しました", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.42, green: 0.88, blue: 0.58))
            }
        }
    }

    private var postButton: some View {
        Button {
            Task { await postHowCard() }
        } label: {
            HStack(spacing: 8) {
                if isPosting {
                    ProgressView()
                        .tint(.black)
                    Text("投稿中")
                } else if didPost {
                    Image(systemName: "checkmark")
                    Text("投稿済み")
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("感想を投稿")
                }
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white.opacity(canPost || didPost ? 1 : 0.38), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canPost || isPosting || didPost)
    }

    private var resonanceButton: some View {
        Button {
            showResonance = true
        } label: {
            HStack(spacing: 8) {
                Text("🔥")
                Text("共鳴した人を見る")
                    .font(.subheadline.bold())
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.5, blue: 0.2), Color(red: 0.95, green: 0.2, blue: 0.15)],
                    startPoint: .leading, endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .buttonStyle(.plain)
    }

    private var canPost: Bool {
        !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var rangeText: String {
        "\(formatTime(draft.songStart))-\(formatTime(draft.songEnd))"
    }

    private func postHowCard() async {
        guard canPost, !isPosting, !didPost else { return }

        isPosting = true
        postErrorMessage = nil
        defer { isPosting = false }

        do {
            let howCard = HowCardComment(
                comment: commentText.trimmingCharacters(in: .whitespacesAndNewlines),
                songStart: draft.songStart,
                songEnd: draft.songEnd,
                songID: song.firestoreSongID,
                artistID: song.firestoreArtistID,
                userID: "me"
            )
            _ = try await FirebaseAPI.shared.createHowCard(howCard)
            didPost = true
            NotificationCenter.default.post(name: .howCardDidChange, object: nil)
        } catch {
            postErrorMessage = "投稿できませんでした"
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let value = max(0, Int(time.rounded()))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
