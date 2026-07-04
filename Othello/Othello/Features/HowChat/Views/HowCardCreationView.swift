import SwiftUI

struct HowCardCreationView: View {
    let event: ReactionEvent
    let messages: [HowChatMessage]
    let sessionID: String
    let songId: String

    @State private var selectedTags: Set<HowTag>
    @State private var commentText = ""
    @State private var posted = false
    @State private var isPosting = false
    @State private var generatedCard: HowCardResponse?
    @State private var showResonance = false
    @Environment(\.dismiss) private var dismiss

    init(event: ReactionEvent, messages: [HowChatMessage] = [], sessionID: String? = nil, songId: String = ResonanceDemo.songId) {
        self.event = event
        self.messages = messages
        self.sessionID = sessionID ?? event.id.uuidString
        self.songId = songId
        _selectedTags = State(initialValue: Set(event.tags))
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    lyricCard
                    commentSection
                    tagSection
                    if !selectedTags.isEmpty {
                        postButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }

            if posted {
                postedOverlay
            }
        }
        .navigationTitle("Howカードを作る")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .fullScreenCover(isPresented: $showResonance) {
            ResonanceMatchView(
                songId: songId,
                songTitle: event.lyricLine,
                myInterval: (event.startTime, max(event.endTime, event.startTime + 1))
            )
        }
    }

    // MARK: - 歌詞カード

    @ViewBuilder
    private var lyricCard: some View {
        if let lyric = event.lyricLine {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "quote.opening")
                        .font(.caption.bold())
                        .foregroundStyle(HowTuneDesign.accent)
                    Text("この瞬間のフレーズ")
                        .font(.caption.bold())
                        .foregroundStyle(HowTuneDesign.accent)
                    Spacer()
                    Text(formatTime(event.startTime))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color(.secondaryLabel))
                }
                Text(lyric)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                if let translation = event.lyricTranslation {
                    Text(translation)
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.6, green: 0.05, blue: 0.1).opacity(0.3), Color.white.opacity(0.04)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(HowTuneDesign.accent.opacity(0.25), lineWidth: 1)
            )
        } else {
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .foregroundStyle(Color(.secondaryLabel))
                Text(formatTime(event.startTime) + " の反応区間")
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
                Spacer()
            }
            .padding(16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - コメント

    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble.fill")
                    .font(.caption.bold())
                    .foregroundStyle(HowTuneDesign.accent)
                Text("コメント")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))
                Spacer()
                Text("\(commentText.count)/140")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color(.secondaryLabel))
            }

            ZStack(alignment: .topLeading) {
                if commentText.isEmpty {
                    Text("この曲のここが好き")
                        .font(.subheadline)
                        .foregroundStyle(Color(.tertiaryLabel))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                }

                TextEditor(text: $commentText)
                    .font(.subheadline)
                    .foregroundStyle(Color(.label))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: 96)
                    .onChange(of: commentText) { _, newValue in
                        if newValue.count > 140 {
                            commentText = String(newValue.prefix(140))
                        }
                    }
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - タグ選択

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("気持ちのタグ（複数選択可）")
                .font(.subheadline.bold())
                .foregroundStyle(Color(.label))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(HowTag.scoreCases, id: \.self) { tag in
                    let isSelected = selectedTags.contains(tag)
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            if isSelected { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Text(tagEmoji(tag)).font(.system(size: 32))
                            Text(tag.label).font(.subheadline.bold()).foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            isSelected ? tag.color.opacity(0.2) : Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? tag.color : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 投稿ボタン

    private var postButton: some View {
        Button {
            guard !isPosting else { return }
            isPosting = true
            Task {
                let card = try? await ChatAPIClient.shared.postHowCard(
                    sessionID: sessionID,
                    event: event,
                    messages: messages,
                    selectedTags: Array(selectedTags)
                )
                generatedCard = card
                withAnimation(.spring(duration: 0.4)) {
                    isPosting = false
                    posted = true
                }
            }
        } label: {
            HStack(spacing: 8) {
                if isPosting {
                    ProgressView().tint(.white).scaleEffect(0.8)
                    Text("生成中…").font(.subheadline.bold())
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("Howカードを投稿").font(.subheadline.bold())
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.45, blue: 0.45), Color(red: 0.85, green: 0.15, blue: 0.2)],
                    startPoint: .leading, endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .shadow(color: .red.opacity(0.4), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - 投稿完了オーバーレイ

    private var postedOverlay: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(HowTuneDesign.accent)
                Text("Howカードを投稿しました")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                if let card = generatedCard {
                    VStack(spacing: 8) {
                        Text(card.tagLabel)
                            .font(.headline)
                            .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.45))
                        Text(card.description)
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 8)
                } else {
                    HStack(spacing: 6) {
                        ForEach(Array(selectedTags), id: \.self) { tag in
                            Text(tag.label)
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(tag.color.opacity(0.8), in: Capsule())
                        }
                    }
                }
                if !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(commentText)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.76))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    Button {
                        showResonance = true
                    } label: {
                        HStack(spacing: 8) {
                            Text("🔥")
                            Text("同じ瞬間に反応した人を見る")
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

                    Button("閉じる") { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    // MARK: - Helpers

    private func formatTime(_ t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }

    private func tagEmoji(_ tag: HowTag) -> String {
        switch tag {
        case .groove:    return "🎵"
        case .hype:      return "🔥"
        case .chill:     return "❄️"
        case .immersion: return "🎧"
        case .hit:       return "💫"
        case .afterglow: return "✨"
        case .neutral:   return "○"
        }
    }
}

#Preview {
    NavigationStack {
        HowCardCreationView(event: ReactionEvent.mockSamples(trackDuration: 200)[1])
    }
}
