import SwiftUI

struct OnboardingMotionPage: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var isRequesting = false

    var body: some View {
        ZStack {
            HowTuneDesign.background.ignoresSafeArea()

            VStack(spacing: 0) {
                progressIndicator(current: 2, total: 2)
                    .padding(.top, 60)
                    .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 28) {
                    ZStack {
                        Circle()
                            .fill(HowTuneDesign.accent.opacity(0.15))
                            .frame(width: 100, height: 100)
                        Image(systemName: "airpods")
                            .font(.system(size: 48))
                            .foregroundStyle(HowTuneDesign.accent)
                    }

                    VStack(spacing: 10) {
                        Text("AirPods 頭部モーションの使用")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("音楽を聴いているときの頭の動きを検知します。あなたの「聴き方」の特徴を分析するためだけに使用します。")
                            .font(.body)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)

                    VStack(spacing: 10) {
                        purposeCard(
                            icon: "lock.shield.fill",
                            title: "端末内処理・外部送信なし",
                            body: "モーションデータはデバイス上でのみ処理されます。"
                        )

                        if !viewModel.permissionState.airPodsAvailable {
                            purposeCard(
                                icon: "airpods",
                                title: "AirPods 未接続",
                                body: "対応AirPodsがない場合は、曲中の反応を手動で記録できます。"
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                VStack(spacing: 14) {
                    if viewModel.permissionState.motion == .authorized {
                        authorizedBadge(label: "AirPods 頭部モーションが利用できます")
                        nextButton
                    } else {
                        primaryButton(
                            label: "AirPods を確認する",
                            icon: "airpods",
                            isLoading: isRequesting
                        ) {
                            isRequesting = true
                            Task {
                                await viewModel.requestMotionPermission()
                                isRequesting = false
                            }
                        }

                        skipButton(label: "スキップして手動モードへ進む") {
                            viewModel.proceedToManualMode()
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }

    private var nextButton: some View {
        primaryButton(label: "HowTune をはじめる", icon: "music.note") {
            viewModel.completeOnboarding()
        }
    }
}

#Preview {
    OnboardingMotionPage(viewModel: OnboardingViewModel())
}
