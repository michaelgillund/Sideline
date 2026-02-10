//
//  Golf.swift
//  Sideline
//
//  Created by Michael Gillund on 2/9/26.
//

import Foundation

struct Golf: Codable {
    
    struct Event: Codable, Identifiable {
        
        var players: [Competition.Competitor] {
            let competitors = competitions?.flatMap { $0 }.flatMap { $0.competitors ?? [] } ?? []
            return competitors.sorted { $0.sortOrder ?? 0 < $1.sortOrder ?? 0 }
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
            return status?.type?.description?.hasPrefix("Postponed") ?? false
        }
        
        struct League: Codable {
            let id: String?
            let name: String?
            let abbreviation: String?
            let shortName: String?
            let slug: String?
        }
        
        struct Season: Codable {
            let year: Int?
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
        
        struct Tournament: Codable {
            struct ScoringSystem: Codable {
                let id: String?
                let name: String?
            }
            
            let id: String?
            let displayName: String?
            let major: Bool?
            let scoringSystem: ScoringSystem?
            let numberOfRounds: Int?
            let cutRound: Int?
            let cutScore: Int?
            let cutCount: Int?
        }
        
        struct Status: Codable {
            struct `Type`: Codable {
                let id: String?
                let name: String?
                let state: String?
                let completed: Bool?
                let description: String?
            }
            
            let type: `Type`?
        }
        
        struct Winner: Codable {
            let id: String?
            let displayName: String?
        }
        
        struct DefendingChampion: Codable {
            struct Athlete: Codable {
                let id: String?
                let displayName: String?
                let amateur: Bool?
            }
            
            let athlete: Athlete?
            let displayName: String?
        }
        
        struct PlayoffType: Codable {
            let id: Int?
            let description: String?
            let minimumHoles: Int?
        }
        
        struct Competition: Codable {
            struct Status: Codable {
                struct `Type`: Codable {
                    let id: String?
                    let name: String?
                    let state: String?
                    let description: String?
                    let detail: String?
                    let shortDetail: String?
                }
                
                let period: Int?
                let type: `Type`?
            }
            
            struct Broadcast: Codable {
                struct Medium: Codable {
                    let id: String?
                    let slug: String?
                    let name: String?
                    let shortName: String?
                    let callLetters: String?
                }
                
                let media: Medium?
                let lang: String?
                let region: String?
            }
            
            struct Competitor: Codable, Identifiable {
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
                    
                    struct Position: Codable {
                        let id: String?
                        let displayName: String?
                        let isTie: Bool?
                    }
                    
                    let displayValue: String?
                    let period: Int?
                    let teeTime: String?
                    let hole: Int?
                    let startHole: Int?
                    let thru: Int?
                    let displayThru: String?
                    let playoff: Bool?
                    let behindCurrentRound: Bool?
                    let detail: String?
                    let type: `Type`?
                    let position: Position?
                    let todayDetail: String?
                }
                
                struct Score: Codable {
                    let value: Double?
                    let displayValue: String?
                    let holesRemaining: Int?
                    let draw: Bool?
                    let winner: Bool?
                }
                
                struct Linescore: Codable {
                    let displayValue: String?
                    let period: Int?
                    let inScore: Int?
                    let outScore: Int?
                    let currentPosition: Int?
                    let teeTime: String?
                    let hasStream: Bool?
                    let isPlayoff: Bool?
                    let startPosition: Int?
                }
                
                struct Statistic: Codable {
                    let name: String?
                    let displayValue: String?
                }
                
                struct Athlete: Codable {
                    struct Headshot: Codable {
                        let href: String?
                    }
                    
                    struct Flag: Codable {
                        let href: String?
                        let alt: String?
                    }
                    
                    struct BirthPlace: Codable {
                        let countryAbbreviation: String?
                        let stateAbbreviation: String?
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
                    
                    let id: String?
                    let uid: String?
                    let guid: String?
                    let displayName: String?
                    let shortName: String?
                    let lastName: String?
                    let amateur: Bool?
                    let headshot: Headshot?
                    let flag: Flag?
                    let birthPlace: BirthPlace?
                    let links: [Link]?
                }
                
                struct Roster: Codable {
                    let playerId: Int?
                    let athlete: Athlete?
                    
                    struct Athlete: Codable {
                        let id: String?
                        let uid: String?
                        let displayName: String?
                        let shortName: String?
                        let lastName: String?
                        let amateur: Bool?
                        let headshot: Headshot?
                        let flag: Flag?
                        let birthPlace: BirthPlace?
                        let links: [Link]?
                        
                        struct Headshot: Codable {
                            let href: String?
                        }
                        
                        struct Flag: Codable {
                            let href: String?
                            let alt: String?
                        }
                        
                        struct BirthPlace: Codable {
                            let countryAbbreviation: String?
                            let stateAbbreviation: String?
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
                    }
                }
                struct Team: Codable {
                    let id: String?
                    let abbreviation: String?
                    let displayName: String?
                    let logos: [Logo]?
                }
                
