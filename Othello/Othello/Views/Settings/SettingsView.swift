import FirebaseAuth
import SwiftUI

/// 設定画面。検証用の一時ログアウトボタンを正式なログアウト導線に昇格させたもの。
struct SettingsView: View {
    @ObservedObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("reactionDataConsentV1") private var reactionConsent = false

    var body: some View {
        NavigationStack {
            List {
                Section("アカウント") {
                    if let email = Auth.auth().currentUser?.email {
                        LabeledContent("ログイン中", value: email)
                    }
                    Button(role: .destructive) {
                        authVM.signOut()
                        dismiss()
                    } label: {
                        Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                Section("反応データ") {
                    Toggle("反応データの蓄積に同意", isOn: $reactionConsent)
                    Text(
                        "オンにすると、曲を聴いたときの頭の動きから検出した反応（区間とタグ）を匿名で蓄積し、インサイトの精度向上に使います。本人だけが閲覧でき、いつでもオフにできます。"
                    )
                    .font(.footnote)
                    .foregroundStyle(Color(.secondaryLabel))
                }

                Section("アプリについて") {
                    LabeledContent("アプリ", value: "HowTune")
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
                        as? String
                    {
                        LabeledContent("バージョン", value: version)
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView(authVM: AuthViewModel())
}
