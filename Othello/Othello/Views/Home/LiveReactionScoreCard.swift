import SwiftUI

struct LiveReactionScoreCard: View {
    let score: ReactionScore
    let eventCount: Int
    let classifierStatus: String
    let activityLabel: String?
    let airPodsStatus: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("リアルタイム反応")
                        .font(.headline)
                        .foregroundStyle(Color(.label))
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }

                Spacer()

                Text("\(eventCount)区間")
                    .font(.caption.bold())
                    .foregroundStyle(HowTuneDesign.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.secondarySystemBackground), in: Capsule())
            }

            VStack(spacing: 10) {
                ForEach(score.axes) { axis in
                    ReactionAxisBar(axis: axis, isCompact: true)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var statusText: String {
        if let activityLabel {
            return "\(classifierStatus) / \(activityLabel) / \(airPodsStatus)"
        }
        return "\(classifierStatus) / \(airPodsStatus)"
    }
}
