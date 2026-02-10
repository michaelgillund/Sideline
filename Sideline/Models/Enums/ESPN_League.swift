//
//  ESPN_League.swift
//  Sideline
//
//  Created by Michael Gillund on 2/9/26.
//

import Foundation

public enum ESPN_League: CaseIterable, Hashable, Codable {
    case pga
    case liv
    case nfl
    case nba
    case mlb
    case nhl
    case ncaaf
    case ncaam
    case wnba
    case mls
    case premierLeague
    case laLiga
    case bundesliga
    case serieA
    case ligue1
    case uefaChampions
    case atpWta
    case ufc
    case f1

    var rawValue: String {
        switch self {
        case .mlb: return "mlb"
        case .nba: return "nba"
        case .ncaam: return "mens-college-basketball"
        case .wnba: return "wnba"
        case .nfl: return "nfl"
        case .ncaaf: return "college-football"
        case .nhl: return "nhl"
        case .mls: return "usa.1"
        case .premierLeague: return "eng.1"
        case .laLiga: return "esp.1"
        case .bundesliga: return "ger.1"
        case .serieA: return "ita.1"
        case .ligue1: return "fra.1"
        case .uefaChampions: return "uefa.champions"
        case .pga: return "pga"
        case .atpWta: return "all"
        case .ufc: return "ufc"
        case .f1: return "f1"
        case .liv: return "liv"
        }
    }
    
    var displayName: String {
        switch self {
        case .mlb: return "MLB"
        case .nba: return "NBA"
        case .ncaam: return "NCAAM"
        case .wnba: return "WNBA"
        case .nfl: return "NFL"
        case .ncaaf: return "NCAAF"
        case .nhl: return "NHL"
        case .mls: return "MLS"
        case .premierLeague: return "EPL"
        case .laLiga: return "La Liga"
        case .bundesliga: return "Bundesliga"
        case .serieA: return "Serie A"
        case .ligue1: return "Ligue 1"
        case .uefaChampions: return "Champions League"
        case .pga: return "PGA"
        case .atpWta: return "Tennis"
        case .ufc: return "UFC"
        case .f1: return "F1"
        case .liv: return "LIVGolf"
        }
    }
    
    var logo: String {
        switch self {
        case .bundesliga:
            return "Bundesliga"

        case .uefaChampions:
            return "Champions League"

        case .premierLeague:
            return "EPL"

        case .f1:
            return "F1"

        case .laLiga:
            return "La Liga"

        case .ligue1:
            return "Ligue 1"

        case .liv:
            return "LIV"

        case .mlb:
            return "MLB"

        case .mls:
            return "MLS"

        case .nba:
            return "NBA"

        case .ncaam:
            return "NCAA"

        case .ncaaf:
            return "NCAA"

        case .nfl:
            return "NFL"

        case .nhl:
            return "NHL"

        case .pga:
            return "PGA"

        case .serieA:
            return "Serie A"

        case .wnba:
            return "WNBA"

        case .atpWta:
            return "ATP"

        case .ufc:
            return "UFC"
        }
    }
}


