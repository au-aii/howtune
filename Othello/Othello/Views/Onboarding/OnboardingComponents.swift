import SwiftUI

// MARK: - デザイントークン（HomeViewに合わせた統一値）
enum HowTuneDesign {
    static let accent = Color(red: 1.0, green: 0.3, blue: 0.3)
    static let accentGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.45, blue: 0.45), Color(red: 0.85, green: 0.15, blue: 0.2)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let background = Color(.systemBackground)
    static let surface = Color(.secondarySystemBackground)
    static let divider = Color(.separator)
}

// MARK: - プログレスインジケーター
func progressIndicator(current: Int, total: Int) -> some View {
    HStack(spacing: 8) {
        ForEach(1...total, id: \.self) { i in
            Capsule()
                .fill(i <= current ? HowTuneDesign.accent : Color(.systemGray4))
                .frame(height: 3)
        }
    }
}

// MARK: - 目的説明カード
func purposeCard(icon: String, title: String, body: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
        Image(systemName: icon)
            .foregroundStyle(HowTuneDesign.accent)
            .font(.title3)
            .frame(width: 28)
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color(.label))
            Text(body)
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    .padding(16)
    .background(HowTuneDesign.surface, in: RoundedRectangle(cornerRadius: 12))
}

// MARK: - 許可済みバッジ
func authorizedBadge(label: String) -> some View {
    Label(label, systemImage: "checkmark.circle.fill")
        .font(.subheadline)
        .foregroundStyle(Color.green)
}

// MARK: - スキップボタン
func skipButton(label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(label)
            .font(.subheadline)
            .foregroundStyle(Color(.secondaryLabel))
    }
}

// MARK: - メインアクションボタン
func primaryButton(label: String, icon: String? = nil, isLoading: Bool = false, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.85)
            } else if let icon {
                Image(systemName: icon)
            }
            Text(isLoading ? "確認中…" : label)
                .fontWeight(.semibold)
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            ZStack {
                if isLoading {
                    Color.gray.opacity(0.4)
                } else {
                    HowTuneDesign.accentGradient
                }
            }
        )
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: HowTuneDesign.accent.opacity(isLoading ? 0 : 0.4), radius: 10, y: 4)
    }
    .disabled(isLoading)
}
