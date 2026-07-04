import SwiftUI

struct ContentView: View {
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var onboardingVM = OnboardingViewModel()
    @StateObject private var playback = PlaybackViewModel()
    @StateObject private var airPods = AirPodsMotionViewModel()
    @State private var nowPlayingContext: NowPlayingContext?
    @State private var showNowPlaying: Bool = false

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
            Color.black.ignoresSafeArea()

            ForYouView(nowPlayingContext: $nowPlayingContext, playback: playback)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomOverlay
        }
        .task {
            await playback.onAppear()
        }
        .onChange(of: nowPlayingContext?.id) { _, newValue in
            if newValue != nil {
                airPods.start(playbackPositionProvider: playback.playbackPositionProvider())
            } else {
                airPods.stop()
                showNowPlaying = false
            }
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
