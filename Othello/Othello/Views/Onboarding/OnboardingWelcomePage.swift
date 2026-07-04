import SwiftUI

struct OnboardingWelcomePage: View {
    @Binding var currentPage: Int

    var body: some View {
        ZStack {
            HowTuneDesign.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ロゴ
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(HowTuneDesign.accentGradient)
                            .frame(width: 100, height: 100)
                            .shadow(color: HowTuneDesign.accent.opacity(0.5), radius: 20)
                        Image(systemName: "headphones")
                            .font(.system(size: 44))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 6) {
                        Text("HowTune")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(.label))
                        Text("How でつながる音楽体験")
                            .font(.subheadline)
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }

                Spacer()

                // 機能説明
                VStack(spacing: 12) {
                    featureRow(
                        icon: "airpods",
                        title: "頭部の反応を感知",
                        description: "AirPods の頭部モーションで、音楽への自然な反応を記録"
                    )
                    Divider().overlay(HowTuneDesign.divider)
                    featureRow(
                        icon: "music.note",
                        title: "Apple Music と同期",
                        description: "曲の再生位置に合わせて、聴きどころを記録"
                    )
                    Divider().overlay(HowTuneDesign.divider)
                    featureRow(
                        icon: "person.2.fill",
                        title: "同じ「How」でつながる",
                        description: "聴き方が近い人と出会い、音楽体験を共有"
                    )
                }
                .padding(20)
                .background(HowTuneDesign.surface, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)

                Spacer()

                // CTA
                primaryButton(label: "はじめる", icon: "arrow.right") {
                    withAnimation { currentPage = 1 }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(HowTuneDesign.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            }
            Spacer()
        }
    }
}

#Preview {
    OnboardingWelcomePage(currentPage: .constant(0))
}
