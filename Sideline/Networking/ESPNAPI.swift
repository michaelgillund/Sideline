import Foundation

enum ESPNAPIError: Error {
    case invalidURL
    case responseError(statusCode: Int)
    case decodingError(Error)
    case unknownError(Error)

    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL for ESPN API request"
        case .responseError(let statusCode):
            return "ESPN API returned HTTP error \(statusCode)"
        case .decodingError(let underlying):
            return "Failed to decode ESPN response: \(underlying.localizedDescription)"
        case .unknownError(let underlying):
            return "Unexpected error: \(underlying.localizedDescription)"
        }
    }
}

enum ESPNEndpoint {
    case scoreboard
    case summary(eventID: String)
    case standingsConferences
    case standingsDivisions
    case golfLeaderboard(eventID: String)

    var path: String {
        switch self {
        case .scoreboard:
            return "scoreboard"
        case .summary:
            return "summary"
        case .standingsConferences, .standingsDivisions:
            return "standings"
        case .golfLeaderboard:
            return "leaderboard"
        }
    }
}

final class ESPNClient {
    static let shared = ESPNClient()
    private let baseURL = "https://site.api.espn.com/apis/site/v2/sports"
    private init() {}

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    func scoreboard(
        sport: ESPN_Sport,
        league: ESPN_League,
        dateRange: String
    ) async throws -> Scoreboard {
        let urlString = "\(baseURL)/\(sport.rawValue)/\(league.rawValue)/\(ESPNEndpoint.scoreboard.path)"
        guard var comps = URLComponents(string: urlString) else { throw ESPNAPIError.invalidURL }

        var items: [URLQueryItem] = [
            .init(name: "dates", value: dateRange)
        ]

        if league == .ncaam {
            items.append(.init(name: "groups", value: "50"))
        }
        if league == .ncaaf {
            items.append(.init(name: "groups", value: "80"))
        }

        comps.queryItems = items
        guard let url = comps.url else { throw ESPNAPIError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ESPNAPIError.responseError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        do { return try decoder.decode(Scoreboard.self, from: data) }
        catch { throw ESPNAPIError.decodingError(error) }
    }

    func golfLeaderboard(eventID: String) async throws -> Golf {
        let urlString = "\(baseURL)/golf/\(ESPNEndpoint.golfLeaderboard(eventID: eventID).path)"
        guard var comps = URLComponents(string: urlString) else { throw ESPNAPIError.invalidURL }

        comps.queryItems = [.init(name: "event", value: eventID)]
        guard let url = comps.url else { throw ESPNAPIError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ESPNAPIError.responseError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        do { return try decoder.decode(Golf.self, from: data) }
        catch { throw ESPNAPIError.decodingError(error) }
    }
}
