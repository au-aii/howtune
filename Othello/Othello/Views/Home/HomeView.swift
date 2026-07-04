import SwiftUI
import MusicKit
import AVFoundation
import Combine

struct HomePreviewData {
    let track: PlaybackTrack
    let lyrics: SynchronizedLyrics
    let playbackTime: TimeInterval
    let isPlaying: Bool
}

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @StateObject private var playback = PlaybackViewModel()
    @StateObject private var lyrics = LyricsViewModel()
    @StateObject private var airPodsMotion = AirPodsMotionViewModel()
    @StateObject private var reactionDetector = ReactionDetectionViewModel()

    @State private var showSearchSheet = false
    @State private var showReactionDisplay = false
    @State private var navigateToReaction = false
    @State private var tappedLyric: String?
    @State private var tappedLyricTranslation: String?
    @State private var selectedHowChatEvent: ReactionEvent?
    @State private var artworkRotation: Double = 0
    @State private var didAutoPresentSearch = false
    @State private var outputVolume = AVAudioSession.sharedInstance().outputVolume

    private let deepRed = Color(red: 0.85, green: 0.15, blue: 0.2)
    private let grooveBlue = Color(red: 0.18, green: 0.68, blue: 1.0)
    private let volumeTimer = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()
    private let previewData: HomePreviewData?

    init(useManualMode: Bool, permissionState: PermissionState, previewData: HomePreviewData? = nil) {
        #if DEBUG
        self.previewData = previewData ?? (ProcessInfo.processInfo.environment["HOWTUNE_HOME_PREVIEW"] == "1" ? .lyricsShow : nil)
        #else
        self.previewData = previewData
        #endif
        _viewModel = StateObject(wrappedValue: HomeViewModel(
            useManualMode: useManualMode,
            permissionState: permissionState
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                playerBackdrop

                ScrollView(.vertical, showsIndicators: false) {
                    if displayTrack == nil {
                        trackSelectionSurface
                            .padding(.top, 28)
                    } else {
                        playbackSurface
                            .padding(.top, 14)
                    }
                }
                .safeAreaPadding(.bottom, 96)
                .padding(.bottom, 36)
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToReaction) {
                ReactionDisplayView(
                    isSensorAvailable: viewModel.sensorStatus.headMotion == .connected,
                    lyric: tappedLyric,
                    lyricTranslation: tappedLyricTranslation
                )
            }
        }
        .task {
            if previewData == nil {
                await playback.onAppear()
                if playback.currentTrack == nil && !didAutoPresentSearch {
                    didAutoPresentSearch = true
                    showSearchSheet = true
                }
            }
        }
        .sheet(isPresented: $showSearchSheet) { searchSheet }
        .sheet(item: $selectedHowChatEvent) { event in
            HowChatView(event: event, peak: airPodsMotion.peakMoment)
        }
        .fullScreenCover(isPresented: $showReactionDisplay) {
            RealtimeReactionDisplayView(isSensorAvailable: !viewModel.useManualMode)
        }
        .sensoryFeedback(.selection, trigger: selectedHowChatEvent?.id)
        .onReceive(volumeTimer) { _ in
            outputVolume = AVAudioSession.sharedInstance().outputVolume
        }
        .onAppear {
            syncAirPodsMotionCapture()
        }
        .onChange(of: displayIsPlaying) { _, _ in
            syncAirPodsMotionCapture()
        }
        .onChange(of: displayTrackIdentifier) { _, _ in
            stopAirPodsMotionCapture(reason: "track changed")
            reactionDetector.stopSession(finalPlaybackTime: displayPlaybackTime)
            syncAirPodsMotionCapture()
        }
        .onChange(of: viewModel.useManualMode) { _, _ in
            syncAirPodsMotionCapture()
        }
        .onChange(of: airPodsMotion.latestSample) { _, sample in
            guard let sample else { return }
            reactionDetector.ingest(sample)
        }
        .onDisappear {
            airPodsMotion.stop()
            reactionDetector.stopSession(finalPlaybackTime: displayPlaybackTime)
        }
        .alert(
            "再生位置が取得できません",
            isPresented: previewData == nil ? $playback.positionUnavailableAlertShown : .constant(false)
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(playback.positionUnavailableMessage)
        }
    }

    private var displayTrack: PlaybackTrack? {
        previewData?.track ?? playback.currentTrack
    }

    private var displayLyrics: SynchronizedLyrics? {
        previewData?.lyrics ?? lyrics.lyrics
    }

    private var displayLyricsState: LyricsLoadingState {
        previewData == nil ? lyrics.state : .loaded
    }

    private var displayPlaybackTime: TimeInterval {
        previewData?.playbackTime ?? playback.playbackTime
    }

    private var displayIsPlaying: Bool {
        previewData?.isPlaying ?? playback.isPlaying
    }

    private var displayTrackIdentifier: String? {
        displayTrack?.musicKitID ?? displayTrack?.id.rawValue
    }

    private var playerBackdrop: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.04, green: 0.04, blue: 0.05),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var trackSelectionSurface: some View {
        VStack(alignment: .leading, spacing: 26) {
            Button {
                showSearchSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))

                    Text("曲名・アーティスト名で検索")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.36))
                }
                .padding(.horizontal, 18)
                .frame(height: 58)
                .background(Color(.secondarySystemBackground), in: Capsule())
                .overlay(Capsule().stroke(Color(.separator), lineWidth: 1))
            }
            .buttonStyle(.plain)

            VStack(spacing: 14) {
                ForEach(0..<5, id: \.self) { index in
                    skeletonTrackRow(index: index)
                }
            }

            lyricsSkeleton
        }
        .padding(.horizontal, 22)
    }

    private var playbackSurface: some View {
        VStack(spacing: 10) {
            visualizerSection
            trackInfoSection
            playerControlsSection
            lyricsSection
        }
        .padding(.horizontal, 20)
    }

    private var topActions: some View {
        HStack {
            Button {
                showSearchSheet = true
            } label: {
                Image(systemName: "music.note.list")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color(.secondarySystemBackground), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("曲を選ぶ")

            Spacer()

            Button {
                showReactionDisplay = true
            } label: {
                Image(systemName: "waveform.path.ecg")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color(.secondarySystemBackground), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("リアルタイム反応")
        }
    }

    private var visualizerSection: some View {
        ZStack(alignment: .top) {
            ZStack {
                AirPodsReactiveWaveformView(
                    isAnimating: displayIsPlaying,
                    playbackTime: displayPlaybackTime,
                    audioLevel: musicPulseLevel,
                    motionIntensity: airPodsMotionIntensity,
                    trackSeed: visualizerTrackSeed,
                    reactionState: waveformReactionState
                )
                .frame(width: 264, height: 264)

                artworkDisk(size: 132)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 30)

            topActions
        }
        .frame(maxWidth: .infinity)
        .frame(height: 250)
        .onAppear { startArtworkRotationIfNeeded() }
        .onChange(of: displayIsPlaying) { _, _ in startArtworkRotationIfNeeded() }
    }

    private func artworkDisk(size: CGFloat) -> some View {
        ZStack {
            diskArtworkView(url: displayTrack?.artworkURL, size: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(.separator), lineWidth: 1))
                .rotationEffect(.degrees(displayIsPlaying ? artworkRotation : 0))

            Circle()
                .fill(Color.black.opacity(0.78))
                .frame(width: max(34, size * 0.26), height: max(34, size * 0.26))
                .overlay(Circle().stroke(Color.white.opacity(0.20), lineWidth: 1))
        }
        .shadow(color: .black.opacity(0.42), radius: 28, y: 18)
    }

    private var trackInfoSection: some View {
        VStack(spacing: 8) {
            if let track = displayTrack {
                Text(track.title)
                    .font(.system(size: 38, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.72)

                Text(track.artistName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear)
    }

    private var playerControlsSection: some View {
        VStack(spacing: 10) {
            progressMeter

            HStack(spacing: 32) {
                transportButton(systemImage: "backward.fill", size: 38, isEnabled: false) {}

                Button {
                    Task { await playback.togglePlayback() }
                } label: {
                    Image(systemName: displayIsPlaying ? "pause.fill" : "play.fill")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.white.opacity(0.18), in: Circle())
                        .overlay(Circle().stroke(Color(.separator), lineWidth: 1))
                        .offset(x: displayIsPlaying ? 0 : 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(displayIsPlaying ? "一時停止" : "再生")

                transportButton(systemImage: "forward.fill", size: 38, isEnabled: false) {}
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.10), Color.white.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private var progressMeter: some View {
        let duration = displayTrack?.duration ?? 0
        let progress = duration > 0 ? min(max(displayPlaybackTime / duration, 0), 1) : 0
        let beatPhase = Int(displayPlaybackTime * 2.0) % 16

        return VStack(spacing: 7) {
            GeometryReader { proxy in
                let width = proxy.size.width

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.secondarySystemBackground))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [HowTuneDesign.accent, Color.orange.opacity(0.92), grooveBlue.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width * progress)

                    HStack(spacing: 0) {
                        ForEach(0..<16, id: \.self) { index in
                            Capsule()
                                .fill(index == beatPhase ? Color.white.opacity(0.82) : Color.white.opacity(0.24))
                                .frame(width: 2, height: index % 4 == 0 ? 13 : 8)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    Circle()
                        .fill(Color.white)
                        .frame(width: 9, height: 9)
                        .shadow(color: HowTuneDesign.accent.opacity(0.8), radius: 8)
                        .offset(x: max(0, width * progress - 4.5))
                }
            }
            .frame(height: 13)

            HStack {
                Text(formatTime(displayPlaybackTime))
                Spacer()
                Text(formatTime(duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.62))
        }
    }

    private func transportButton(
        systemImage: String,
        size: CGFloat,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white.opacity(isEnabled ? 0.88 : 0.28))
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var lyricsSection: some View {
        VStack(spacing: 12) {
            lyricsContent
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var lyricsContent: some View {
        if displayLyricsState == .loading {
            lyricsSkeleton
                .padding(.top, 12)
        } else if let message = displayLyricsState.message {
            lyricPanelMessage(icon: "text.badge.xmark", title: "歌詞を表示できません", message: message)
        } else if let loadedLyrics = displayLyrics, !loadedLyrics.lines.isEmpty {
            LazyVStack(spacing: 8) {
                ForEach(Array(loadedLyrics.lines.enumerated()), id: \.element.id) { index, line in
                    lyricScrollRow(
                        line: line,
                        index: index,
                        isHighlighted: loadedLyrics.isTimeSynced && line.contains(displayPlaybackTime),
                        showsTime: loadedLyrics.isTimeSynced
                    )
                }
            }
        } else {
            lyricPanelMessage(
                icon: "music.note",
                title: "歌詞がありません",
                message: "この曲の歌詞はまだ取得されていません。"
            )
        }
    }

    private func lyricScrollRow(
        line: TimedLyricLine,
        index: Int,
        isHighlighted: Bool,
        showsTime: Bool
    ) -> some View {
        Button {
            openHowCard(for: line)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                if showsTime {
                    Text(formatTime(line.startTime))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(isHighlighted ? HowTuneDesign.accent : .white.opacity(0.38))
                }

                Text(line.text.isEmpty ? "♪" : line.text)
                    .font(isHighlighted ? .title.weight(.heavy) : .title3.weight(.bold))
                    .foregroundStyle(isHighlighted ? .white : .white.opacity(0.58))
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                howActionStrip(index: index, isHighlighted: isHighlighted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, isHighlighted ? 16 : 12)
            .background(
                isHighlighted ? Color.white.opacity(0.09) : Color.white.opacity(0.03),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isHighlighted ? Color.white.opacity(0.14) : Color.white.opacity(0.04), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func howActionStrip(index: Int, isHighlighted: Bool) -> some View {
        HStack(spacing: 8) {
            Label("\(howCount(for: index)) How", systemImage: "bubble.left.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(isHighlighted ? HowTuneDesign.accent : .white.opacity(0.46))

            Label("コメント", systemImage: "text.bubble.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(isHighlighted ? 0.78 : 0.46))

            Spacer(minLength: 6)

            Label("AIと深掘り", systemImage: "sparkles")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(isHighlighted ? .white : .white.opacity(0.56))

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.34))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            isHighlighted ? Color.white.opacity(0.08) : Color.white.opacity(0.035),
            in: Capsule()
        )
    }

    private func lyricPanelMessage(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 224)
    }

    private var lyricsSkeleton: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(0..<7, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(index == 1 ? 0.16 : 0.08))
                    .frame(width: lyricSkeletonWidth(index: index), height: index == 1 ? 18 : 12)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .leading)
    }

    private func skeletonTrackRow(index: Int) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: trackSkeletonTitleWidth(index: index), height: 12)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: trackSkeletonArtistWidth(index: index), height: 10)
            }

            Spacer()
        }
        .redacted(reason: .placeholder)
    }

    private var searchSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color(.secondaryLabel))
                    TextField("曲名・アーティスト名で検索", text: $playback.searchQuery)
                        .foregroundStyle(Color(.label))
                        .submitLabel(.search)
                        .onSubmit { Task { await playback.search() } }
                        .disabled(!playback.canUseAppleMusicCatalog)
                    if !playback.searchQuery.isEmpty {
                        Button {
                            playback.searchQuery = ""
                            playback.searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if !playback.canUseAppleMusicCatalog {
                    searchEmptyState(
                        title: playback.appleMusicAccessStatus.title,
                        systemImage: playback.appleMusicAccessStatus.systemImage,
                        description: playback.appleMusicAccessStatus.message
                    )
                } else if playback.searchResults.isEmpty && playback.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    searchEmptyState(
                        title: "曲を検索",
                        systemImage: "music.note.list",
                        description: "再生したい曲名かアーティスト名を入力してください"
                    )
                } else if playback.searchResults.isEmpty {
                    searchEmptyState(
                        title: "検索結果がありません",
                        systemImage: "magnifyingglass",
                        description: "\(playback.searchQuery) に一致する曲が見つかりませんでした"
                    )
                } else {
                    List(playback.searchResults) { track in
                        Button {
                            Task {
                                let selectedTrack = await playback.select(track: track) ?? track
                                await lyrics.loadLyrics(for: LyricsTrackQuery(playbackTrack: selectedTrack))
                                showSearchSheet = false
                            }
                        } label: {
                            HStack(spacing: 12) {
                                artworkView(url: track.artworkURL, size: 50)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(track.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Color(.label))
                                        .lineLimit(1)
                                    Text(track.artistName)
                                        .font(.caption)
                                        .foregroundStyle(Color(.secondaryLabel))
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "play.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(HowTuneDesign.accent)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }

                Spacer()
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle("曲を選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { showSearchSheet = false }
                        .foregroundStyle(HowTuneDesign.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func searchEmptyState(title: String, systemImage: String, description: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Color(.secondaryLabel))
            Text(title)
                .font(.headline)
                .foregroundStyle(Color(.label))
            Text(description)
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    private func artworkView(url: URL?, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.black.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        artworkPlaceholder(size: size, failed: true)
                    case .empty:
                        ProgressView()
                            .tint(.white.opacity(0.7))
                    @unknown default:
                        artworkPlaceholder(size: size, failed: false)
                    }
                }
            } else {
                artworkPlaceholder(size: size, failed: false)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func diskArtworkView(url: URL?, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.12), Color.black.opacity(0.88)],
                        center: .center,
                        startRadius: 8,
                        endRadius: size / 2
                    )
                )

            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        artworkPlaceholder(size: size, failed: true)
                    case .empty:
                        ProgressView()
                            .tint(.white.opacity(0.7))
                    @unknown default:
                        artworkPlaceholder(size: size, failed: false)
                    }
                }
            } else {
                artworkPlaceholder(size: size, failed: false)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private func artworkPlaceholder(size: CGFloat, failed: Bool) -> some View {
        Image(systemName: failed ? "photo.badge.exclamationmark" : "music.note")
            .font(.system(size: size >= 80 ? 36 : 18))
            .foregroundStyle(.white.opacity(0.38))
    }

    private func startArtworkRotationIfNeeded() {
        guard displayIsPlaying, artworkRotation == 0 else {
            return
        }

        withAnimation(.linear(duration: 42).repeatForever(autoreverses: false)) {
            artworkRotation = -360
        }
    }

    private func openHowCard(for line: TimedLyricLine) {
        tappedLyric = line.text.isEmpty ? "♪" : line.text
        tappedLyricTranslation = nil
        selectedHowChatEvent = reactionEvent(for: line)
    }

    private func reactionEvent(for line: TimedLyricLine) -> ReactionEvent {
        let text = line.text.isEmpty ? "♪" : line.text
        let startTime = line.startTime
        let endTime = line.endTime ?? min(startTime + 6, displayTrack?.duration ?? startTime + 6)

        let canUseSensorScore = !viewModel.useManualMode && displayIsPlaying && airPodsMotion.isRecording
        let detectorScore = canUseSensorScore ? reactionDetector.currentScore : .empty
        let sampleScore = canUseSensorScore
            ? airPodsMotion.latestSample.map { MotionReactionScoreEstimator.score(from: $0) }
            : nil
        let score = detectorScore.intensity > 0 ? detectorScore : (sampleScore ?? .empty)
        let intensity = min(max(max(score.intensity, reactionLevel), 0.28), 1.0)
        let activeTags = score.activeTags(threshold: 0.35)
        let tags = activeTags.isEmpty
            ? fallbackTags(for: intensity, state: waveformReactionState)
            : activeTags

        return ReactionEvent(
            id: UUID(),
            startTime: startTime,
            endTime: max(endTime, startTime + 2),
            intensity: intensity,
            tags: tags,
            score: score,
            lyricLine: text,
            lyricTranslation: nil,
            heartRateTrend: intensity > 0.72 ? .rising : .stable
        )
    }

    private var reactionLevel: Double {
        min(max(musicPulseLevel * 0.72 + airPodsMotionIntensity * 0.44, 0.08), 1.0)
    }

    private func fallbackTags(for level: Double, state: HowTag) -> [HowTag] {
        if HowTag.scoreCases.contains(state) {
            return [state]
        }

        switch level {
        case 0.72...:
            return [.groove, .hype]
        case 0.46..<0.72:
            return [.groove, .immersion]
        default:
            return [.afterglow]
        }
    }

    private var musicPulseLevel: Double {
        guard displayIsPlaying else {
            return max(0.12, Double(outputVolume) * 0.35)
        }

        let pulse = 0.58
            + 0.20 * sin(displayPlaybackTime * 2.4)
            + 0.12 * sin(displayPlaybackTime * 5.2)
        return min(max(Double(outputVolume) * 0.42 + pulse * 0.58, 0.08), 1.0)
    }

    private var airPodsMotionIntensity: Double {
        if previewData != nil {
            return 0.34
        }

        return airPodsMotion.recentInteractionIntensity
    }

    private var visualizerTrackSeed: Int {
        let key = [
            displayTrack?.musicKitID,
            displayTrack?.title,
            displayTrack?.artistName
        ]
        .compactMap { $0 }
        .joined(separator: "|")

        return key.unicodeScalars.reduce(17) { partialResult, scalar in
            partialResult &* 31 &+ Int(scalar.value)
        }
    }

    private func syncAirPodsMotionCapture() {
        guard previewData == nil else {
            debugAirPodsMotion("preview data active; skip motion capture")
            return
        }

        guard !viewModel.useManualMode else {
            stopAirPodsMotionCapture(reason: "manual mode active")
            reactionDetector.stopSession(finalPlaybackTime: displayPlaybackTime)
            return
        }

        debugAirPodsMotion(
            "sync requested isPlaying=\(displayIsPlaying) "
                + "hasTrack=\(displayTrack != nil) "
                + "trackID=\(displayTrackIdentifier ?? "nil") "
                + "manualMode=\(viewModel.useManualMode) "
                + "status=\(airPodsMotion.status.title)"
        )

        guard displayIsPlaying, displayTrack != nil else {
            if airPodsMotion.isRecording {
                stopAirPodsMotionCapture(reason: "playback/track condition is not satisfied")
                reactionDetector.stopSession(finalPlaybackTime: displayPlaybackTime)
            } else {
                debugAirPodsMotion("capture not started because playback/track condition is not satisfied")
            }
            return
        }

        guard !airPodsMotion.isRecording else {
            debugAirPodsMotion("capture already recording")
            return
        }

        debugAirPodsMotion("starting capture")
        reactionDetector.startSession()
        airPodsMotion.start(playbackPositionProvider: playback.playbackPositionProvider())
    }

    private func stopAirPodsMotionCapture(reason: String) {
        guard airPodsMotion.isRecording else {
            debugAirPodsMotion("capture not recording; skip stop for \(reason)")
            return
        }

        debugAirPodsMotion("stopping capture because \(reason)")
        airPodsMotion.stop()
    }

    private func debugAirPodsMotion(_ message: String) {
        #if DEBUG
        print("[AirPodsMotion][Home] \(message)")
        #endif
    }

    private var waveformReactionState: HowTag {
        guard displayIsPlaying else {
            return .neutral
        }

        let score = reactionDetector.currentScore
        guard score.intensity > 0 else {
            return .neutral
        }

        if airPodsMotion.recentInteractionIntensity < 0.12,
           score.intensity < 0.32 {
            return .neutral
        }

        return score.dominantTag
    }

    private func lyricSkeletonWidth(index: Int) -> CGFloat {
        [250, 286, 190, 238, 154, 220, 272][index % 7]
    }

    private func trackSkeletonTitleWidth(index: Int) -> CGFloat {
        [172, 214, 148, 196, 164][index % 5]
    }

    private func trackSkeletonArtistWidth(index: Int) -> CGFloat {
        [110, 132, 96, 118, 104][index % 5]
    }

    private func howCount(for index: Int) -> Int {
        [4, 12, 3, 1, 2, 0, 5, 1][index % 8]
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let t = max(0, time)
        return String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

#Preview("歌詞表示") {
    HomeView(useManualMode: false, permissionState: PermissionState(), previewData: .lyricsShow)
}

#Preview("未選択") {
    HomeView(useManualMode: false, permissionState: PermissionState())
}

extension HomePreviewData {
    static let lyricsShow: HomePreviewData = {
        let track = PlaybackTrack(
            id: MusicItemID(rawValue: "preview-show"),
            musicKitID: "preview-show",
            title: "Show",
            artistName: "Ado",
            albumTitle: "Show",
            isrc: "JPPO02302806",
            hasLyrics: true,
            duration: 190,
            artworkURL: nil
        )
        let query = LyricsTrackQuery(playbackTrack: track)
        let lines = [
            TimedLyricLine(
                startTime: 14,
                endTime: 18,
                text: "(La-la-la, cue the lights and let the heart show)"
            ),
            TimedLyricLine(
                startTime: 18,
                endTime: 24,
                text: "Okay ここから独自のビート listen, listen"
            ),
            TimedLyricLine(
                startTime: 24,
                endTime: 29,
                text: "(La-la-la, ready for our tiny preview)"
            ),
            TimedLyricLine(
                startTime: 29,
                endTime: 33,
                text: "深く傾け"
            ),
            TimedLyricLine(
                startTime: 33,
                endTime: 38,
                text: "余韻ごと振り切っていこう"
            ),
            TimedLyricLine(
                startTime: 38,
                endTime: 44,
                text: "長い歌詞でも画面の端からはみ出さずに、複数行で自然に読める"
            )
        ]
        let lyrics = SynchronizedLyrics(
            providerName: "Preview",
            providerTrackID: "preview-show",
            query: query,
            lines: lines,
            isTimeSynced: true
        )

        return HomePreviewData(
            track: track,
            lyrics: lyrics,
            playbackTime: 20.5,
            isPlaying: true
        )
    }()
}
