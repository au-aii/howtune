import SwiftUI

/// Howカード投稿後の共鳴マッチング画面（FR-RES-04/05/07）。
/// 同地点反応者が現れると量子→発火の演出が走り、🔥タップで DM に入る。
struct ResonanceMatchView: View {
    let songId: String
    let songTitle: String?
    let myStart: TimeInterval
    let myEnd: TimeInterval

    @StateObject private var matchService = ResonanceMatchService()
    @State private var ignitionStart = Date.distantPast
    // マッチ待機中のパルスアニメーション起点。cycleDuration ごとにリセットして演出を周回させる
    @State private var pulseEpoch: Date = Date()
    @Environment(\.dismiss) private var dismiss

    init(songId: String, songTitle: String? = nil, myInterval: (start: TimeInterval, end: TimeInterval)) {
        self.songId = songId
        self.songTitle = songTitle
        self.myStart = myInterval.start
        self.myEnd = myInterval.end
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        ignitionArea
                        sameSpotSection
                        otherSpotSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .task {
                    while !Task.isCancelled, !hasSameSpot {
                        try? await Task.sleep(for: .seconds(ResonanceVisualConfig.cycleDuration))
                        guard !Task.isCancelled, !hasSameSpot else { break }
                        pulseEpoch = Date()
                    }
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("共鳴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .navigationDestination(for: ResonanceReactor.self) { reactor in
                ResonanceDMView(reactor: reactor)
            }
        }
        .onAppear {
            matchService.start(songId: songId, myInterval: (myStart, myEnd))
        }
        .onDisappear { matchService.stop() }
        .onChange(of: matchService.sameSpotReactors.count) { old, new in
            if new > old { ignitionStart = Date() }   // 同地点マッチ出現 → 発火
        }
    }

    // MARK: - 演出

    private var ignitionArea: some View {
        ZStack {
            QuantumIgnitionView(startDate: hasSameSpot ? ignitionStart : pulseEpoch)
                .frame(height: 260)
            if !hasSameSpot {
                VStack(spacing: 8) {
                    Text("◌")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("同じ瞬間に反応した人を探しています…")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 260)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var hasSameSpot: Bool { !matchService.sameSpotReactors.isEmpty }

    // MARK: - 同地点（🔥）

    private var sameSpotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🔥 同じ瞬間で共鳴")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(matchService.sameSpotReactors.count)人")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)
            }
            if matchService.sameSpotReactors.isEmpty {
                Text("まだいません。流れてきたら火がつきます。")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                ForEach(matchService.sameSpotReactors) { reactor in
                    NavigationLink(value: reactor) {
                        reactorRow(reactor, accent: .orange, mark: "🔥")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 別地点

    private var otherSpotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("別の場所で反応した人")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.85))
            if matchService.otherSpotReactors.isEmpty {
                Text("まだいません。")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                ForEach(matchService.otherSpotReactors) { reactor in
                    NavigationLink(value: reactor) {
                        reactorRow(reactor, accent: Color(red: 0.4, green: 0.7, blue: 1.0), mark: "✦")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func reactorRow(_ reactor: ResonanceReactor, accent: Color, mark: String) -> some View {
        HStack(spacing: 12) {
            Text(mark)
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(reactor.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(reactor.spotLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(accent)
                }
                Text(reactor.comment.isEmpty ? "（コメントなし）" : reactor.comment)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "bubble.left.fill")
                .font(.caption)
                .foregroundStyle(accent)
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(0.25), lineWidth: 1)
        )
    }
}
