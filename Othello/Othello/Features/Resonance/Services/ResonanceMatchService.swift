import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

/// 同じ曲の how-cards を Firestore でリアルタイム購読し、同地点/別地点を判定する（FR-RES-04 / ADR-0006）。
/// 書き込みは Functions 経由のまま。ここは read（購読）のみ。
@MainActor
final class ResonanceMatchService: ObservableObject {
    @Published private(set) var reactors: [ResonanceReactor] = []

    private var listener: ListenerRegistration?
    private let collectionName = "how-cards"

    /// 同地点判定のマージン（秒）。±2.5s で区間が重なれば同地点。
    nonisolated static let sameSpotMargin: TimeInterval = 2.5

    deinit { listener?.remove() }

    /// 指定曲のマッチングをリアルタイム購読開始。
    /// - Parameters:
    ///   - songId: 対象曲 ID
    ///   - myInterval: 自分の反応区間（同地点判定の基準）
    func start(songId: String, myInterval: (start: TimeInterval, end: TimeInterval)) {
        stop()
        let myUserId = Auth.auth().currentUser?.uid

        listener = Firestore.firestore()
            .collection(collectionName)
            .whereField("song_id", isEqualTo: songId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("[ResonanceMatchService] snapshot error: \(error.localizedDescription)")
                    self.reactors = []
                    return
                }
                guard let documents = snapshot?.documents else {
                    self.reactors = []
                    return
                }
                let mapped: [ResonanceReactor] = documents.compactMap { doc in
                    Self.reactor(from: doc.data(), id: doc.documentID, myInterval: myInterval)
                }
                .filter { $0.userId != myUserId }   // 自分は除外
                .sorted { lhs, rhs in
                    if lhs.isSameSpot != rhs.isSameSpot { return lhs.isSameSpot }
                    return lhs.spotStart < rhs.spotStart
                }
                self.reactors = mapped
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    var sameSpotReactors: [ResonanceReactor] { reactors.filter(\.isSameSpot) }
    var otherSpotReactors: [ResonanceReactor] { reactors.filter { !$0.isSameSpot } }

    // MARK: - Pure logic

    /// 2区間が margin 込みで重なれば同地点。
    static func isSameSpot(
        _ a: (start: TimeInterval, end: TimeInterval),
        _ b: (start: TimeInterval, end: TimeInterval),
        margin: TimeInterval = sameSpotMargin
    ) -> Bool {
        a.start - margin <= b.end && b.start - margin <= a.end
    }

    private static func reactor(
        from data: [String: Any],
        id: String,
        myInterval: (start: TimeInterval, end: TimeInterval)
    ) -> ResonanceReactor? {
        guard let userId = (data["user_id"] as? String) ?? (data["userId"] as? String) else { return nil }
        guard let start = doubleValue(data["song_start"]),
              let end = doubleValue(data["song_end"]),
              end >= start else { return nil }
        let comment = (data["comment"] as? String) ?? ""
        let name = (data["user_name"] as? String) ?? (data["display_name"] as? String) ?? "リスナー"
        let same = isSameSpot((start, end), myInterval)
        return ResonanceReactor(
            id: id,
            userId: userId,
            displayName: name,
            comment: comment,
            spotStart: start,
            spotEnd: end,
            isSameSpot: same
        )
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }
}
