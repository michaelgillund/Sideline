//
//  Event.swift
//  Sideline
//
//  Created by Michael Gillund on 2/9/26.
//

import Foundation

struct Event: Codable, Identifiable {
    let id: String?
    let date: String?
    let competitions: [Competition]?
    let links: [Link]?
    let status: Status?
    let shortName: String?
    let groupings: [Groupings]?
    
    struct Groupings: Codable, Identifiable {
        struct Grouping: Codable {
            let id: String?
            let slug: String?
            let displayName: String?
        }
        
        struct Competition: Codable, Identifiable {
            struct Status: Codable {
                struct `Type`: Codable {
                    let id: String?
                    let name: String?
                    let state: String?
                    let completed: Bool?
                    let description: String?
                    let detail: String?
                    let shortDetail: String?
                }
                
                let period: Int?
                let type: `Type`?
            }
            
            struct Venue: Codable {
                let fullName: String?
                let court: String?
            }
            
            struct Format: Codable {
                struct Regulation: Codable {
                    let periods: Int?
                }
                
                let regulation: Regulation?
            }
            
            struct Note: Codable {
                let text: String?
                let type: String?
            }
            
            struct GeoBroadcast: Codable {
                struct `Type`: Codable {
                    let id: String?
                    let shortName: String?
                }
                
                struct Market: Codable {
                    let id: String?
                    let type: String?
                }
                
                struct Medium: Codable {
                    let shortName: String?
                }
                
                let type: `Type`?
                let market: Market?
                let media: Medium?
                let lang: String?
                let region: String?
            }
            
            struct Broadcast: Codable {
                let market: String?
                let names: [String]?
            }
            
            struct Competitor: Codable {
                struct Linescore: Codable, Identifiable {
                    let id: UUID = UUID()
                    let value: Double?
                    let winner: Bool?
                    let tiebreak: Int?
                }
                
                struct Athlete: Codable {
                    struct Flag: Codable {
                        let href: String?
                        let alt: String?
                        let rel: [String]?
                    }
                    
                    struct Link: Codable {
                        let language: String?
                        let rel: [String]?
                        let href: URL?
                        let text: String?
                        let shortText: String?
                        let isExternal: Bool?
                        let isPremium: Bool?
                        let isHidden: Bool?
                    }
                    
                    let guid: String?
                    let displayName: String?
                    let shortName: String?
                    let fullName: String?
                    let flag: Flag?
                    let links: [Link]?
                }
                
                struct CuratedRank: Codable {
                    let current: Int?
                }
                
                struct Roster: Codable {
                    struct Athlete: Codable {
                        struct Flag: Codable {
                            let href: String?
                            let alt: String?
                            let rel: [String]?
                        }
                        
                        struct Link: Codable {
                            let language: String?
                            let rel: [String]?
                            let href: String?
                            let text: String?
                            let shortText: String?
                            let isExternal: Bool?
                            let isPremium: Bool?
                            let isHidden: Bool?
                        }
                        
                        let guid: String?
                        let displayName: String?
                        let shortName: String?
                        let fullName: String?
                        let flag: Flag?
                        let links: [Link]?
                    }
                    
                    let displayName: String?
                    let shortDisplayName: String?
                    let athletes: [Athlete]?
                }
                
                let id: String?
                let uid: String?
                let type: String?
                let order: Int?
                let homeAway: String?
                let winner: Bool?
                let linescores: [Linescore]?
                let athlete: Athlete?
                let curatedRank: CuratedRank?
                let roster: Roster?
            }
            
            struct `Type`: Codable {
                let id: String?
                let text: String?
                let slug: String?
            }
            
            struct Round: Codable {
                let id: String?
                let displayName: String?
            }
            
            func stringToDate() -> Date? {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mmX"
                dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
                dateFormatter.locale = .current
                
                if let date = dateFormatter.date(from: date ?? "") {
                    return date
                } else {
                    print("Invalid date format")
                    return nil
                }
            }
            
