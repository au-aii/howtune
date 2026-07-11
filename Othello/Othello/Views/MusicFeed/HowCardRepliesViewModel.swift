import Foundation
import Combine

@MainActor
final class HowCardRepliesViewModel: ObservableObject {
    let post: FeedPost
    @Published private(set) var replies: [HowCardReply] = []
    @Published private(set) var replyCount: Int
    @Published private(set) var isLoading = false
    @Published private(set) var isPosting = false
    @Published var draft = ""
    @Published var errorMessage: String?

    private let api: FirebaseAPI

    var canPost: Bool {
        normalizedDraft != nil && !isPosting
    }

    init(post: FeedPost, api: FirebaseAPI? = nil) {
        self.post = post
        self.replyCount = post.commentCount
        self.api = api ?? .shared
    }

    func load() async {
        guard let cardID = post.cardID else {
            errorMessage = "Howカードが見つかりません"
            return
        }

        isLoading = replies.isEmpty
        errorMessage = nil
        defer { isLoading = false }

        do {
            replies = try await api.fetchHowCardReplies(cardID: cardID, limit: 100)
            replyCount = max(replyCount, replies.count)
        } catch {
            errorMessage = "返信を取得できませんでした"
        }
    }

    func postReply() async -> Int? {
        guard !isPosting else {
            return nil
        }
        guard let cardID = post.cardID, let body = normalizedDraft else {
            return nil
        }

        isPosting = true
        errorMessage = nil
        defer { isPosting = false }

        do {
            let response = try await api.createHowCardReply(cardID: cardID, body: body)
            replies.append(response.reply)
            replyCount = response.replyCount
            draft = ""
            return response.replyCount
        } catch {
            print("[HowCardReplies] post failed: \(error.localizedDescription)")
            errorMessage = Self.message(for: error, fallback: "返信を送信できませんでした")
            return nil
        }
    }

    private var normalizedDraft: String? {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(180))
    }

    private static func message(for error: Error, fallback: String) -> String {
        guard let apiError = error as? FirebaseAPIError else {
            return fallback
        }

        switch apiError {
        case .missingBaseURL:
            return "API_BASE_URL が設定されていません"
        case .notAuthenticated:
            return "ログイン状態を確認できませんでした"
        case .documentNotFound:
            return "Howカードが見つかりませんでした"
        case .badServerResponse(let statusCode, let message):
            if statusCode == 404 {
                return "返信APIがまだ反映されていません"
            }
            if let message, !message.isEmpty {
                return message
            }
            return fallback
        default:
            return fallback
        }
    }
}
