//
//  ContentView.swift
//  Sideline
//
//  Created by Michael Gillund on 2/6/26.
//
import Foundation
import SwiftUI
import Combine
import NukeUI

struct GroupedScoreboard {
    let date: Date
    let league: ESPN_League
    let events: [ScoreboardContent]
}

enum ScoreboardContent {
    case event(Event)
    case golf(Golf.Event)
}

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

        comps.queryItems = [ .init(name: "event", value: eventID) ]
        guard let url = comps.url else { throw ESPNAPIError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ESPNAPIError.responseError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        do { return try decoder.decode(Golf.self, from: data) }
        catch { throw ESPNAPIError.decodingError(error) }
    }
}

@MainActor
final class ScoreboardViewModel: ObservableObject {

    @Published var scoreboards: [GroupedScoreboard] = []
    @Published var isLoading = false
    @Published var error: Error?

    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @Published private(set) var loadedWeekStart: Date?
    @Published private(set) var loadedWeekEnd: Date?

    private let client = ESPNClient.shared

    private var pollingCancellable: AnyCancellable?
    private var refreshTask: Task<Void, Never>?

    private var lastSignature: String = ""

    private let leagues: [ESPN_Sport: [ESPN_League]] = [
        .baseball: [.mlb],
        .basketball: [.nba, .ncaam, .wnba],
        .football: [.nfl, .ncaaf],
        .hockey: [.nhl],
        .golf: [.pga, .liv]
    ]

    func startPolling(every seconds: TimeInterval = 30) {
        stopPolling()

        pollingCancellable = Timer
            .publish(every: seconds, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshTask?.cancel()
                self.refreshTask = Task { [weak self] in
                    await self?.fetchCurrentWeek()
                }
            }
    }

    func stopPolling() {
        pollingCancellable?.cancel()
        pollingCancellable = nil
        refreshTask?.cancel()
        refreshTask = nil
    }

    func fetchToday() async {
        let today = Calendar.current.startOfDay(for: Date())
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"
        await fetchScoreboards(dateRange: fmt.string(from: today))
    }

    func fetchCurrentWeek() async {
        var cal = Calendar.current
        cal.firstWeekday = 1

        let base = cal.startOfDay(for: selectedDate)
        let weekday = cal.component(.weekday, from: base)
        let daysFromSunday = (weekday - cal.firstWeekday + 7) % 7

        guard
            let start = cal.date(byAdding: .day, value: -daysFromSunday, to: base),
            let end = cal.date(byAdding: .day, value: 6, to: start)
        else { return }

        loadedWeekStart = start
        loadedWeekEnd = end

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"

        await fetchScoreboards(dateRange: "\(fmt.string(from: start))-\(fmt.string(from: end))")
    }

    func fetchScoreboards(dateRange: String) async {
        isLoading = true
        error = nil

        do {
            let requests: [(sport: ESPN_Sport, league: ESPN_League)] =
                leagues.flatMap { sport, leagueList in
                    leagueList.map { (sport, $0) }
                }

            let fetched: [(league: ESPN_League, groups: [GroupedScoreboard])] =
                try await withThrowingTaskGroup(of: (ESPN_League, [GroupedScoreboard]).self) { group in

                    for req in requests {
                        if shouldSkip(league: req.league, dateRange: dateRange) { continue }

                        group.addTask { [client] in
                            let scoreboard = try await client.scoreboard(
                                sport: req.sport,
                                league: req.league,
                                dateRange: dateRange
                            )

                            if req.sport == .golf {
                                let groups = try await Self.buildGolfGroupsParallel(
                                    client: client,
                                    league: req.league,
                                    scoreboard: scoreboard
                                )
                                return (req.league, groups)
                            } else {
                                let groups = await Self.buildEventGroupsPerDay(
                                    league: req.league,
                                    scoreboard: scoreboard
                                )
                                return (req.league, groups)
                            }
                        }
                    }

                    var out: [(ESPN_League, [GroupedScoreboard])] = []
                    for try await item in group {
                        out.append(item)
                    }
                    return out
                }

            var results = fetched.flatMap { $0.groups }
            results.sort {
                if $0.date != $1.date { return $0.date < $1.date }
                return $0.league.displayName < $1.league.displayName
            }

            let sig = signature(for: results)
            if sig != lastSignature {
                lastSignature = sig
                scoreboards = results
            }

        } catch {
            self.error = error
        }

        isLoading = false
    }

    private static func buildEventGroupsPerDay(
        league: ESPN_League,
        scoreboard: Scoreboard
    ) -> [GroupedScoreboard] {
        let cal = Calendar.current
        var map: [Date: [ScoreboardContent]] = [:]

        for event in scoreboard.events {
            guard let date = parseESPNStatic(event.date) else { continue }
            let day = cal.startOfDay(for: date)
            map[day, default: []].append(.event(event))
        }

        return map.keys.sorted().map { day in
            GroupedScoreboard(date: day, league: league, events: map[day] ?? [])
        }
    }