            let id: String?
            let uid: String?
            let date: String?
            let startDate: String?
            let timeValid: Bool?
            let recent: Bool?
            let status: Status?
            let venue: Venue?
            let format: Format?
            let notes: [Note]?
            let geoBroadcasts: [GeoBroadcast]?
            let broadcasts: [Broadcast]?
            let competitors: [Competitor]?
            let tournamentId: Int?
            let type: `Type`?
            let round: Round?
            let wasSuspended: Bool?
            
            var isLive: Bool {
                guard let state = status?.type?.state else { return false }
                return !state.hasPrefix("pre") && !state.hasPrefix("post")
            }
            
            var isPre: Bool {
                return status?.type?.state?.hasPrefix("pre") ?? false
            }
            
            var isPost: Bool {
                return status?.type?.state?.hasPrefix("post") ?? false
            }
            
            var isPostponed: Bool {
                return status?.type?.detail?.hasPrefix("Postponed") ?? false
            }
            
            var gametime: String {
                guard let state = status?.type?.state else { return "" }
                guard let game = status?.type?.shortDetail?
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: "of ", with: "") else { return "" }
                
                if state.hasPrefix("pre") {
                    return formattedDate(date)
                } else if game.hasPrefix("1st") || game.hasPrefix("2nd") || game.hasPrefix("3rd") || game.hasPrefix("4th"){
                    return game + " Set"
                } else {
                    return game
                }
            }
            private func formattedDate(_ dateString: String?) -> String {
                guard let dateString = dateString else { return "" }
                
                let inputFormatter = DateFormatter()
                inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mmZ"
                
                if let date = inputFormatter.date(from: dateString) {
                    let outputFormatter = DateFormatter()
                    outputFormatter.locale = Locale(identifier: "en_US")
                    outputFormatter.dateFormat = "h:mm a"
                    return outputFormatter.string(from: date)
                }
                
                return ""
            }
        }
        
