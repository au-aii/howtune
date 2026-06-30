import Combine
import Foundation
import MusicKit
import SwiftUI

@MainActor
final class HomeDashboardViewModel: ObservableObject {
    @Published private(set) var comments: [HomeDashboardComment] = []
    @Published private(set) var featuredArtists: [Artist] = Artist.catalog
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let api: FirebaseAPI
    private var hasLoaded = false

    init(api: FirebaseAPI? = nil) {
        self.api = api ?? FirebaseAPI.shared
    }

    func load(force: Bool = false) async {
        guard force || !hasLoaded else { return }
        hasLoaded = true
        isLoading = comments.isEmpty
        errorMessage = nil

        do {
            let howCards = try await api.fetchHowCards(limit: 12)
            let canResolveMusic = await ensureMusicKitAuthorization()
            let dashboardComments = await enrich(howCards, canResolveMusic: canResolveMusic)
            comments = dashboardComments
            featuredArtists = makeFeaturedArtists(from: dashboardComments)
        } catch {
            print("❌ fetchHowCards error:", error)
            errorMessage = message(for: error)
            if featuredArtists.isEmpty {
                featuredArtists = Artist.catalog
            }
        }

        isLoading = false
    }

    private func enrich(_ howCards: [HowCardComment], canResolveMusic: Bool) async -> [HomeDashboardComment] {
        var metadataCache: [String: MusicMetadata] = [:]
        var unresolvedMetadataKeys: Set<String> = []
        var items: [HomeDashboardComment] = []

        for card in howCards {
            let cacheKey = "\(card.songID)|\(card.artistID)"
            let metadata: MusicMetadata?
            if let cached = metadataCache[cacheKey] {
                metadata = cached
            } else if canResolveMusic, !unresolvedMetadataKeys.contains(cacheKey) {
                let resolved = await fetchMusicMetadata(for: card)
                if let resolved {
                    metadataCache[cacheKey] = resolved
                } else {
                    unresolvedMetadataKeys.insert(cacheKey)
                }
                metadata = resolved
            } else {
                metadata = nil
            }

            let artistName = nonEmpty(metadata?.artistName)
                ?? readableIdentifier(
                    card.artistID,
                    fallback: "不明なアーティスト",
                    numericIDPrefix: "アーティストID"
                )
            let songTitle = nonEmpty(metadata?.title) ?? fallbackSongTitle(for: card)
            let colors = gradientColors(for: artistName + songTitle)

            items.append(
                HomeDashboardComment(
                    howCard: card,
                    songTitle: songTitle,
                    artistName: artistName,
                    artworkURL: metadata?.artworkURL,
                    durationSeconds: metadata?.durationSeconds ?? max(Int(card.songEnd.rounded(.up)), 180),
                    gradientColors: colors
                )
            )
        }

        return items
    }

    private func ensureMusicKitAuthorization() async -> Bool {
        switch MusicAuthorization.currentStatus {
        case .authorized:
            return true
        case .notDetermined:
            return await MusicAuthorization.request() == .authorized
        default:
            return false
        }
    }

    private func fetchMusicMetadata(for card: HowCardComment) async -> MusicMetadata? {
        let songID = card.songID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !songID.isEmpty else {
            return nil
        }

        if looksLikeAppleMusicCatalogID(songID),
           let metadata = await fetchMusicMetadataByCatalogID(songID) {
            return metadata
        }

        return await searchMusicMetadata(
            term: musicSearchTerm(songID: songID, artistID: card.artistID),
            preferredArtist: card.artistID,
            preferredTitle: fallbackSongTitle(for: card)
        )
    }

    private func fetchMusicMetadataByCatalogID(_ songID: String) async -> MusicMetadata? {
        do {
            var request = MusicCatalogResourceRequest<MusicKit.Song>(
                matching: \.id,
                equalTo: MusicItemID(rawValue: songID)
            )
            request.limit = 1
            let response = try await request.response()
            guard let song = response.items.first else { return nil }
            return MusicMetadata(song: song)
        } catch {
            return nil
        }
    }

    private func searchMusicMetadata(
        term: String,
        preferredArtist: String,
        preferredTitle: String
    ) async -> MusicMetadata? {
        let searchTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchTerm.isEmpty else { return nil }

        do {
            var request = MusicCatalogSearchRequest(term: searchTerm, types: [MusicKit.Song.self])
            request.limit = 5
            let response = try await request.response()
            let songs = Array(response.songs)
            guard !songs.isEmpty else { return nil }

            let artistNeedle = normalizedIdentifier(preferredArtist)
            let titleNeedle = normalizedIdentifier(preferredTitle)
            let bestMatch = songs.first { song in
                let artist = normalizedIdentifier(song.artistName)
                let title = normalizedIdentifier(song.title)
                let artistMatches = artistNeedle.isEmpty || artist.contains(artistNeedle) || artistNeedle.contains(artist)
                let titleMatches = titleNeedle.isEmpty || title.contains(titleNeedle) || titleNeedle.contains(title)
                return artistMatches && titleMatches
            }

            return MusicMetadata(song: bestMatch ?? songs[0])
        } catch {
            return nil
        }
    }

