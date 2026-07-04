import SwiftUI

struct OnboardingMusicPage: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var isRequesting = false

    var body: some View {
        ZStack {
            HowTuneDesign.background.ignoresSafeArea()

            VStack(spacing: 0) {
                progressIndicator(current: 1, total: 2)
                    .padding(.top, 60)
                    .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 28) {
                    ZStack {
                        Circle()
                            .fill(HowTuneDesign.accent.opacity(0.15))
                            .frame(width: 100, height: 100)
                        Image(systemName: "music.note")
                            .font(.system(size: 48))
                            .foregroundStyle(HowTuneDesign.accent)
                    }

                    VStack(spacing: 10) {
                        Text("Apple Music の使用")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("曲の再生と再生位置の同期に使用します。Apple Music の契約がない場合、曲の再生は利用できません。")
                            .font(.body)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)

                    VStack(spacing: 10) {
                        purposeCard(
                            icon: "music.note.list",
                            title: "曲と再生位置を同期",
                            body: "How カードを曲中の時間に紐づけるために使います。"
                        )
                        purposeCard(
                            icon: "lock.shield.fill",
                            title: "必要な権限だけを使用",
                            body: "Apple Music の認証と契約状態だけを確認します。"
                        )

                        if viewModel.appleMusicAccessStatus.shouldShowNotice {
                            AppleMusicAccessBanner(status: viewModel.appleMusicAccessStatus)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                VStack(spacing: 14) {
                    switch viewModel.appleMusicAccessStatus {
                    case .authorized:
                        authorizedBadge(label: "Apple Music を利用できます")
                        nextButton
                    case .checking:
                        primaryButton(
                            label: "Apple Music を確認する",
                            icon: "music.note",
                            isLoading: true
                        ) {}
                    case .subscriptionRequired:
                        requestButton(label: "契約状態を再確認する")
                        skipButton(label: "AirPods 設定へ進む") {
                            withAnimation { viewModel.currentPage = 2 }
                        }
                    default:
                        requestButton(label: "Apple Music を許可する")
                        skipButton(label: "あとで設定して進む") {
                            withAnimation { viewModel.currentPage = 2 }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }

    private var nextButton: some View {
        primaryButton(label: "次へ", icon: "arrow.right") {
            withAnimation { viewModel.currentPage = 2 }
        }
    }

    private func requestButton(label: String) -> some View {
        primaryButton(label: label, icon: "music.note", isLoading: isRequesting) {
            isRequesting = true
            Task {
                await viewModel.requestAppleMusicPermission()
                isRequesting = false
            }
        }
    }
}

#Preview {
    OnboardingMusicPage(viewModel: OnboardingViewModel())
}