        let grouping: Grouping?
        let competitions: [Competition]?
        let id: UUID = UUID()
    }
    
    struct Competition: Codable {
        let id: String?
        let date: String?
        let competitors: [Competitor]?
        let status: Status?
        let notes: [Notes]?
        let odds: [Odd]?
        let situation: Situation?
        let series: Series?
        
        struct Series: Codable {
            let type: String?
            let title: String?
            let summary: String?
            let completed: Bool?
            let totalCompetitions: Int?
            let competitors: [Competitor]?
            
            struct Competitor: Codable {
                let id: String?
                let uid: String?
                let wins: Int?
                let ties: Int?
            }
        }
        
        struct Competitor: Codable, Identifiable {
            let id: String?
            let uid: String?
            let team: Team?
            let score: String?
            let linescores: [Linescore]?
            let hits: Int?
            let errors: Int?
            let order: Int?
            let athlete: Athlete?
            let records: [Record]?
            
            struct Record: Codable {
                let name: String?
                let abbreviation: String?
                let type: String?
                let summary: String?
            }
            
            struct Athlete: Codable {
                let fullName: String?
                let displayName: String?
                let shortName: String?
                let flag: Flag?
                
                struct Flag: Codable {
                    let href: String?
                }
            }
            
            struct Team: Codable {
                let id: String?
                let name: String?
                let abbreviation: String?
                let displayName: String?
                let shortDisplayName: String?
                let color: String?
                let alternateColor: String?
                let logo: String?
            }
            
            struct Linescore: Codable {
                let value: Int?
                
                enum CodingKeys: String, CodingKey {
                    case value
                }
            }
        }
        
        struct Situation: Codable {
            let balls: Int?
            let strikes: Int?
            let outs: Int?
            let onFirst: Bool?
            let onSecond: Bool?
            let onThird: Bool?
            var lastPlay: LastPlay?
            var down: Int?
            var yardLine: Int?
            var distance: Int?
            var downDistanceText: String?
            var shortDownDistanceText: String?
            var possessionText: String?
            var isRedZone: Bool?
            var homeTimeouts: Int?
            var awayTimeouts: Int?
            var possession: String?
            let batter: Player?
            
            struct Player: Codable {
                let playerId: Int?
            }
            
            struct LastPlay: Codable {
                var id: String?
                var type: PlayType?
                var text: String?
                var scoreValue: Int?
                var team: Team?
                var probability: Probability?
                var drive: Drive?
                var start: PlayPosition?
                var end: PlayPosition?
                var statYardage: Int?
                var athletesInvolved: [Athlete]?
                
                struct PlayType: Codable {
                    var id: String?
                    var text: String?
                    var abbreviation: String?
                }
                
                struct Team: Codable {
                    var id: String?
                }
                
                struct Probability: Codable {
                    var tiePercentage: Double?
                    var homeWinPercentage: Double?
                    var awayWinPercentage: Double?
                    var secondsLeft: Int?
                }
                
                struct Drive: Codable {
                    var description: String?
                    var start: PlayPosition?
                    var timeElapsed: TimeElapsed?
                    
                    struct TimeElapsed: Codable {
                        var displayValue: String?
                    }
                }
                
                struct PlayPosition: Codable {
                    var yardLine: Int?
                    var team: Team?
                }
                
                struct Athlete: Codable {
                    var id: String?
                    var fullName: String?
                    var displayName: String?
                    var shortName: String?
                    var links: [Link]?
                    var headshot: String?
                    var jersey: String?
                    var position: String?
                    var team: Team?
                    
                    struct Link: Codable {
                        var rel: [String]?
                        var href: String?
                    }
                }
            }
        }
        
        struct Odd: Codable {
            struct Provider: Codable {
                let id: String?
                let name: String?
            }
            
            let provider: Provider?
            let details: String?
            let overUnder: Double?
            let spread: Double?
        }
        
        struct Notes: Codable {
            let type: String?
            let headline: String?
        }
        
        struct Status: Codable {
            let clock: Double?
            let displayClock: String?
            let period: Int?
            let type: `Type`?
            
            struct `Type`: Codable {
                let id: String?
                let name: String?
                let state: String?
                let completed: Bool?
                let description: String?
                let detail: String?
                let shortDetail: String?
            }
        }
    }
    
    struct Link: Codable {
        let href: String?
    }
    
    struct Status: Codable {
        let clock: Double?
        let displayClock: String?
        let period: Int?
        let type: `Type`?
        
        struct `Type`: Codable {
            let id: String?
            let name: String?
            let state: String?
            let completed: Bool?
            let description: String?
            let detail: String?
            let shortDetail: String?
        }
    }
}

extension Event {
    
    // MARK: - Sorting
    
    var sorted: String {
        guard let state = status?.type?.state else { return "" }
        switch state {
        case let s where s.hasPrefix("pre"):
            return "B"
        case let s where s.hasPrefix("in"):
            return "A"
        case let s where s.hasPrefix("post"):
            return "C"
        default:
            return ""
        }
    }
    
    // MARK: - League
    
    var league: String {
        guard let link = links?.first?.href else { return "" }
        switch true {
        case link.contains("nfl"): return "nfl"
        case link.contains("nba"): return "nba"
        case link.contains("mlb"): return "mlb"
        case link.contains("nhl"): return "nhl"
        case link.contains("college-football"): return "ncaaf"
        case link.contains("mens-college-basketball"): return "ncaab"
        default: return ""
        }
    }
    
    // MARK: - Odds
    
    var spread: String {
        return competitions?.first?.odds?.first?.details ?? ""
    }
    
    // MARK: - Game Time
    
    var gametime: String {
        guard let state = status?.type?.state else { return "" }
        guard let game = status?.type?.shortDetail?
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "of ", with: "") else { return "" }
        