    private func makeFeaturedArtists(from comments: [HomeDashboardComment]) -> [Artist] {
        var groups: [String: ArtistAccumulator] = [:]
        var artistOrder: [String] = []
        var artists: [Artist] = []

        for comment in comments {
            let key = artistGroupingKey(for: comment.artist)
            if groups[key] == nil {
                artistOrder.append(key)
                groups[key] = ArtistAccumulator(artist: comment.artist)
            }

            groups[key]?.append(song: comment.song)
            groups[key]?.commentCount += 1
        }

        for key in artistOrder {
            guard let group = groups[key] else { continue }
            let artist = group.artist
            artists.append(
                Artist(
                    id: artist.id,
                    name: artist.name,
                    listeningCount: "\(group.commentCount)件のコメント",
                    tag: artist.tag,
                    gradientColors: artist.gradientColors,
                    artworkURL: artist.artworkURL,
                    songs: group.songs
                )
            )
        }

        let seen = Set(groups.keys)
        let fallback = Artist.catalog.filter { artist in
            !seen.contains(artistGroupingKey(for: artist))
        }

        return Array((artists + fallback).prefix(8))
    }

    private func artistGroupingKey(for artist: Artist) -> String {
        let idKey = artist.id.uuidString
            .lowercased()
        if !idKey.isEmpty {
            return "id:\(idKey)"
        }

        return "name:" + artist.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func gradientColors(for key: String) -> [Color] {
        let palettes: [[Color]] = [
            [Color(red: 0.98, green: 0.25, blue: 0.30), Color(red: 0.95, green: 0.62, blue: 0.18)],
            [Color(red: 0.10, green: 0.58, blue: 0.72), Color(red: 0.24, green: 0.82, blue: 0.62)],
            [Color(red: 0.48, green: 0.34, blue: 0.92), Color(red: 0.92, green: 0.28, blue: 0.58)],
            [Color(red: 0.88, green: 0.46, blue: 0.16), Color(red: 0.38, green: 0.18, blue: 0.08)],
            [Color(red: 0.16, green: 0.44, blue: 0.86), Color(red: 0.06, green: 0.72, blue: 0.78)]
        ]
        let seed = abs(key.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) })
        return palettes[seed % palettes.count]
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func readableIdentifier(
        _ value: String,
        fallback: String,
        numericIDPrefix: String = "ID"
    ) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        if trimmed.count > 18, trimmed.allSatisfy({ $0.isNumber || $0 == "-" }) {
            return "\(numericIDPrefix) \(trimmed.prefix(8))"
        }
        return normalizedIdentifier(trimmed)
    }

    private func fallbackSongTitle(for card: HowCardComment) -> String {
        let songText = normalizedIdentifier(card.songID)
        guard !songText.isEmpty else { return "不明な曲" }

        let artistText = normalizedIdentifier(card.artistID)
        let lowerSong = songText.lowercased()
        let lowerArtist = artistText.lowercased()
        if !lowerArtist.isEmpty, lowerSong.hasPrefix(lowerArtist + " ") {
            let startIndex = songText.index(songText.startIndex, offsetBy: artistText.count)
            let title = songText[startIndex...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                return title
            }
        }

        return readableIdentifier(card.songID, fallback: "不明な曲", numericIDPrefix: "曲ID")
    }

    private func musicSearchTerm(songID: String, artistID: String) -> String {
        let songText = normalizedIdentifier(songID)
        let artistText = normalizedIdentifier(artistID)
        guard !artistText.isEmpty else { return songText }

        if songText.lowercased().hasPrefix(artistText.lowercased() + " ") {
            return songText
        }

        return [artistText, songText]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func normalizedIdentifier(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func looksLikeAppleMusicCatalogID(_ value: String) -> Bool {
        value.count >= 6 && value.allSatisfy(\.isNumber)
    }

    private func message(for error: Error) -> String {
        if let apiError = error as? FirebaseAPIError {
            switch apiError {
            case .missingBaseURL:
                return "API_BASE_URL が設定されていません。"
            case .notAuthenticated:
                return "ログイン状態を確認できませんでした。"
            case .documentNotFound:
                return "コメントが見つかりませんでした。"
            default:
                return "おすすめコメントを取得できませんでした。"
            }
        }
        return "おすすめコメントを取得できませんでした。"
    }
}

private struct MusicMetadata {
    let title: String
    let artistName: String
    let artworkURL: URL?
    let durationSeconds: Int

    init(song: MusicKit.Song) {
        self.title = song.title
        self.artistName = song.artistName
        self.artworkURL = song.artwork?.url(width: 800, height: 800)
        self.durationSeconds = Int((song.duration ?? 180).rounded())
    }
}

private struct ArtistAccumulator {
    let artist: Artist
    private(set) var songs: [Song]
    private var songKeys: Set<String>
    var commentCount: Int

    init(artist: Artist) {
        self.artist = artist
        self.songs = []
        self.songKeys = []
        self.commentCount = 0
    }

    mutating func append(song: Song) {
        let key = song.howCardLookupSongID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !songKeys.contains(key) else { return }
        songKeys.insert(key)
        songs.append(song)
    }
}
