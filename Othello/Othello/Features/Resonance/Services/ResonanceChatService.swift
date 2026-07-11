import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

/// 2者間のリアルタイム DM（FR-RES-06 / ADR-0006）。
/// conversations/{cid}/messages を購読・送信。書き込みは体感速度のため Firestore 直＋楽観的更新。
@MainActor
final class ResonanceChatService: ObservableObject {
    @Published private(set) var messages: [ResonanceMessage] = []

    private var listener: ListenerRegistration?
    private let otherUserId: String

    /// uid ペアを並べ替えて会話 ID を一意化（uidA__uidB）。
    static func conversationId(_ a: String, _ b: String) -> String {
        [a, b].sorted().joined(separator: "__")
    }

    init(otherUserId: String) {
        self.otherUserId = otherUserId
    }

    deinit { listener?.remove() }

    var myUserId: String? { Auth.auth().currentUser?.uid }

    private var conversationId: String? {
        guard let me = myUserId else { return nil }
        return Self.conversationId(me, otherUserId)
    }

    private var messagesRef: CollectionReference? {
        guard let cid = conversationId else { return nil }
        return Firestore.firestore()
            .collection("conversations")
            .document(cid)
            .collection("messages")
    }

    func start() {
        listener?.remove()
        guard let ref = messagesRef else { return }
        listener = ref
            .order(by: "created_at")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("[ResonanceChatService] snapshot error: \(error.localizedDescription)")
                    return
                }
                guard let docs = snapshot?.documents else { return }
                let server: [ResonanceMessage] = docs.compactMap { Self.message(from: $0.data(), id: $0.documentID) }
                let serverIds = Set(server.map(\.id))
                let pending = self.messages.filter { $0.isPending && !serverIds.contains($0.id) }
                self.messages = (server + pending).sorted { $0.createdAt < $1.createdAt }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    /// 楽観的送信: 即ローカル反映 → Firestore へ非同期書き込み。
    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let me = myUserId, let ref = messagesRef else { return }

        let localId = UUID().uuidString
        let now = Date()
        messages.append(
            ResonanceMessage(id: localId, senderId: me, text: trimmed, createdAt: now, isPending: true)
        )

        ref.document(localId).setData([
            "sender_id": me,
            "text": trimmed,
            "created_at": FieldValue.serverTimestamp()
        ]) { [weak self] error in
            if let error {
                print("[ResonanceChatService] send error: \(error.localizedDescription)")
                return
            }
            guard let self else { return }
            Task { @MainActor in
                if let idx = self.messages.firstIndex(where: { $0.id == localId }) {
                    self.messages[idx].isPending = false
                }
            }
        }
    }

    private static func message(from data: [String: Any], id: String) -> ResonanceMessage? {
        guard let sender = data["sender_id"] as? String,
              let text = data["text"] as? String else { return nil }
        let date = (data["created_at"] as? Timestamp)?.dateValue() ?? Date()
        return ResonanceMessage(id: id, senderId: sender, text: text, createdAt: date)
    }
}