        if state.hasPrefix("pre") {
            return formattedDate(date)
        } else if game.localizedCaseInsensitiveContains("Top") {
            let topSymbol = "▲"
            return game.replacingOccurrences(of: "Top", with: topSymbol)
        } else if game.localizedCaseInsensitiveContains("Bottom") {
            let bottomSymbol = "▼"
            return game.replacingOccurrences(of: "Bottom", with: bottomSymbol)
        } else if game.localizedCaseInsensitiveContains("Bot") {
            let bottomSymbol = "▼"
            return game.replacingOccurrences(of: "Bot", with: bottomSymbol)
        } else {
            return game
        }
    }
    
    // MARK: - State
    
    var state: String {
        return status?.type?.state ?? ""
    }
    
    var isLive: Bool {
        guard let state = status?.type?.state else { return false }
        return !state.hasPrefix("pre") && !state.hasPrefix("post")
    }
    
    var isPre: Bool {
        return status?.type?.state?.hasPrefix("pre") ?? false
    }
    
    var isPost: Bool {
        return status?.type?.state?.hasPrefix("post") ?? false
    }
    
    var isPostponed: Bool {
        return status?.type?.detail?.hasPrefix("Postponed") ?? false
    }
    
    var isHomeWinning: Bool {
        guard let homeScore = Int(homeScore), let awayScore = Int(awayScore) else { return false }
        return homeScore > awayScore
    }
    
    var isAwayWinning: Bool {
        guard let homeScore = Int(homeScore), let awayScore = Int(awayScore) else { return false }
        return awayScore > homeScore
    }
    
    // MARK: - Home Team
    
    var homeId: String {
        return homeTeam?.id ?? ""
    }
    var homeColor: String {
        return homeTeam?.color ?? ""
    }
    
    var homeAltColor: String {
        return homeTeam?.alternateColor ?? ""
    }
    var homeAbbreviation: String {
        return homeTeam?.abbreviation ?? ""
    }
    
    var homeName: String {
        return homeTeam?.shortDisplayName ?? ""
    }
    
    var homeImage: String {
        return adjustURL(homeTeam?.logo ?? "")
    }
    var homeDarkImage: String {
        return adjustImageURLForDarkMode(homeTeam?.logo ?? "")
    }
    var homeScore: String {
        guard let description = status?.type?.description, !description.hasPrefix("Scheduled") else {
            return ""
        }
        return homeCompetitor?.score ?? ""
    }
    
    var homeLinescore: [Competition.Competitor.Linescore] {
        return homeCompetitor?.linescores ?? []
    }
    
    var homeRecord: String {
        return homeCompetitor?.records?.first(where: { $0.type == "total"})?.summary ?? ""
    }
    
    // MARK: - Away Team
    var awayId: String {
        return awayTeam?.id ?? ""
    }
    var awayColor: String {
        return awayTeam?.color ?? ""
    }
    var awayAltColor: String {
        return awayTeam?.alternateColor ?? ""
    }
    
    var awayAbbreviation: String {
        return awayTeam?.abbreviation ?? ""
    }
    
    var awayName: String {
        return awayTeam?.shortDisplayName ?? ""
    }
    
    var awayImage: String {
        return adjustURL(awayTeam?.logo ?? "")
    }
    var awayDarkImage: String {
        return adjustImageURLForDarkMode(awayTeam?.logo ?? "")
    }
    var awayScore: String {
        guard let description = status?.type?.description, !description.hasPrefix("Scheduled") else {
            return ""
        }
        return awayCompetitor?.score ?? ""
    }
    
    var awayLinescore: [Competition.Competitor.Linescore] {
        return awayCompetitor?.linescores ?? []
    }
    
    var awayRecord: String {
        return awayCompetitor?.records?.first(where: { $0.type == "total"})?.summary ?? ""
    }
    
    // MARK: - Playoff
    
    var isPlayoff: Bool {
        return competitions?.first?.series?.type == "playoff"
    }
    
    var playoffTop: String {
        guard isPlayoff else { return "" }
        let originalHeadline = competitions?.first?.notes?.first?.headline ?? ""
        return originalHeadline.replacingOccurrences(of: " - ", with: " ")
    }
    
    var playoffHeadline: String {
        guard isPlayoff else { return "" }
        let originalHeadline = competitions?.first?.notes?.first?.headline ?? ""
        let series = " • \(playoffSeries)"
        return originalHeadline.replacingOccurrences(of: "-", with: "•") + series
    }
    
    var playoffSummary: String {
        guard isPlayoff else { return "" }
        return competitions?.first?.series?.summary ?? ""
    }
    
    var awayPlayoffWins: String {
        guard isPlayoff else { return "0" }
        return String(competitions?[0].series?.competitors?[1].wins ?? 0)
    }
    
    var homePlayoffWins: String {
        guard isPlayoff else { return "0" }
        return String(competitions?[0].series?.competitors?[0].wins ?? 0)
    }
    
    var playoffSeries: String {
        guard isPlayoff else { return "" }
        
        let awayWins = competitions?[0].series?.competitors?[1].wins ?? 0
        let homeWins = competitions?[0].series?.competitors?[0].wins ?? 0
        
        if awayWins == homeWins {
            return "Series \(awayWins)-\(homeWins)"
        } else if awayWins > homeWins {
            return "\(awayName) \(awayWins)-\(homeWins)"
        } else {
            return "\(homeName) \(homeWins)-\(awayWins)"
        }
    }
    
    // MARK: - Football Specific
    var situation: String {
        guard isLive else { return "" }
        return competitions?.first?.situation?.downDistanceText ?? ""
    }
    
    // MARK: - Baseball Specific
    
    var outs: String {
        guard isLive else { return "" }
        let outCount = competitions?.first?.situation?.outs ?? 0
        return "\(outCount) Out\(outCount != 1 ? "s" : "")"
    }
    var strikes: String {
        guard isLive else { return "" }
        let strikes = competitions?.first?.situation?.strikes ?? 0
        return "\(strikes)"
    }
    var balls: String {
        guard isLive else { return "" }
        let balls = competitions?.first?.situation?.balls ?? 0
        return "\(balls)"
    }
    
    var isOnFirstBase: Bool {
        return competitions?.first?.situation?.onFirst ?? false
    }
    
    var isOnSecondBase: Bool {
        return competitions?.first?.situation?.onSecond ?? false
    }
    
    var isOnThirdBase: Bool {
        return competitions?.first?.situation?.onThird ?? false
    }
    
    var homeHits: String {
        return "\(homeCompetitor?.hits ?? 0)"
    }
    
    var awayHits: String {
        return "\(awayCompetitor?.hits ?? 0)"
    }
    
    var homeErrors: String {
        return "\(homeCompetitor?.errors ?? 0)"
    }
    
    var awayErrors: String {
        return "\(awayCompetitor?.errors ?? 0)"
    }
    
    var seriesSummary: String {
        return competitions?.first?.series?.summary ?? ""
    }
    
    // MARK: - Helper Methods
    
    private var homeCompetitor: Competition.Competitor? {
        return competitions?.first?.competitors?.first
    }
    
    private var awayCompetitor: Competition.Competitor? {
        return competitions?.first?.competitors?.last
    }
    
    private var homeTeam: Competition.Competitor.Team? {
        return homeCompetitor?.team
    }
    
    private var awayTeam: Competition.Competitor.Team? {
        return awayCompetitor?.team
    }
    
    private func adjustURL(_ urlString: String) -> String {
        return urlString.replacingOccurrences(of: "/scoreboard", with: "")
    }
    
    private func formattedDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "" }
        
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mmZ"
        
        if let date = inputFormatter.date(from: dateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.locale = Locale(identifier: "en_US")
            outputFormatter.dateFormat = "h:mm a"
            return outputFormatter.string(from: date)
        }
        
        return ""
    }
    func adjustImageURLForDarkMode(_ url: String) -> String {
        var adjustedURL = url
        if let range = adjustedURL.range(of: "500") {
            let endIndex = range.upperBound
            adjustedURL.insert(contentsOf: "-dark", at: endIndex)
        }
        return adjustedURL
    }
}
