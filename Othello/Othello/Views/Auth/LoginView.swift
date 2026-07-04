import SwiftUI

struct LoginView: View {
    @ObservedObject var authVM: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @FocusState private var focus: LoginField?

    private enum LoginField { case email, password }

    var body: some View {
        ZStack {
            HowTuneDesign.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(HowTuneDesign.accentGradient)
                            .frame(width: 80, height: 80)
                            .shadow(color: HowTuneDesign.accent.opacity(0.5), radius: 20)
                        Image(systemName: "headphones")
                            .font(.system(size: 36))
                            .foregroundStyle(.white)
                    }
                    Text("HowTune")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

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
                        SecureField("パスワード", text: $password)
                            .foregroundStyle(.white)
                            .textContentType(.password)
                            .focused($focus, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { Task { await authVM.signIn(email: email, password: password) } }
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
                .padding(.bottom, 24)

                primaryButton(label: "ログイン", icon: "arrow.right", isLoading: authVM.isLoading) {
                    Task { await authVM.signIn(email: email, password: password) }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                Button {
                    authVM.errorMessage = nil
                    showSignUp = true
                } label: {
                    Text("アカウントをお持ちでない方は ")
                        .foregroundStyle(.gray)
                    + Text("新規登録")
                        .foregroundStyle(HowTuneDesign.accent)
                }
                .font(.subheadline)
                .padding(.bottom, 48)
            }
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView(authVM: authVM)
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
