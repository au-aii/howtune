import SwiftUI

enum NowPlayingTab {
    case lyrics, rangeSelection
}

struct NowPlayingView: View {
    let context: NowPlayingContext
    @ObservedObject var playback: PlaybackViewModel
    @ObservedObject var airPods: AirPodsMotionViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var lyricsViewModel = LyricsViewModel()
    @State private var activeTab: NowPlayingTab = .lyrics
    @State private var selectedLyricDraft: LyricHowCardDraft?

    private var song: Song { context.song }

    init(context: NowPlayingContext, playback: PlaybackViewModel, airPods: AirPodsMotionViewModel) {
        self.context = context
        self.playback = playback
        self.airPods = airPods
    }

    init(song: Song, playback: PlaybackViewModel, airPods: AirPodsMotionViewModel) {
        self.init(context: NowPlayingContext(song: song), playback: playback, airPods: airPods)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                mainContent
            }
            VStack {
                Spacer()
                nowPlayingFooter
            }
        }
        .task(id: lyricsTaskID) {
            await lyricsViewModel.loadLyrics(for: lyricsQuery)
        }
        .sheet(item: $selectedLyricDraft) { draft in
            LyricHowCardComposerView(song: song, draft: draft)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.black)
        }
    }

    private var mainContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    sharedPlaybackSurface
                    tabContent(proxy: proxy)
                    Color.clear.frame(height: 104)
                }
            }
        }
    }

    private var sharedPlaybackSurface: some View {
        VStack(spacing: 0) {
            circularVisualizer
                .padding(.top, 8)
            songInfo
            playbackControls
        }
    }

    @ViewBuilder
    private func tabContent(proxy: ScrollViewProxy) -> some View {
        switch activeTab {
        case .lyrics:
            lyricsCard(proxy: proxy)
                .padding(.top, 24)
        case .rangeSelection:
            ClipCreationInlineView(song: song)
                .padding(.top, 24)
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            .accessibilityLabel("戻る")

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var circularVisualizer: some View {
        ZStack {
            AirPodsReactiveWaveformView(
                isAnimating: playback.isPlaying,
                playbackTime: playback.playbackTime,
                audioLevel: waveformAudioLevel,
                motionIntensity: airPods.recentInteractionIntensity,
                trackSeed: waveformTrackSeed,
                reactionState: waveformReactionState
            )
            .frame(width: 264, height: 264)

            CircularArtworkView(song: song, size: 154, isPlaying: playback.isPlaying, showsCenterHole: true)
        }
        .frame(width: 282, height: 282)
        .padding(.vertical, 12)
    }

    private var songInfo: some View {
        VStack(spacing: 6) {
            Text(song.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text(song.artistName)
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
        .padding(.bottom, 8)
    }

    private var playbackControls: some View {
        VStack(spacing: 10) {
            let duration = song.duration
            let progress = duration > 0 ? min(max(playback.playbackTime / duration, 0), 1) : 0

            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                    if context.hasHighlight {
                        let highlightStartX = width * highlightStartProgress
                        let desiredHighlightWidth = width * max(0.02, highlightEndProgress - highlightStartProgress)
                        let highlightWidth = max(0, min(desiredHighlightWidth, width - highlightStartX))
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: highlightWidth)
                            .offset(x: highlightStartX)
                    }
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.3, blue: 0.3), Color(red: 0.18, green: 0.68, blue: 1.0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width * progress)
                }
            }
            .frame(height: 6)

            if context.hasHighlight {
                HStack {
                    Text("選択中 \(highlightRangeText)")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.3, blue: 0.3))
                    Spacer()
                }
            }

            HStack {
                Text(formatTime(playback.playbackTime))
                Spacer()
                Button {
                    Task { await playback.togglePlayback() }
                } label: {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                        .background(Color.white, in: Circle())
                        .offset(x: playback.isPlaying ? 0 : 2)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(formatTime(duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.64))
        }
        .padding(.horizontal, 28)
        .padding(.top, 10)
    }

    private func lyricsCard(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            lyricsContent(proxy: proxy)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
    }

    @ViewBuilder
    private func lyricsContent(proxy: ScrollViewProxy) -> some View {
        switch lyricsViewModel.state {
        case .idle, .loading:
            lyricsStatusMessage("歌詞を読み込み中")
        case .loaded:
            if let loadedLyrics = lyricsViewModel.lyrics, !loadedLyrics.lines.isEmpty {
                immersiveLyricsView(loadedLyrics, proxy: proxy)
            } else {
                lyricsStatusMessage("歌詞を表示できません")
            }
        case .unavailable(let message), .failed(let message):
            lyricsStatusMessage(message)
        }
    }

    private func immersiveLyricsView(
        _ loadedLyrics: SynchronizedLyrics,
        proxy: ScrollViewProxy
    ) -> some View {
        let activeID = activeLyricLineID(in: loadedLyrics)
        let activeIndex = activeLyricIndex(in: loadedLyrics)

        return LazyVStack(alignment: .leading, spacing: 20) {
            ForEach(Array(loadedLyrics.lines.enumerated()), id: \.element.id) { index, line in
                lyricLineView(
                    line: line,
                    isActive: activeID == line.id,
                    distanceFromActive: activeIndex.map { abs($0 - index) },
                    hasActiveLine: activeID != nil,
                    onTap: {
                        selectedLyricDraft = lyricDraft(for: line, at: index, in: loadedLyrics)
                    }
                )
                .id(line.id)
            }
        }
        .padding(.vertical, 26)
        .onAppear {
            scrollToActiveLyric(activeID, proxy: proxy, animated: false)
        }
        .onChange(of: activeID) { _, newValue in
            scrollToActiveLyric(newValue, proxy: proxy, animated: true)
        }
    }

    private func lyricLineView(
        line: TimedLyricLine,
        isActive: Bool,
        distanceFromActive: Int?,
        hasActiveLine: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        let opacity = lyricOpacity(isActive: isActive, distanceFromActive: distanceFromActive, hasActiveLine: hasActiveLine)
        let font: Font = isActive ? .title.weight(.heavy) : .title3.weight(.bold)
        let text = displayLyricText(line.text)

        return Button(action: onTap) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(text)
                    .font(font)
                    .foregroundStyle(.white.opacity(opacity))
                    .lineSpacing(4)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Image(systemName: "plus.bubble")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(isActive ? 0.52 : 0.22))
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Howカードを作成 \(text)")
        .animation(.easeInOut(duration: 0.24), value: opacity)
    }

    private func lyricsStatusMessage(_ message: String) -> some View {
        Text(message)
            .font(.title3.weight(.bold))
            .foregroundStyle(.white.opacity(0.64))
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 48)
    }

    private func activeLyricLineID(in lyrics: SynchronizedLyrics) -> String? {
        guard lyrics.isTimeSynced else { return nil }
        return lyrics.line(at: playback.playbackTime)?.id
    }

    private func activeLyricIndex(in lyrics: SynchronizedLyrics) -> Int? {
        guard let activeID = activeLyricLineID(in: lyrics) else { return nil }
        return lyrics.lines.firstIndex { $0.id == activeID }
    }

    private func lyricOpacity(isActive: Bool, distanceFromActive: Int?, hasActiveLine: Bool) -> Double {
        guard hasActiveLine else { return 0.82 }
        if isActive { return 1.0 }
        guard let distanceFromActive else { return 0.34 }
        if distanceFromActive <= 1 { return 0.64 }
        if distanceFromActive <= 3 { return 0.42 }
        return 0.28
    }

    private func lyricDraft(
        for line: TimedLyricLine,
        at index: Int,
        in lyrics: SynchronizedLyrics
    ) -> LyricHowCardDraft {
        let range = lyricRange(for: line, at: index, in: lyrics)
        return LyricHowCardDraft(
            lyricText: displayLyricText(line.text),
            songStart: range.start,
            songEnd: range.end,
            isEstimatedRange: range.isEstimated
        )
    }

    private func lyricRange(
        for line: TimedLyricLine,
        at index: Int,
        in lyrics: SynchronizedLyrics
    ) -> (start: TimeInterval, end: TimeInterval, isEstimated: Bool) {
        let duration = max(song.duration, 1)

        if lyrics.isTimeSynced {
            let start = normalizedLyricStart(line.startTime, duration: duration)
            let rawEnd = line.endTime ?? min(start + fallbackLyricDuration(for: line), duration)
            let end = normalizedLyricEnd(rawEnd, start: start, duration: duration)
            return (start, end, line.endTime == nil)
        }

        return estimatedLyricRange(at: index, in: lyrics.lines, duration: duration)
    }

    private func estimatedLyricRange(
        at index: Int,
        in lines: [TimedLyricLine],
        duration: TimeInterval
    ) -> (start: TimeInterval, end: TimeInterval, isEstimated: Bool) {
        let weights = lines.map { max(nonWhitespaceCharacterCount($0.text), 6) }
        let totalWeight = max(weights.reduce(0, +), 1)
        let safeIndex = min(max(index, 0), max(weights.count - 1, 0))
        let leadingWeight = weights.prefix(safeIndex).reduce(0, +)
        let lineWeight = weights.indices.contains(safeIndex) ? weights[safeIndex] : totalWeight

        let start = normalizedLyricStart(
            duration * TimeInterval(leadingWeight) / TimeInterval(totalWeight),
            duration: duration
        )
        let rawEnd = duration * TimeInterval(leadingWeight + lineWeight) / TimeInterval(totalWeight)
        let end = normalizedLyricEnd(rawEnd, start: start, duration: duration)
        return (start, end, true)
    }

    private func normalizedLyricStart(_ rawStart: TimeInterval, duration: TimeInterval) -> TimeInterval {
        let minimumDuration = minimumLyricDuration(for: duration)
        let latestStart = max(duration - minimumDuration, 0)
        return min(max(rawStart, 0), latestStart)
    }

    private func normalizedLyricEnd(
        _ rawEnd: TimeInterval,
        start: TimeInterval,
        duration: TimeInterval
    ) -> TimeInterval {
        let minimumDuration = minimumLyricDuration(for: duration)
        let lowerBound = min(start + minimumDuration, duration)
        let upperBound = max(duration, lowerBound)
        return min(max(rawEnd, lowerBound), upperBound)
    }

    private func minimumLyricDuration(for duration: TimeInterval) -> TimeInterval {
        min(min(max(duration * 0.012, 2), 5), duration)
    }

    private func fallbackLyricDuration(for line: TimedLyricLine) -> TimeInterval {
        let characterBasedDuration = TimeInterval(nonWhitespaceCharacterCount(line.text)) * 0.28
        return min(max(characterBasedDuration, 4), 12)
    }

    private func nonWhitespaceCharacterCount(_ text: String) -> Int {
        text.filter { !$0.isWhitespace }.count
    }

    private func displayLyricText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "♪" : trimmed
    }

    private func scrollToActiveLyric(_ id: String?, proxy: ScrollViewProxy, animated: Bool) {
        guard let id else { return }
        let action = {
            proxy.scrollTo(id, anchor: .center)
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.32), action)
        } else {
            action()
        }
    }

    private var lyricsQuery: LyricsTrackQuery {
        if let track = playback.currentTrack, matches(track: track, song: song) {
            return LyricsTrackQuery(playbackTrack: track)
        }

        return LyricsTrackQuery(
            title: song.title,
            artistName: song.artistName,
            duration: song.duration
        )
    }

    private var lyricsTaskID: String {
        [
            lyricsQuery.musicKitID ?? "",
            lyricsQuery.title,
            lyricsQuery.artistName,
            lyricsQuery.albumName ?? "",
            lyricsQuery.isrc ?? "",
            lyricsQuery.duration.map { String(Int($0.rounded())) } ?? ""
        ]
        .joined(separator: "|")
    }

    private func matches(track: PlaybackTrack, song: Song) -> Bool {
        if let musicKitID = song.musicKitID, track.musicKitID == musicKitID {
            return true
        }

        let trackTitle = normalizedMatchText(track.title)
        let songTitle = normalizedMatchText(song.title)
        let trackArtist = normalizedMatchText(track.artistName)
        let songArtist = normalizedMatchText(song.artistName)

        return !songTitle.isEmpty
            && !songArtist.isEmpty
            && trackTitle.contains(songTitle)
            && trackArtist.contains(songArtist)
    }

    private func normalizedMatchText(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let seconds = max(0, Int(time))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var highlightStart: TimeInterval {
        min(max(context.highlightStart ?? context.initialPlaybackTime, 0), max(song.duration, 1))
    }

    private var highlightEnd: TimeInterval {
        let duration = max(song.duration, 1)
        let rawEnd = context.highlightEnd ?? max(highlightStart + 12, context.initialPlaybackTime)
        return min(max(rawEnd, highlightStart), duration)
    }

    private var highlightStartProgress: Double {
        let duration = max(song.duration, 1)
        return min(max(highlightStart / duration, 0), 1)
    }

    private var highlightEndProgress: Double {
        let duration = max(song.duration, 1)
        return min(max(highlightEnd / duration, highlightStartProgress), 1)
    }

    private var highlightRangeText: String {
        "\(formatTime(highlightStart)) - \(formatTime(highlightEnd))"
    }

    private var waveformAudioLevel: Double {
        guard playback.isPlaying else {
            return 0.18
        }

        let pulse = 0.58
            + 0.20 * sin(playback.playbackTime * 2.4)
            + 0.12 * sin(playback.playbackTime * 5.2)
        return min(max(pulse, 0.12), 1.0)
    }

    private var waveformTrackSeed: Int {
        [song.firestoreSongID, song.title, song.artistName]
            .joined(separator: "|")
            .unicodeScalars
            .reduce(17) { partialResult, scalar in
                partialResult &* 31 &+ Int(scalar.value)
            }
    }

    private var waveformReactionState: HowTag {
        guard playback.isPlaying else { return .neutral }
        return airPods.recentInteractionIntensity > 0.28 ? .groove : .neutral
    }

    private var nowPlayingFooter: some View {
        HStack(spacing: 0) {
            footerTabButton(tab: .lyrics, title: "歌詞", systemImage: "music.note.list")
            footerTabButton(tab: .rangeSelection, title: "範囲選択", systemImage: "slider.horizontal.3")
        }
        .padding(4)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
    }

    private func footerTabButton(tab: NowPlayingTab, title: String, systemImage: String) -> some View {
        let isActive = activeTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { activeTab = tab }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isActive ? Color.black : Color.white.opacity(0.58))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(isActive ? Color.white : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NowPlayingView(song: Song(
        id: UUID(),
        title: "ライラック",
        artistName: "Mrs. GREEN APPLE",
        gradientColors: [Color(red: 0.85, green: 0.55, blue: 0.35), Color(red: 0.65, green: 0.35, blue: 0.5)],
        durationSeconds: 272
    ), playback: PlaybackViewModel(), airPods: AirPodsMotionViewModel())
}