    private static func buildGolfGroupsParallel(
        client: ESPNClient,
        league: ESPN_League,
        scoreboard: Scoreboard
    ) async throws -> [GroupedScoreboard] {
        let cal = Calendar.current

        let leaderboards: [(day: Date, contents: [ScoreboardContent])] =
            try await withThrowingTaskGroup(of: (Date, [ScoreboardContent]).self) { group in

                for event in scoreboard.events {
                    guard
                        let id = event.id,
                        let date = parseESPNStatic(event.date)
                    else { continue }

                    let day = cal.startOfDay(for: date)

                    group.addTask {
                        let golf = try await client.golfLeaderboard(eventID: id)
                        let contents = golf.events.map { ScoreboardContent.golf($0) }
                        return (day, contents)
                    }
                }

                var out: [(Date, [ScoreboardContent])] = []
                for try await item in group {
                    out.append(item)
                }
                return out
            }

        var map: [Date: [ScoreboardContent]] = [:]
        for item in leaderboards {
            map[item.day, default: []].append(contentsOf: item.contents)
        }

        return map.keys.sorted().map { day in
            GroupedScoreboard(date: day, league: league, events: map[day] ?? [])
        }
    }

    private let espnFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .init(identifier: "en_US_POSIX")
        f.timeZone = .init(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm'Z'"
        return f
    }()

    private func parseESPN(_ string: String?) -> Date? {
        guard let s = string else { return nil }
        return espnFormatter.date(from: s)
    }

    private static func parseESPNStatic(_ string: String?) -> Date? {
        guard let s = string else { return nil }
        let f = DateFormatter()
        f.locale = .init(identifier: "en_US_POSIX")
        f.timeZone = .init(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm'Z'"
        return f.date(from: s)
    }

    private func shouldSkip(league: ESPN_League, dateRange: String) -> Bool {
        if league == .pga, dateRange.count == 8 {
            if let date = parseShort(dateRange),
               Calendar.current.component(.weekday, from: date) == 2 {
                return true
            }
        }
        return false
    }

    private func parseShort(_ string: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f.date(from: string)
    }

    private func signature(for groups: [GroupedScoreboard]) -> String {
        var parts: [String] = []
        parts.reserveCapacity(groups.count * 4)

        for g in groups {
            parts.append("D:\(Int(g.date.timeIntervalSince1970))|L:\(g.league.displayName)|C:\(g.events.count)")
            for e in g.events {
                switch e {
                case .event(let ev):
                    let id = ev.id ?? ""
                    let state = ev.status?.type?.state ?? ""
                    let detail = ev.status?.type?.shortDetail ?? ""
                    let hs = ev.homeScore
                    let asz = ev.awayScore
                    parts.append("E:\(id)|\(state)|\(detail)|\(hs)-\(asz)")
                case .golf(let ge):
                    let id = ge.id ?? ""
                    let state = ge.status?.type?.state ?? ""
                    let name = ge.shortName ?? ""
                    let leaders = ge.players.prefix(5).map {
                        "\($0.athlete?.displayName ?? ""):\($0.score?.displayValue ?? "")"
                    }.joined(separator: ",")
                    parts.append("G:\(id)|\(state)|\(name)|\(leaders)")
                }
            }
        }

        return String(parts.joined(separator: "||").hashValue)
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ScoreboardViewModel()
    @State private var currentPage: Int?

    private var weekDates: [Date] {
        var cal = Calendar.current
        cal.firstWeekday = 1

        let base = cal.startOfDay(for: viewModel.selectedDate)
        let weekday = cal.component(.weekday, from: base)
        let daysFromSunday = (weekday - cal.firstWeekday + 7) % 7

        guard let sunday = cal.date(byAdding: .day, value: -daysFromSunday, to: base) else {
            return []
        }

        return (0...6).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: sunday)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                                DateButton(
                                    date: date,
                                    isSelected: currentPage == index
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        currentPage = index
                                        viewModel.selectedDate = date
                                    }
                                }
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .background(Color(.systemBackground))

                    .onAppear {
                        guard currentPage == nil else { return }

                        let target = Calendar.current.startOfDay(for: viewModel.selectedDate)
                        let initial = weekDates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: target) }) ?? 0

                        DispatchQueue.main.async {
                            currentPage = initial
                            proxy.scrollTo(initial, anchor: .center)
                        }
                    }

                    .onChange(of: currentPage) { _, newValue in
                        if let newValue {
                            withAnimation {
                                proxy.scrollTo(newValue, anchor: .center)
                            }
                        }
                    }
                }

                Divider()

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                            DayContentView(
                                date: date,
                                scoreboards: viewModel.scoreboards,
                                isLoading: viewModel.isLoading
                            )
                            .containerRelativeFrame(.horizontal)
                            .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollIndicators(.hidden)
                .scrollPosition(id: $currentPage)

                .onChange(of: currentPage) { _, newValue in
                    if let newValue, weekDates.indices.contains(newValue) {
                        viewModel.selectedDate = weekDates[newValue]
                    }
                }
            }
            .task {
                await viewModel.fetchCurrentWeek()
                viewModel.startPolling()
            }
            .onDisappear {
                viewModel.stopPolling()
            }
        }
    }
}

