import Foundation
import Combine

@MainActor
final class ScoreboardViewModel: ObservableObject {

    // MARK: - Published
    @Published var scoreboards: [GroupedScoreboard] = []
    @Published var isLoading = false
    @Published var error: Error?

    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @Published private(set) var loadedWeekStart: Date?
    @Published private(set) var loadedWeekEnd: Date?

    // MARK: - Private
    private let client = ESPNClient.shared

    private var pollingCancellable: AnyCancellable?
    private var refreshTask: Task<Void, Never>?

    // Signature of what is currently displayed (after merge)
    private var lastSignature: Int = 0

    private let leagues: [ESPN_Sport: [ESPN_League]] = [
        .baseball: [.mlb],
        .basketball: [.nba, .ncaam, .wnba],
        .football: [.nfl, .ncaaf],
        .hockey: [.nhl],
        .golf: [.pga, .liv]
    ]

    // MARK: - Polling
    func startPolling(every seconds: TimeInterval = 30) {
        stopPolling()

        pollingCancellable = Timer
            .publish(every: seconds, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshTask?.cancel()
                self.refreshTask = Task { [weak self] in
                    guard let self else { return }
                    await self.fetchTodayMerge()
                }
            }
    }

    func stopPolling() {
        pollingCancellable?.cancel()
        pollingCancellable = nil
        refreshTask?.cancel()
        refreshTask = nil
    }

    /// Call this from scenePhase `.active` (or onAppear) to immediately refresh today.
    func refreshNow() async {
        await fetchTodayMerge()
    }

    // MARK: - Public Fetch APIs

    /// Initial load for the visible week.
    /// IMPORTANT: We intentionally remove "today" from the week snapshot and then immediately fetch today-only,
    /// so the app never "rewinds" live clocks on cold launch.
    func fetchCurrentWeek() async {
        var cal = Calendar.current
        cal.firstWeekday = 1 // Sunday

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
        let range = "\(fmt.string(from: start))-\(fmt.string(from: end))"

        // 1) Fetch week snapshot
        let weekGroupsRaw = await fetchGroups(dateRange: range)

        // 2) Remove TODAY from that snapshot so we do not seed UI with an older live clock
        let today = Calendar.current.startOfDay(for: Date())
        let weekMinusToday = weekGroupsRaw.filter { !Calendar.current.isDate($0.date, inSameDayAs: today) }

        applyReplace(weekMinusToday)

        // 3) Immediately fetch today-only and merge it in (so initial view matches what polling will show)
        await fetchTodayMerge()
    }

    /// Polling / foreground refresh: fetch ONLY today and merge into existing week array.
    func fetchTodayMerge() async {
        let today = Calendar.current.startOfDay(for: Date())
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"

        let raw = await fetchGroups(dateRange: fmt.string(from: today))

        // Keep only today groups (paranoia: ESPN can sometimes return events that parse into adjacent day)
        let todayOnly = raw.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }

        applyMerge(newGroups: todayOnly, replacingDays: [today])
    }

    // MARK: - Core Fetch (no mutation of scoreboards except isLoading/error)

    private func fetchGroups(dateRange: String) async -> [GroupedScoreboard] {
        isLoading = true
        error = nil
        defer { isLoading = false }

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
                                let groups = Self.buildEventGroupsPerDay(
                                    league: req.league,
                                    scoreboard: scoreboard
                                )
                                return (req.league, groups)
                            }
                        }
                    }

                    var out: [(ESPN_League, [GroupedScoreboard])] = []
                    for try await item in group { out.append(item) }
                    return out
                }

            return fetched.flatMap { $0.groups }

        } catch {
            self.error = error
            return []
        }
    }

    // MARK: - Apply Results (signature uses final displayed array)

    private func applyReplace(_ newGroups: [GroupedScoreboard]) {
        let sorted = newGroups.sorted(by: Self.defaultSort)
        let sig = Self.signatureHash(for: sorted)
        guard sig != lastSignature else { return }
        lastSignature = sig
        scoreboards = sorted
    }

    private func applyMerge(newGroups: [GroupedScoreboard], replacingDays: [Date]) {
        let cal = Calendar.current
        let daysToReplace = Set(replacingDays.map { cal.startOfDay(for: $0) })

        var merged = scoreboards
        merged.removeAll { daysToReplace.contains(cal.startOfDay(for: $0.date)) }
        merged.append(contentsOf: newGroups)
        merged.sort(by: Self.defaultSort)

        let sig = Self.signatureHash(for: merged)
        guard sig != lastSignature else { return }
        lastSignature = sig
        scoreboards = merged
    }

    private static func defaultSort(_ a: GroupedScoreboard, _ b: GroupedScoreboard) -> Bool {
        if a.date != b.date { return a.date < b.date }
        return a.league.displayName < b.league.displayName
    }

    // MARK: - Group Builders

    nonisolated
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
                for try await item in group { out.append(item) }
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

    // MARK: - Date parsing / Skip

    nonisolated
    private static let espnFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .init(identifier: "en_US_POSIX")
        f.timeZone = .init(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm'Z'"
        return f
    }()

    nonisolated
    private static func parseESPNStatic(_ string: String?) -> Date? {
        guard let s = string else { return nil }
        return espnFormatter.date(from: s)
    }

    private func shouldSkip(league: ESPN_League, dateRange: String) -> Bool {
        // Skip PGA on Mondays only for single-day query
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

    // MARK: - Signature (lightweight)

    private static func signatureHash(for groups: [GroupedScoreboard]) -> Int {
        var hasher = Hasher()
        hasher.combine(groups.count)

        for g in groups {
            hasher.combine(Int(g.date.timeIntervalSince1970))
            hasher.combine(g.league.rawValue)
            hasher.combine(g.events.count)

            for e in g.events {
                switch e {
                case .event(let ev):
                    hasher.combine(ev.id ?? "")
                    hasher.combine(ev.status?.type?.state ?? "")
                    hasher.combine(ev.status?.type?.shortDetail ?? "")
                    hasher.combine(ev.homeScore)
                    hasher.combine(ev.awayScore)

                case .golf(let ge):
                    hasher.combine(ge.id ?? "")
                    hasher.combine(ge.status?.type?.state ?? "")
                    hasher.combine(ge.shortName ?? "")
                    for p in ge.players.prefix(3) {
                        hasher.combine(p.athlete?.displayName ?? "")
                        hasher.combine(p.score?.displayValue ?? "")
                    }
                }
            }
        }

        return hasher.finalize()
    }
}
