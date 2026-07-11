import Foundation
import Combine

@MainActor
final class ReactionDetectionViewModel: ObservableObject {
    @Published private(set) var currentScore: ReactionScore = .empty
    @Published private(set) var events: [ReactionEvent] = []
    @Published private(set) var classifierStatus: String = "Create ML未読込"
    @Published private(set) var latestActivityLabel: String?

    private let classifier: OthelloActivityClassifierService
    private let extractor: ReactionFeatureExtractor
    private var samples: [AirPodsMotionSample] = []
    private var isSessionActive = false
    private var lastPredictionTime: TimeInterval?
    private var lastWindowEvaluationTime: TimeInterval?
    private var currentTimeBasisUsesPlaybackTime: Bool?
    private var activeEvent: PendingReactionEvent?

    init(
        classifier: OthelloActivityClassifierService? = nil,
        extractor: ReactionFeatureExtractor? = nil
    ) {
        self.classifier = classifier ?? OthelloActivityClassifierService()
        self.extractor = extractor ?? ReactionFeatureExtractor()
        self.classifierStatus = self.classifier.isAvailable ? "Create ML有効" : "Create ML未検出"
    }

    func startSession() {
        samples.removeAll()
        events.removeAll()
        activeEvent = nil
        lastPredictionTime = nil
        lastWindowEvaluationTime = nil
        currentTimeBasisUsesPlaybackTime = nil
        latestActivityLabel = nil
        currentScore = .empty
        isSessionActive = true
        classifier.resetState()
        classifierStatus = classifier.isAvailable ? "Create ML有効" : "特徴量スコアのみ"
    }

    func ingest(_ sample: AirPodsMotionSample) {
        guard isSessionActive else { return }

        let sampleUsesPlaybackTime = sample.playbackTime != nil
        if let currentTimeBasisUsesPlaybackTime,
           currentTimeBasisUsesPlaybackTime != sampleUsesPlaybackTime {
            samples.removeAll()
            activeEvent = nil
            lastPredictionTime = nil
            lastWindowEvaluationTime = nil
        }
        currentTimeBasisUsesPlaybackTime = sampleUsesPlaybackTime

        samples.append(sample)
        if samples.count > 240 {
            samples.removeFirst(samples.count - 240)
        }

        let sampleTime = timelineTime(for: sample)
        if let lastWindowEvaluationTime, sampleTime - lastWindowEvaluationTime < 0.25 {
            return
        }
        lastWindowEvaluationTime = sampleTime

        guard let window = extractor.makeWindow(from: samples) else { return }
        if let lastPredictionTime, window.endTime - lastPredictionTime < 0.5 {
            return
        }
        lastPredictionTime = window.endTime

        let prediction = classifier.predict(window: window)
        latestActivityLabel = prediction?.displayLabel
        classifierStatus = classifier.isAvailable ? "Create ML推論中" : "特徴量スコアのみ"

        let nextScore = ReactionScoringService.score(for: window, prediction: prediction)
        currentScore = currentScore.blended(with: nextScore, factor: 0.45)
        updateReactionInterval(score: currentScore, window: window)
    }

    func recordManualReaction(_ tag: HowTag, at playbackTime: TimeInterval) {
        guard isSessionActive else { return }

        finishActiveEvent(endTime: playbackTime)
        currentScore = ReactionScoringService.manualScore(for: tag)
        latestActivityLabel = tag.label

        appendEvent(
            ReactionEvent(
                id: UUID(),
                startTime: max(0, playbackTime - 0.6),
                endTime: playbackTime + 1.4,
                intensity: 1,
                tags: [tag],
                score: currentScore,
                lyricLine: nil,
                lyricTranslation: nil,
                heartRateTrend: .stable
            )
        )
    }

    func stopSession(finalPlaybackTime: TimeInterval?) {
        finishActiveEvent(endTime: finalPlaybackTime)
        isSessionActive = false
        samples.removeAll()
        lastPredictionTime = nil
        lastWindowEvaluationTime = nil
        currentTimeBasisUsesPlaybackTime = nil
        currentScore = .empty
    }

    private func timelineTime(for sample: AirPodsMotionSample) -> TimeInterval {
        if let playbackTime = sample.playbackTime {
            return playbackTime
        }

        guard let firstSample = samples.first else {
            return 0
        }
        return sample.capturedAt.timeIntervalSince(firstSample.capturedAt)
    }

    private func updateReactionInterval(
        score: ReactionScore,
        window: ReactionFeatureWindow
    ) {
        let tags = score.activeTags()
        let intensity = score.intensity
        let isReactive = intensity >= 0.45 && !tags.isEmpty

        if isReactive {
            if var activeEvent {
                activeEvent.endTime = window.endTime
                if intensity > activeEvent.maxIntensity {
                    activeEvent.maxIntensity = intensity
                    activeEvent.peakScore = score
                }
                activeEvent.tags.formUnion(tags)
                self.activeEvent = activeEvent
            } else {
                activeEvent = PendingReactionEvent(
                    startTime: window.startTime,
                    endTime: window.endTime,
                    maxIntensity: intensity,
                    tags: Set(tags),
                    peakScore: score
                )
            }
        } else {
            finishActiveEvent(endTime: window.endTime)
        }
    }

    private func finishActiveEvent(endTime: TimeInterval?) {
        guard var pending = activeEvent else { return }
        if let endTime {
            pending.endTime = max(pending.endTime, endTime)
        }

        activeEvent = nil
        guard pending.endTime - pending.startTime >= 0.6 else { return }

        appendEvent(
            ReactionEvent(
                id: UUID(),
                startTime: pending.startTime,
                endTime: pending.endTime,
                intensity: min(max(pending.maxIntensity, 0), 1),
                tags: Array(pending.tags).sorted { $0.rawValue < $1.rawValue },
                score: pending.peakScore,
                lyricLine: nil,
                lyricTranslation: nil,
                heartRateTrend: .stable
            )
        )
    }

    private func appendEvent(_ event: ReactionEvent) {
        events.append(event)
        events.sort { $0.startTime < $1.startTime }
    }
}

private struct PendingReactionEvent {
    var startTime: TimeInterval
    var endTime: TimeInterval
    var maxIntensity: Double
    var tags: Set<HowTag>
    var peakScore: ReactionScore
}