struct DateButton: View {
    let date: Date
    let isSelected: Bool
    let action: () -> Void

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(dayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .secondary)

                Text(dayNumber)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(isSelected ? .white : .primary)

                if isToday {
                    Circle()
                        .fill(isSelected ? .white : .blue)
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 50)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue : Color.clear)
                    .shadow(
                        color: isSelected ? .blue.opacity(0.3) : .clear,
                        radius: 8,
                        x: 0,
                        y: 4
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct DayContentView: View {
    let date: Date
    let scoreboards: [GroupedScoreboard]
    let isLoading: Bool

    private let leagueOrder: [ESPN_League] = [
        .nfl, .ncaaf,
        .nba, .ncaam, .wnba,
        .mlb,
        .nhl,
        .pga, .liv,
        .mls, .premierLeague, .laLiga, .bundesliga, .serieA, .ligue1, .uefaChampions,
        .f1
    ]

    private var sections: [(league: ESPN_League, games: [GameViewModel])] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!

        let todaysBoards = scoreboards.filter { $0.date >= dayStart && $0.date < dayEnd }

        var map: [ESPN_League: [GameViewModel]] = [:]

        for board in todaysBoards {
            for content in board.events {
                switch content {
                case .event(let event):
                    map[board.league, default: []].append(GameViewModel(event: event, league: board.league))
                case .golf:
                    continue
                }
            }
        }

        for (league, games) in map {
            map[league] = games.sorted { g1, g2 in
                if g1.isLive && !g2.isLive { return true }
                if !g1.isLive && g2.isLive { return false }
                return (g1.event.date ?? "") < (g2.event.date ?? "")
            }
        }

        let sortedLeagues = map.keys.sorted { a, b in
            let ia = leagueOrder.firstIndex(of: a) ?? Int.max
            let ib = leagueOrder.firstIndex(of: b) ?? Int.max
            if ia != ib { return ia < ib }
            return a.displayName < b.displayName
        }

        return sortedLeagues.map { ($0, map[$0] ?? []) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 18) {
                    ForEach(sections, id: \.league) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            LeagueHeader(league: section.league)

                            VStack(spacing: 12) {
                                ForEach(section.games) { gameVM in
                                    GameCard(gameViewModel: gameVM)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .padding(.top)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct LeagueHeader: View {
    let league: ESPN_League

    var body: some View {
        HStack(spacing: 4) {
            Image(league.logo)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)

            Text(league.displayName)
                .font(.headline)
                .fontWeight(.bold)

            Spacer()
        }
    }
}

struct GameViewModel: Identifiable {
    
    let id = UUID()
    let event: Event
    let league: ESPN_League

    var homeTeam: String { event.homeName }
    var awayTeam: String { event.awayName }
    var time: String { event.gametime }
    var leagueDisplay: String { league.displayName }

    var homeScore: Int? { Int(event.homeScore) }
    var awayScore: Int? { Int(event.awayScore) }

    var isLive: Bool { event.isLive }

    var awayLogoURL: String? { event.awayImage }
    var homeLogoURL: String? { event.homeImage }
}

struct GameCard: View {
    let gameViewModel: GameViewModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    TeamLogo(url: gameViewModel.awayLogoURL, size: 40)

                    Text(gameViewModel.awayTeam)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer()

                    if let score = gameViewModel.awayScore {
                        Text("\(score)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(score > (gameViewModel.homeScore ?? 0) ? .primary : .secondary)
                    }
                }

                HStack(spacing: 8) {
                    Rectangle()
                        .fill(.separator)
                        .frame(height: 1)

                    if gameViewModel.isLive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.red)
                                .frame(width: 6, height: 6)

                            Text("LIVE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.red)
                        }
                    } else {
                        Text(gameViewModel.time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Rectangle()
                        .fill(.separator)
                        .frame(height: 1)
                }

                HStack(spacing: 12) {
                    TeamLogo(url: gameViewModel.homeLogoURL, size: 40)

                    Text(gameViewModel.homeTeam)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer()

                    if let score = gameViewModel.homeScore {
                        Text("\(score)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(score > (gameViewModel.awayScore ?? 0) ? .primary : .secondary)
                    }
                }
            }
        }
        .padding(16)
        .glassEffect(
            .regular,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct TeamLogo: View {
    let url: String?
    let size: CGFloat

    var body: some View {
        LazyImage(url: URL(string: url ?? "")) { state in
            if let image = state.image {
                image.resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    ContentView()
}
