import SwiftUI

struct ContentView: View {
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var onboardingVM = OnboardingViewModel()
    @StateObject private var playback = PlaybackViewModel()
    @StateObject private var airPods = AirPodsMotionViewModel()
    @State private var nowPlayingContext: NowPlayingContext?
    @State private var showNowPlaying: Bool = false
    @State private var showSettings: Bool = false
    @StateObject private var reactionDetector = ReactionDetectionViewModel()
    @AppStorage("reactionDataConsentV1") private var reactionConsent = false
    @State private var lastSessionSong: Song?

    var body: some View {
        if !authVM.isLoggedIn {
            LoginView(authVM: authVM)
        } else if onboardingVM.isOnboardingComplete {
            mainView
        } else {
            onboardingFlow
        }
    }

    private var onboardingFlow: some View {
        TabView(selection: $onboardingVM.currentPage) {
            OnboardingWelcomePage(currentPage: $onboardingVM.currentPage).tag(0)
            OnboardingMusicPage(viewModel: onboardingVM).tag(1)
            OnboardingMotionPage(viewModel: onboardingVM).tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .animation(.easeInOut, value: onboardingVM.currentPage)
    }

    private var mainView: some View {
        ZStack(alignment: .bottom) {
            Color(.systemBackground).ignoresSafeArea()

            ForYouView(nowPlayingContext: $nowPlayingContext, playback: playback)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomOverlay
        }
        .overlay(alignment: .topLeading) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(.label))
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.leading, 16)
            .padding(.top, 8)
            .accessibilityLabel("設定")
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(authVM: authVM)
        }
        .task {
            await playback.onAppear()
        }
        .onChange(of: nowPlayingContext?.id) { _, newValue in
            if newValue != nil {
                airPods.start(playbackPositionProvider: playback.playbackPositionProvider())
                reactionDetector.startSession()
                lastSessionSong = nowPlayingContext?.song
            } else {
                airPods.stop()
                reactionDetector.stopSession(finalPlaybackTime: playback.playbackTime)
                showNowPlaying = false
                persistReactionSessionIfConsented()
            }
        }
        .onChange(of: airPods.latestSample) { _, sample in
            if let sample { reactionDetector.ingest(sample) }
        }
        .alert("再生位置が取得できません", isPresented: $playback.positionUnavailableAlertShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(playback.positionUnavailableMessage)
        }
        .fullScreenCover(isPresented: $showNowPlaying) {
            if let context = nowPlayingContext {
                NowPlayingView(context: context, playback: playback, airPods: airPods)
            }
        }
    }

    // 曲停止時: 同意があれば検出した反応セッションを保存（moat P-a）
    private func persistReactionSessionIfConsented() {
        guard reactionConsent, let song = lastSessionSong else { return }
        let events = reactionDetector.events
        lastSessionSong = nil
        guard !events.isEmpty else { return }
        Task {
            try? await FirebaseAPI.shared.createReactionSession(
                song: song,
                events: events
            )
        }
    }

    private var bottomOverlay: some View {
        VStack(spacing: 8) {
            if playback.shouldShowAppleMusicAccessNotice {
                AppleMusicAccessBanner(status: playback.appleMusicAccessStatus)
            }

            if nowPlayingContext != nil {
                GlobalMiniPlayerView(song: nowPlayingContext?.song, onTap: {
                    showNowPlaying = true
                }, playback: playback)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

#Preview {
    ContentView()
}
