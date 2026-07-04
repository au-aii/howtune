import Foundation
import SwiftUI

struct HowCardReplyRow: View {
    let reply: HowCardReply

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color(.secondarySystemBackground))
                .frame(width: 32, height: 32)
                .overlay {
                    Text(avatarLetter)
                        .font(.caption.bold())
                        .foregroundStyle(Color(.label))
                }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(.label))
                    Text(relativeTime)
                        .font(.caption2)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                Text(reply.body)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private var displayName: String {
        if let trimmed = reply.userName?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            return trimmed
        }
        return "listener"
    }

    private var avatarLetter: String {
        displayName.first.map(String.init) ?? "L"
    }

    private var relativeTime: String {
        guard let createdAt = reply.createdAt,
              let date = Self.isoFormatter.date(from: createdAt) else {
            return "今"
        }

        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 { return "今" }
        if seconds < 3600 { return "\(seconds / 60)分前" }
        if seconds < 86400 { return "\(seconds / 3600)時間前" }
        return "\(seconds / 86400)日前"
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
