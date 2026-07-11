import SwiftUI

struct HowChatView: View {
    @StateObject private var vm: HowChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var pulseScale: CGFloat = 1.0
    @State private var navigateToHowCard = false
    @FocusState private var isInputFocused: Bool

    init(event: ReactionEvent, peak: PeakMoment? = nil) {
        _vm = StateObject(wrappedValue: HowChatViewModel(event: event, peak: peak))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                VStack(spacing: 0) {
                    reactionHeader(event: vm.event)
                    Divider().overlay(Color(.separator))
                    messageList
                    Divider().overlay(Color(.separator))
                    inputArea
                }
            }
            .navigationTitle("この瞬間について")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(HowTuneDesign.accent)
                }
            }
            .navigationDestination(isPresented: $navigateToHowCard) {
                HowCardCreationView(event: vm.event, messages: vm.messages, sessionID: vm.sessionID)
            }
        }
        .presentationDetents([.large])
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear { vm.start() }
        .onTapGesture { isInputFocused = false }
    }

    // MARK: - 反応地点ヘッダー（可視化）

    @ViewBuilder
    private func reactionHeader(event: ReactionEvent) -> some View {
        let dominant = event.tags.first
        let color = dominant?.color ?? .white

        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                // モメンタムパルス
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 64, height: 64)
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                            value: pulseScale
                        )
                    Circle()
                        .fill(color.opacity(0.3))
                        .frame(width: 44, height: 44)
                    Text(dominant.map { tagEmoji($0) } ?? "🎵")
                        .font(.system(size: 22))
                }
                .onAppear { pulseScale = 1.18 }

                VStack(alignment: .leading, spacing: 4) {
                    Text(formatTime(event.startTime))
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(Color(.secondaryLabel))

                    if let lyric = event.lyricLine {
                        Text(lyric)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color(.label))
                            .lineLimit(2)
                    }

                    HStack(spacing: 6) {
                        ForEach(event.tags, id: \.self) { tag in
                            Text(tag.label)
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(tag.color.opacity(0.8), in: Capsule())
                        }
                        // 強度バー
                        intensityBar(value: event.intensity, color: color)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            // 心拍トレンド
            HStack(spacing: 6) {
                Image(systemName: event.heartRateTrend.systemImage)
                    .font(.caption)
                    .foregroundStyle(event.heartRateTrend.color)
                Text("心拍 \(event.heartRateTrend.label)")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                Spacer()
                Text("強度 \(Int(event.intensity * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - 強度バー

    private func intensityBar(value: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.secondarySystemBackground)).frame(height: 4)
                Capsule().fill(color).frame(width: geo.size.width * value, height: 4)
            }
        }
        .frame(width: 60, height: 4)
    }

    // MARK: - メッセージ一覧

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.messages) { msg in
                        messageBubble(msg)
                            .id(msg.id)
                    }
                    if vm.state == .loading {
                        typingIndicator
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .onChange(of: vm.messages.count) { _, _ in
                withAnimation { proxy.scrollTo(vm.messages.last?.id) }
            }
            .onChange(of: vm.state) { _, _ in
                withAnimation { proxy.scrollTo(vm.messages.last?.id) }
            }
        }
    }

    @ViewBuilder
    private func messageBubble(_ msg: HowChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if msg.sender == .ai {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(HowTuneDesign.accent)
                    .frame(width: 20)
                Text(msg.text)
                    .font(.subheadline)
                    .foregroundStyle(Color(.label))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                Text(msg.text)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(HowTuneDesign.accent.opacity(0.85), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(duration: 0.35), value: msg.id)
    }

    private var typingIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(HowTuneDesign.accent)
                .frame(width: 20)
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color(.secondaryLabel))
                        .frame(width: 6, height: 6)
                        .opacity(vm.state == .loading ? 1 : 0.3)
                        .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: vm.state)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer()
        }
    }

    // MARK: - 入力エリア

    @ViewBuilder
    private var inputArea: some View {
        if vm.state == .done {
            doneState
        } else {
            VStack(spacing: 10) {
                if !vm.choices.isEmpty {
                    choiceButtons
                }
                freeInputRow
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }

    private var choiceButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.choices) { choice in
                    Button {
                        vm.selectChoice(choice)
                    } label: {
                        Text(choice.label)
                            .font(.subheadline)
                            .foregroundStyle(Color(.label))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground), in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    }
                    .disabled(vm.state == .loading)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var freeInputRow: some View {
        HStack(spacing: 10) {
            TextField("自由に入力…", text: $vm.freeInputText)
                .font(.subheadline)
                .foregroundStyle(Color(.label))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22))
                .focused($isInputFocused)
                .submitLabel(.send)
                .onSubmit { vm.submitFreeInput() }
                .disabled(vm.state == .loading)

            Button {
                vm.submitFreeInput()
                isInputFocused = false
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        vm.freeInputText.isEmpty || vm.state == .loading
                            ? Color.gray.opacity(0.4)
                            : HowTuneDesign.accent
                    )
            }
            .disabled(vm.freeInputText.isEmpty || vm.state == .loading)
        }
        .padding(.bottom, isInputFocused ? 0 : 0)
    }

    private var doneState: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(HowTuneDesign.accent)
                Text("気持ちを言語化できました")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Button {
                navigateToHowCard = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                    Text("Howカードを作る")
                        .font(.subheadline.bold())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.45, blue: 0.45), Color(red: 0.85, green: 0.15, blue: 0.2)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .shadow(color: .red.opacity(0.4), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Helpers

    private func formatTime(_ t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }

    private func tagEmoji(_ tag: HowTag) -> String {
        switch tag {
        case .groove:    return "🎵"
        case .hype:      return "🔥"
        case .chill:     return "❄️"
        case .immersion: return "🎧"
        case .hit:       return "💫"
        case .afterglow: return "✨"
        case .neutral:   return "○"
        }
    }
}

// MARK: - Preview

#Preview {
    HowChatView(event: ReactionEvent.mockSamples(trackDuration: 200)[1])
}
