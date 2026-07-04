import SwiftUI

struct RealtimeReactionDisplayView: View {
    @StateObject private var viewModel = ReactionDisplayViewModel()
    @StateObject private var motionViewModel = AirPodsMotionViewModel()
    @StateObject private var reactionDetector = ReactionDetectionViewModel()
    let isSensorAvailable: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        dominantStateCard
                        axesPanelCard
                        if shouldShowSensorUnavailableNote {
                            sensorUnavailableNote
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("リアルタイム反応")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Color(red: 1.0, green: 0.3, blue: 0.3))
                }
                ToolbarItem(placement: .primaryAction) {
                    sessionToggleButton
                }
            }
            .onDisappear { stopSession(presentTimeline: false) }
            .onChange(of: motionViewModel.latestSample) { _, sample in
                guard let sample else { return }
                reactionDetector.ingest(sample)
                viewModel.updateScore(reactionDetector.currentScore)
            }
            .fullScreenCover(isPresented: $viewModel.showTimeline) {
                ReactionTimelineView(
                    trackTitle: "— 曲タイトル —",
                    trackArtist: "— アーティスト —",
                    duration: 268
                )
            }
        }
    }

    private var shouldShowSensorUnavailableNote: Bool {
        !isSensorAvailable || motionViewModel.fallbackRequired
    }

    private var dominantStateCard: some View {
        VStack(spacing: 12) {
            if viewModel.isSessionActive, let dominant = viewModel.score.dominant {
                Text(dominant.emoji)
                    .font(.system(size: 56))
                    .transition(.scale.combined(with: .opacity))
                Text(dominant.label)
                    .font(.title2.bold())
                    .foregroundStyle(dominant.color)
                    .transition(.opacity)
                Text("いまの状態")
                    .font(.caption)
                    .foregroundStyle(.gray)
            } else if viewModel.isSessionActive {
                ProgressView()
                    .tint(.gray)
                Text("反応を検出中…")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .padding(.top, 4)
            } else {
                Image(systemName: "waveform.path")
                    .font(.system(size: 40))
                    .foregroundStyle(.gray.opacity(0.4))
                Text("リスニング開始で\nリアルタイム反応を表示")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 130)
        .padding(20)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .animation(.spring(duration: 0.4), value: viewModel.score.dominant?.id)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isSessionActive)
    }

    private var axesPanelCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("3状態スコア")
                .font(.caption.bold())
                .foregroundStyle(.gray.opacity(0.6))
                .kerning(1.2)
                .padding(.bottom, 4)

            if viewModel.isSessionActive {
                VStack(spacing: 14) {
                    ForEach(viewModel.score.axes) { axis in
                        ReactionAxisBar(axis: axis)
                    }
                }
            } else {
                VStack(spacing: 14) {
                    ForEach(ReactionScore.empty.axes) { axis in
                        ReactionAxisBar(axis: ReactionAxis(
                            id: axis.id,
                            label: axis.label,
                            emoji: axis.emoji,
                            value: 0,
                            color: axis.color
                        ))
                    }
                }
                .opacity(0.3)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .animation(.easeInOut(duration: 0.15), value: viewModel.score)
    }

    private var sensorUnavailableNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.tap.fill")
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.1))
            VStack(alignment: .leading, spacing: 2) {
                Text("手動ラベルモード")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Text("センサーが使えないため、ボタンで反応を記録します")
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
        }
        .padding(14)
        .background(Color(red: 1.0, green: 0.55, blue: 0.1).opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private var sessionToggleButton: some View {
        Button {
            if viewModel.isSessionActive {
                stopSession()
            } else {
                startSession()
            }
        } label: {
            Text(viewModel.isSessionActive ? "終了" : "開始")
                .font(.subheadline.bold())
                .foregroundStyle(viewModel.isSessionActive ? .white : Color(red: 1.0, green: 0.3, blue: 0.3))
        }
    }

    private func startSession() {
        viewModel.startSession(sensorAvailable: isSensorAvailable)
        reactionDetector.startSession()
        if isSensorAvailable {
            motionViewModel.start()
        }
    }

    private func stopSession(presentTimeline: Bool = true) {
        motionViewModel.stop()
        reactionDetector.stopSession(finalPlaybackTime: nil)
        viewModel.stopSession(presentTimeline: presentTimeline)
    }
}

#Preview {
    RealtimeReactionDisplayView(isSensorAvailable: true)
}