                struct Logo: Codable {
                    let href: String?
                    let alt: String?
                    let rel: [String]?
                    let width: Int?
                    let height: Int?
                }
                
                let id: String?
                let uid: String?
                let movement: Int?
                let earnings: Int?
                let sortOrder: Int?
                let amateur: Bool?
                let featured: Bool?
                let status: Status?
                let score: Score?
                let linescores: [Linescore]?
                let statistics: [Statistic]?
                let athlete: Athlete?
                let roster: [Roster]?
                let team: Team?
                let homeAway: String?
            }
            
            struct Leader: Codable {
                struct Leader: Codable {
                    struct Athlete: Codable {
                        let id: String?
                        let displayName: String?
                    }
                    
                    let displayValue: String?
                    let athlete: Athlete?
                }
                
                let name: String?
                let displayName: String?
                let shortDisplayName: String?
                let abbreviation: String?
                let leaders: [Leader]?
            }
            
            struct HoleByHoleSource: Codable {
                let id: String?
                let state: String?
                let description: String?
            }
            
            struct ScoringSystem: Codable {
                let id: String?
                let name: String?
            }
            
            struct `Type`: Codable {
                let id: String?
                let text: String?
            }
            let id: String?
            let uid: String?
            let date: String?
            let endDate: String?
            let recent: Bool?
            let onWatchESPN: Bool?
            let dataFormat: String?
            let status: Status?
            let broadcasts: [Broadcast]?
            let competitors: [Competitor]?
            let leaders: [Leader]?
            let holeByHoleSource: HoleByHoleSource?
            let scoringSystem: ScoringSystem?
            let description: String?
            let type: `Type`?
            let score: String?
        }
        
        struct Course: Codable {
            struct Hole: Codable {
                let number: Int?
                let shotsToPar: Int?
                let totalYards: Int?
            }
            
            struct Address: Codable {
                let city: String?
                let state: String?
                let country: String?
                let zipCode: String?
            }
            
            let id: String?
            let name: String?
            let totalYards: Int?
            let shotsToPar: Int?
            let parIn: Int?
            let parOut: Int?
            let host: Bool?
            let holes: [Hole]?
            let address: Address?
        }
        
        let id: String?
        let uid: String?
        let date: String?
        let endDate: String?
        let name: String?
        let shortName: String?
        let primary: Bool?
        let hasPlayerStats: Bool?
        let hasCourseStats: Bool?
        let purse: Int?
        let displayPurse: String?
        let league: League?
        let season: Season?
        let links: [Link]?
        let tournament: Tournament?
        let status: Status?
        let winner: Winner?
        let defendingChampion: DefendingChampion?
        let playoffType: PlayoffType?
        let competitions: [Competition]?
        let courses: [Course]?
        
        enum CodingKeys: String, CodingKey {
            case id
            case uid
            case date
            case endDate
            case name
            case shortName
            case primary
            case hasPlayerStats
            case hasCourseStats
            case purse
            case displayPurse
            case league
            case season
            case links
            case tournament
            case status
            case winner
            case defendingChampion
            case playoffType
            case competitions
            case courses
        }
        
        // Custom initializer for decoding
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            id = try? container.decode(String.self, forKey: .id)
            uid = try? container.decode(String.self, forKey: .uid)
            date = try? container.decode(String.self, forKey: .date)
            endDate = try? container.decode(String.self, forKey: .endDate)
            name = try? container.decode(String.self, forKey: .name)
            shortName = try? container.decode(String.self, forKey: .shortName)
            primary = try? container.decode(Bool.self, forKey: .primary)
            hasPlayerStats = try? container.decode(Bool.self, forKey: .hasPlayerStats)
            hasCourseStats = try? container.decode(Bool.self, forKey: .hasCourseStats)
            purse = try? container.decode(Int.self, forKey: .purse)
            displayPurse = try? container.decode(String.self, forKey: .displayPurse)
            league = try? container.decode(League.self, forKey: .league)
            season = try? container.decode(Season.self, forKey: .season)
            links = try? container.decode([Link].self, forKey: .links)
            tournament = try? container.decode(Tournament.self, forKey: .tournament)
            status = try? container.decode(Status.self, forKey: .status)
            winner = try? container.decode(Winner.self, forKey: .winner)
            defendingChampion = try? container.decode(DefendingChampion.self, forKey: .defendingChampion)
            playoffType = try? container.decode(PlayoffType.self, forKey: .playoffType)
            courses = try? container.decode([Course].self, forKey: .courses)
            
            // Custom handling for competitions to support both [Competition] and [[Competition]]
            if let singleArray = try? container.decode([Competition].self, forKey: .competitions) {
                self.competitions = singleArray
            } else if let nestedArray = try? container.decode([[Competition]].self, forKey: .competitions) {
                self.competitions = nestedArray.flatMap { $0 }
            } else {
                self.competitions = nil
            }
        }
    }
    
    let events: [Event]
}
