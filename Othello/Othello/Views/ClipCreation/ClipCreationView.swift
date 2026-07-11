import SwiftUI

struct ClipCreationView: View {
    let song: Song
    @StateObject private var viewModel: ClipCreationViewModel
    @Environment(\.dismiss) private var dismiss

    init(song: Song) {
        self.song = song
        self._viewModel = StateObject(wrappedValue: ClipCreationViewModel(song: song))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 28) {
                        albumArt
                        songInfo
                        waveformSection
                        commentSection
                        shareButton
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("切り抜きを作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color(.label))
                            .frame(width: 36, height: 36)
                            .background(Color(.secondarySystemBackground), in: Circle())
                    }
                    .accessibilityLabel("戻る")
                }
            }
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert("投稿エラー", isPresented: postErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.postErrorMessage ?? "")
            }
        }
    }

    // MARK: - Album Art

    private var albumArt: some View {
        CircularArtworkView(song: song, size: 220, isPlaying: false, showsCenterHole: true)
    }

    // MARK: - Song Info

    private var songInfo: some View {
        VStack(spacing: 6) {
            Text(song.title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color(.label))
            Text(song.artistName)
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
        }
    }

    // MARK: - Waveform Section

    private var waveformSection: some View {
        ClipRangeSelectionView(
            waveformData: viewModel.waveformData,
            totalDuration: viewModel.totalDuration,
            clipStart: viewModel.clipStart,
            clipEnd: viewModel.clipEnd,
            clipStartFormatted: viewModel.clipStartFormatted,
            clipEndFormatted: viewModel.clipEndFormatted,
            clipDurationSeconds: viewModel.clipDurationSeconds
        ) { startRatio, endRatio in
            viewModel.updateClipRange(startRatio: startRatio, endRatio: endRatio)
        }
    }

    // MARK: - Comment

    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("コメント")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                Spacer()
                Text("\(viewModel.commentText.count)/140")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color(.secondaryLabel))
            }

            ZStack(alignment: .topLeading) {
                if viewModel.commentText.isEmpty {
                    Text("この曲のここが好き")
                        .font(.subheadline)
                        .foregroundStyle(Color(.tertiaryLabel))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                }

                TextEditor(text: $viewModel.commentText)
                    .font(.subheadline)
                    .foregroundStyle(Color(.label))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: 88)
                    .onChange(of: viewModel.commentText) { _, newValue in
                        if newValue.count > 140 {
                            viewModel.commentText = String(newValue.prefix(140))
                        }
                    }
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(.separator), lineWidth: 1)
            )

            if viewModel.postedCardID != nil {
                Label("Howカードを投稿しました", systemImage: "checkmark.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(Color.green)
            }
        }
    }

    // MARK: - Share Button

    private var shareButton: some View {
        Button {
            Task {
                if await viewModel.postHowCard() {
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isPosting {
                    ProgressView()
                        .tint(.black)
                    Text("投稿中")
                        .font(.body.weight(.semibold))
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                    Text("この切り抜きをシェア")
                        .font(.body.weight(.semibold))
                }
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        }
        .disabled(viewModel.isPosting)
    }

    private var postErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.postErrorMessage != nil },
            set: { if !$0 { viewModel.postErrorMessage = nil } }
        )
    }
}


#Preview {
    ClipCreationView(song: Song(
        id: UUID(),
        title: "ライラック",
        artistName: "Mrs. GREEN APPLE",
        gradientColors: [
            Color(red: 0.75, green: 0.5, blue: 0.85),
            Color(red: 0.95, green: 0.65, blue: 0.4)
        ],
        durationSeconds: 272
    ))
}
