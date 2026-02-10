//
//  Scoreboard.swift
//  Sideline
//
//  Created by Michael Gillund on 2/9/26.
//

import Foundation

struct Scoreboard: Codable {
    let leagues: [League]
    let events: [Event]
    
    struct League: Codable {
        let id: String?
        let uid: String?
        let name: String?
        let abbreviation: String?
        let slug: String?
        let season: Season?
        let logos: [Logo]?
        let calendarType: String?
        let calendarIsWhitelist: Bool?
        let calendarStartDate: String?
        let calendarEndDate: String?
        let calendar: CalendarType?
        
        struct Season: Codable {
            struct `Type`: Codable {
                let id: String?
                let type: Int?
                let name: String?
                let abbreviation: String?
            }
            
            let year: Int?
            let startDate: String?
            let endDate: String?
            let displayName: String?
            let type: `Type`?
        }
        
        struct Logo: Codable {
            let href: String?
        }
        
        enum CalendarType: Codable {
            case string([String])
            case calendar([Calendar])
            
            struct Calendar: Codable {
                let label: String?
                let value: String?
                let startDate: String?
                let endDate: String?
                let entries: [Entry]?
                
                struct Entry: Codable {
                    let label: String?
                    let alternateLabel: String?
                    let detail: String?
                    let value: String?
                    let startDate: String?
                    let endDate: String?
                }
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let calendarArray = try? container.decode([Calendar].self) {
                    self = .calendar(calendarArray)
                } else if let stringArray = try? container.decode([String].self) {
                    self = .string(stringArray)
                } else {
                    throw DecodingError.typeMismatch(CalendarType.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected an array of strings or an array of Calendar objects"))
                }
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .string(let stringArray):
                    try container.encode(stringArray)
                case .calendar(let calendarArray):
                    try container.encode(calendarArray)
                }
            }
        }
    }
}
