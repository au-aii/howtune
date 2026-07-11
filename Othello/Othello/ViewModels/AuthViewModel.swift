import Combine
import FirebaseAuth
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    /// 現在ログイン中ユーザーのメール（設定画面の表示用）。
    var userEmail: String? { Auth.auth().currentUser?.email }

    private var authStateHandler: AuthStateDidChangeListenerHandle?

    init() {
        isLoggedIn = Auth.auth().currentUser != nil
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isLoggedIn = user != nil
            }
        }
    }

    deinit {
        if let handler = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handler)
        }
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            errorMessage = localizedError(error)
        }
        isLoading = false
    }

    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            do {
                try await FirebaseAPI.shared.createUserDocument(from: result.user)
            } catch let createUserError {
                do {
                    try await result.user.delete()
                    try Auth.auth().signOut()
                } catch let rollbackError {
                    throw FirebaseAPIError.signOutRollbackFailed(original: createUserError, signOut: rollbackError)
                }
                throw createUserError
            }
        } catch {
            errorMessage = localizedError(error)
        }
        isLoading = false
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = localizedError(error)
        }
    }

    private func localizedError(_ error: Error) -> String {
        if case FirebaseAPIError.signOutRollbackFailed = error {
            return "ユーザー情報の保存とログアウトに失敗しました"
        }
        if error is FirebaseAPIError {
            return "ユーザー情報の保存に失敗しました"
        }

        let code = AuthErrorCode(rawValue: (error as NSError).code)
        switch code {
        case .invalidEmail:
            return "メールアドレスの形式が正しくありません"
        case .wrongPassword, .invalidCredential:
            return "メールアドレスまたはパスワードが違います"
        case .emailAlreadyInUse:
            return "このメールアドレスはすでに使用されています"
        case .weakPassword:
            return "パスワードは6文字以上にしてください"
        case .userNotFound:
            return "アカウントが見つかりません"
        case .networkError:
            return "ネットワークエラーが発生しました"
        default:
            return "エラーが発生しました。もう一度お試しください"
        }
    }
}
