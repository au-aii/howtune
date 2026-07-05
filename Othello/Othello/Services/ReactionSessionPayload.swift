import Foundation

/// `POST /reaction-sessions` の送信ペイロード（moat P-a）。
/// 反応セッション（検出済み区間＝multi-label タグ）と弱教師ラベル(self_report_tags)を送る。
struct ReactionSessionEventPayload: Encodable {
    let start: Double
    let end: Double
    let tags: [String]
    let intensity: Double?
    let hr_trend: String?
}

struct ReactionSessionPayload: Encodable {
    let song_id: String
    let song_title: String?
    let artist_id: String?
    let artist_name: String?
    let duration_sec: Double?
    let consent_version: String
    let events: [ReactionSessionEventPayload]
    let self_report_tags: [String]
}

struct ReactionSessionResponse: Decodable {
    struct Session: Decodable { let id: String }
    let session: Session
}
