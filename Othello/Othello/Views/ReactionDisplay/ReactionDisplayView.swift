import SwiftUI

struct ReactionDisplayView: View {
    @StateObject private var viewModel = ReactionDisplayViewModel()
    @State private var posted = false
    @State private var commentText = ""
    let isSensorAvailable: Bool
    let selectedLyric: String?
    let selectedLyricTranslation: String?

    init(isSensorAvailable: Bool, lyric: String? = nil, lyricTranslation: String? = nil) {
        self.isSensorAvailable = isSensorAvailable
        self.selectedLyric = lyric
        self.selectedLyricTranslation = lyricTranslation
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    if let lyric = selectedLyric {
                        selectedPhraseCard(lyric: lyric, translation: selectedLyricTranslation)
                    } else {
                        noLyricPlaceholder
                    }
                    commentSection
                    howTagGrid
                    if viewModel.selectedHowTag != nil {
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
        .navigationTitle("Howカード")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.selectedLyric = selectedLyric
            viewModel.selectedLyricTranslation = selectedLyricTranslation
        }
    }

    private func selectedPhraseCard(lyric: String, translation: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "quote.opening").font(.caption.bold())
                    .foregroundStyle(Color(red: 1.0, green: 0.3, blue: 0.3))
                Text("選択中のフレーズ").font(.caption.bold())
                    .foregroundStyle(Color(red: 1.0, green: 0.3, blue: 0.3))
                Spacer()
            }
            Text(lyric).font(.title3.bold()).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            if let translation {
                Text(translation).font(.subheadline).foregroundStyle(.gray)
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
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.25), lineWidth: 1))
    }

    private var noLyricPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.bubble").font(.system(size: 36)).foregroundStyle(.gray.opacity(0.4))
            Text("歌詞を選んでHowカードを作ろう").font(.subheadline).foregroundStyle(.gray).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(28)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }

    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble.fill")
                    .font(.caption.bold())
                    .foregroundStyle(Color(red: 1.0, green: 0.3, blue: 0.3))
                Text("コメント")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text("\(commentText.count)/140")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.gray)
            }

            ZStack(alignment: .topLeading) {
                if commentText.isEmpty {
                    Text("この曲のここが好き")
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
                    .frame(minHeight: 92)
                    .onChange(of: commentText) { _, newValue in
                        if newValue.count > 140 {
                            commentText = String(newValue.prefix(140))
                        }
                    }
            }
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .padding(16)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
    }

    private var howTagGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("このフレーズでの気持ちは？").font(.subheadline.bold()).foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(HowTag.scoreCases, id: \.self) { tag in
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            viewModel.selectedHowTag = viewModel.selectedHowTag == tag ? nil : tag
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Text(howTagEmoji(tag)).font(.system(size: 32))
                            Text(tag.label).font(.subheadline.bold()).foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(
                            viewModel.selectedHowTag == tag ? tag.color.opacity(0.2) : Color.white.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(viewModel.selectedHowTag == tag ? tag.color : Color.clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: viewModel.selectedHowTag)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
    }

    private var postButton: some View {
        Button {
            withAnimation(.spring(duration: 0.4)) { posted = true }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                if let tag = viewModel.selectedHowTag {
                    Text("「\(tag.label)」でHowカードを投稿").font(.subheadline.bold())
                }
            }
            .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
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

    private var postedOverlay: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color(red: 1.0, green: 0.3, blue: 0.3))
                Text("Howカードを投稿しました")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                if let tag = viewModel.selectedHowTag {
                    Text(tag.label)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(tag.color.opacity(0.8), in: Capsule())
                }
                if !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(commentText)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.76))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(32)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24))
        }
        .onTapGesture {
            withAnimation(.spring(duration: 0.3)) { posted = false }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    private func howTagEmoji(_ tag: HowTag) -> String {
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
        ReactionDisplayView(
            isSensorAvailable: true,
            lyric: "コンビニの灯りに泳いだ",
            lyricTranslation: "Swimming in the convenience-store glow"
        )
    }
}
