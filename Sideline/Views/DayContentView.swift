import SwiftUI
import NukeUI

struct DayContentView: View {
    let date: Date
    let scoreboards: [GroupedScoreboard]
    let isLoading: Bool
    let showSkeleton: Bool

    private let leagueOrder: [ESPN_League] = [
        .nfl, .ncaaf,
        .nba, .ncaam, .wnba,
        .mlb,
        .nhl,
        .pga, .liv,
        .mls, .premierLeague, .laLiga, .bundesliga, .serieA, .ligue1, .uefaChampions,
        .f1
    ]

    private var sections: [(league: ESPN_League, games: [Event])] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!

        let todaysBoards = scoreboards.filter { $0.date >= dayStart && $0.date < dayEnd }
        var map: [ESPN_League: [Event]] = [:]

        for board in todaysBoards {
            for content in board.events {
                switch content {
                case .event(let event):
                    map[board.league, default: []].append(event)
                case .golf:
                    continue
                }
            }
        }

        for (league, games) in map {
            map[league] = games.sorted { g1, g2 in
                if g1.isLive && !g2.isLive { return true }
                if !g1.isLive && g2.isLive { return false }
                return (g1.date ?? "") < (g2.date ?? "")
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
        if showSkeleton {
            DaySkeletonView()
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(spacing: 18) {
                        ForEach(sections, id: \.league) { section in
                            VStack(alignment: .leading, spacing: 10) {
                                LeagueHeader(league: section.league)

                                GlassEffectContainer {
                                    VStack(spacing: 12) {
                                        ForEach(section.games) { event in
                                            GameCard(event: event)
                                        }
                                    }
                                }
                            }
                        }

                        if sections.isEmpty && !isLoading {
                            VStack(spacing: 10) {
                                Image(systemName: "sportscourt")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text("No games")
                                    .font(.headline)
                                Text("Try another day.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 30)
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
}

struct LeagueHeader: View {
    let league: ESPN_League

    var body: some View {
        HStack(spacing: 4) {
            if league == .ncaaf || league == .ncaam {
                Image(systemName: league.symbol)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 20, height: 20)
            } else {
                Image(league.logo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 24, height: 24)
            }

            Text(league.displayName)
                .font(.headline)
                .fontWeight(.bold)
                .fontWidth(.condensed)

            Spacer()
        }
    }
}

struct GameCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let event: Event

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {

                HStack(spacing: 10) {
                    TeamLogo(
                        url: colorScheme == .dark ? event.awayDarkImage : event.awayImage,
                        size: 40
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        Text(event.awayName)
                            .fontWeight(.bold)
                            .fontWidth(.condensed)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Text(event.awayRecord)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }

                    Spacer()

                    if let score = Int(event.awayScore) {
                        Text("\(score)")
                            .font(.title)
                            .fontWeight(.bold)
                            .fontWidth(.compressed)
                            .foregroundStyle(score > (Int(event.homeScore) ?? 0) ? .primary : .secondary)
                    }
                }

                HStack(spacing: 8) {
                    Rectangle().fill(.separator).frame(height: 1)

                    if event.isLive {
                        VStack(alignment: .center, spacing: 2) {
                            HStack(spacing: 4) {
                                Circle().fill(.red).frame(width: 6, height: 6)
                                Text("LIVE")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.red)
                            }
                            Text(event.gametime)
                                .font(.caption2)
                                .foregroundStyle(.primary)
                        }
                    } else {
                        let spreadText = event.spread.trimmingCharacters(in: .whitespacesAndNewlines)

                        if !spreadText.isEmpty {
                            VStack(alignment: .center, spacing: 2) {
                                Text(event.gametime)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(spreadText)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        } else {
                            Text(event.gametime)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Rectangle().fill(.separator).frame(height: 1)
                }

                HStack(spacing: 10) {
                    TeamLogo(
                        url: colorScheme == .dark ? event.homeDarkImage : event.homeImage,
                        size: 40
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        Text(event.homeName)
                            .fontWeight(.bold)
                            .fontWidth(.condensed)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Text(event.homeRecord)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }

                    Spacer()

                    if let score = Int(event.homeScore) {
                        Text("\(score)")
                            .font(.title)
                            .fontWeight(.bold)
                            .fontWidth(.compressed)
                            .foregroundStyle(score > (Int(event.awayScore) ?? 0) ? .primary : .secondary)
                    }
                }
            }
        }
        .padding(10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct TeamLogo: View {
    let url: String?
    let size: CGFloat

    var body: some View {
        let resolvedURL: URL? = {
            guard let s = url?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !s.isEmpty,
                  let u = URL(string: s)
            else { return nil }
            return u
        }()

        LazyImage(url: resolvedURL) { state in
            if let image = state.image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: size, height: size)
        .clipped()
    }
}
