import SwiftUI

struct SignUpView: View {
    @ObservedObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirm = ""
    @FocusState private var focus: SignUpField?

    private enum SignUpField { case email, password, confirmPassword }

    private var passwordMismatch: Bool {
        !passwordConfirm.isEmpty && password != passwordConfirm
    }

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !passwordMismatch && !authVM.isLoading
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HowTuneDesign.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Text("アカウント作成")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("メールアドレスで登録")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 16) {
                        fieldRow(icon: "envelope") {
                            TextField("メールアドレス", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .foregroundStyle(.white)
                                .focused($focus, equals: .email)
                                .submitLabel(.next)
                                .onSubmit { focus = .password }
                        }

                        fieldRow(icon: "lock") {
                            SecureField("パスワード（6文字以上）", text: $password)
                                .foregroundStyle(.white)
                                .textContentType(.newPassword)
                                .focused($focus, equals: .password)
                                .submitLabel(.next)
                                .onSubmit { focus = .confirmPassword }
                        }

                        fieldRow(icon: "lock.fill") {
                            SecureField("パスワード確認", text: $passwordConfirm)
                                .foregroundStyle(.white)
                                .textContentType(.newPassword)
                                .focused($focus, equals: .confirmPassword)
                                .submitLabel(.done)
                                .onSubmit { if canSubmit { Task { await authVM.signUp(email: email, password: password) } } }
                        }

                        if passwordMismatch {
                            Text("パスワードが一致しません")
                                .font(.caption)
                                .foregroundStyle(HowTuneDesign.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }

                        if let error = authVM.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(HowTuneDesign.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 24)

                    primaryButton(
                        label: "アカウントを作成",
                        icon: "person.badge.plus",
                        isLoading: authVM.isLoading
                    ) {
                        Task { await authVM.signUp(email: email, password: password) }
                    }
                    .padding(.horizontal, 24)
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1.0 : 0.5)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(HowTuneDesign.accent)
                }
            }
            .onChange(of: authVM.isLoggedIn) { _, isLoggedIn in
                if isLoggedIn { dismiss() }
            }
        }
    }

    private func fieldRow<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.gray)
                .frame(width: 20)
            content()
        }
        .padding(16)
        .background(HowTuneDesign.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
