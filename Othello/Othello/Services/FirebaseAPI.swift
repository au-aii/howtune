import FirebaseAuth
import Foundation

final class FirebaseAPI {
    static let shared = FirebaseAPI()

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    func createHowCard(_ howCard: HowCardComment) async throws -> String {
        let response: HowCardResponseEnvelope = try await send(
            path: "how-cards",
            method: "POST",
            body: HowCardCommentPayload(howCard)
        )

        guard let id = response.howCard.documentID else {
            throw FirebaseAPIError.missingDocumentID
        }

        return id
    }

    func updateHowCard(_ howCard: HowCardComment) async throws {
        guard let id = howCard.documentID else {
            throw FirebaseAPIError.missingDocumentID
        }

        let _: HowCardResponseEnvelope = try await send(
            path: "how-cards/\(id)",
            method: "PATCH",
            body: HowCardCommentPayload(howCard)
        )
    }

    func fetchHowCard(id: String) async throws -> HowCardComment {
        let response: HowCardResponseEnvelope = try await send(
            path: "how-cards/\(id)",
            method: "GET"
        )
        return response.howCard
    }

    func fetchHowCards(songID: String? = nil, limit: Int = 50) async throws -> [HowCardComment] {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let songID = normalizedLookupSongID(songID) {
            queryItems.insert(URLQueryItem(name: "song_id", value: songID), at: 0)
        }

        let response: HowCardsResponseEnvelope = try await send(
            path: "how-cards",
            method: "GET",
            queryItems: queryItems
        )
        return response.howCards
    }

    func incrementGoods(cardID: String) async throws {
        let _: LikeResponseEnvelope = try await send(
            path: "how-cards/\(cardID)/like",
            method: "POST"
        )
    }

    func fetchHowCardReplies(cardID: String, limit: Int = 50) async throws -> [HowCardReply] {
        let response: HowCardRepliesResponseEnvelope = try await send(
            path: "how-cards/\(cardID)/replies",
            method: "GET",
            queryItems: [URLQueryItem(name: "limit", value: String(limit))]
        )
        return response.replies
    }

    func createHowCardReply(cardID: String, body: String) async throws -> HowCardReplyResponseEnvelope {
        try await send(
            path: "how-cards/\(cardID)/replies",
            method: "POST",
            body: HowCardReplyPayload(body: body)
        )
    }

    @discardableResult
    func upsertUser(_ user: UserProfile) async throws -> UserProfile {
        let response: UserResponseEnvelope = try await send(
            path: "users/me",
            method: "PUT",
            body: UserProfilePayload(email: user.email, displayName: user.displayName)
        )
        return response.user
    }

    func fetchUser(uid: String) async throws -> UserProfile {
        guard Auth.auth().currentUser?.uid == uid else {
            throw FirebaseAPIError.notAuthenticated
        }

        let response: UserResponseEnvelope = try await send(
            path: "users/me",
            method: "GET"
        )
        return response.user
    }

    func createUserDocument(from user: User) async throws {
        guard let email = user.email, !email.isEmpty else {
            throw FirebaseAPIError.missingEmail
        }

        let profile = UserProfile(
            id: user.uid,
            userID: user.uid,
            email: email,
            displayName: user.displayName
        )
        try await upsertUser(profile)
    }

    private static let productionAPIBase = "https://asia-northeast1-howtune-74252.cloudfunctions.net/api"

    private var baseURL: URL? {
        let configured = EnvironmentValueProvider.value(forKey: "API_BASE_URL")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let urlString = configured.isEmpty ? Self.productionAPIBase : configured
        return URL(string: urlString)
    }

    private func send<Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        let request = try await makeRequest(path: path, method: method, queryItems: queryItems)
        return try await perform(request)
    }

    private func send<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Body
    ) async throws -> Response {
        var request = try await makeRequest(path: path, method: method, queryItems: queryItems)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await perform(request)
    }

    private func makeRequest(
        path: String,
        method: String,
        queryItems: [URLQueryItem]
    ) async throws -> URLRequest {
        let token = try await firebaseIDToken()
        let url = try makeURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func makeURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var url = baseURL else {
            throw FirebaseAPIError.missingBaseURL
        }

        path.split(separator: "/").forEach { component in
            url.appendPathComponent(String(component))
        }

        guard !queryItems.isEmpty else {
            return url
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.queryItems = queryItems

        guard let urlWithQuery = components.url else {
            throw URLError(.badURL)
        }
        return urlWithQuery
    }

    private func normalizedLookupSongID(_ rawValue: String?) -> String? {
        guard let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              trimmed.count <= 120 else {
            return nil
        }
        return trimmed
    }

    private func firebaseIDToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseAPIError.notAuthenticated
        }

        return try await withCheckedThrowingContinuation { continuation in
            user.getIDToken { token, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let token {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: FirebaseAPIError.notAuthenticated)
                }
            }
        }
    }

    private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw FirebaseAPIError.notAuthenticated
        }

        if httpResponse.statusCode == 404 {
            if Self.errorMessage(from: data) == nil {
                throw FirebaseAPIError.badServerResponse(statusCode: httpResponse.statusCode, message: "API endpoint not found")
            }
            throw FirebaseAPIError.documentNotFound
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw FirebaseAPIError.badServerResponse(
                statusCode: httpResponse.statusCode,
                message: Self.errorMessage(from: data)
            )
        }

        return try decoder.decode(Response.self, from: data)
    }

    private static func errorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if let envelope = try? JSONDecoder().decode(ErrorResponseEnvelope.self, from: data) {
            return envelope.error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : envelope.error
        }
        return nil
    }
}

private struct ErrorResponseEnvelope: Decodable {
    let error: String
}
