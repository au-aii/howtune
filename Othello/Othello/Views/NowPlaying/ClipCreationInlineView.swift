import SwiftUI

struct ClipCreationInlineView: View {
    let song: Song
    @StateObject private var viewModel: ClipCreationViewModel

    init(song: Song) {
        self.song = song
        self._viewModel = StateObject(wrappedValue: ClipCreationViewModel(song: song))
    }

    var body: some View {
        VStack(spacing: 28) {
            waveformSection
            commentSection
            shareButton
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .alert("投稿エラー", isPresented: postErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.postErrorMessage ?? "")
        }
    }

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
                    .frame(minHeight: 82)
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

    private var shareButton: some View {
        Button {
            Task { await viewModel.postHowCard() }
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
            .padding(.vertical, 16)
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
