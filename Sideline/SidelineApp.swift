//
//  SidelineApp.swift
//  Sideline
//
//  Created by Michael Gillund on 2/6/26.
//

import SwiftUI

@main
struct SidelineApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
import Foundation
import SwiftUI
import Combine


extension ESPNEndpoint {
    static let baseURL = "https://site.api.espn.com/apis/site/v2/sports"
    static let scoreboardPath = "scoreboard"
}

// =====================================================
// MARK: - Shared Session Factory (FAIR TESTING ✅)
// =====================================================

enum SpeedTestSessionFactory {

    static func resetGlobalCache() {
        URLCache.shared.removeAllCachedResponses()
        // If you ever set a custom URLCache, also clear that.
    }

    static func makeEphemeralSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30

        // Optional: tune concurrency (default is fine, but keep it consistent)
        config.httpMaximumConnectionsPerHost = 10

        return URLSession(configuration: config)
    }
}

// =====================================================
// MARK: - SAME URL BUILDER USED BY BOTH CLIENTS ✅
// =====================================================

struct ScoreboardRequestBuilder {

    static func makeScoreboardURL(
        sport: ESPN_Sport,
        league: ESPN_League,
        dates: String
    ) throws -> URL {

        let base = "\(ESPNEndpoint.baseURL)/\(sport.rawValue)/\(league.rawValue)/\(ESPNEndpoint.scoreboardPath)"
        guard var comps = URLComponents(string: base) else { throw ESPNAPIError.invalidURL }

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "dates", value: dates)
        ]

        if league == .ncaam {
            queryItems.append(URLQueryItem(name: "groups", value: "50"))
        }
        if league == .ncaaf {
            queryItems.append(URLQueryItem(name: "groups", value: "80"))
        }

        comps.queryItems = queryItems
        guard let url = comps.url else { throw ESPNAPIError.invalidURL }

        print("🌐 SCOREBOARD URL -> \(sport.rawValue) / \(league.rawValue)")
        print("    \(url.absoluteString)")

        return url
    }

    static func makeURLRequest(url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.cachePolicy = .reloadIgnoringLocalCacheData // ✅ fairness
        req.timeoutInterval = 30
        return req
    }

    static var decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
}

// =====================================================
// MARK: - Client A: Async/Await
// =====================================================

final class SpeedTesterClientAsync {
    private let session: URLSession
    init(session: URLSession) { self.session = session }

    func scoreboard(
        sport: ESPN_Sport,
        league: ESPN_League,
        dates: String
    ) async throws -> Scoreboard {

        let url = try ScoreboardRequestBuilder.makeScoreboardURL(sport: sport, league: league, dates: dates)
        let req = ScoreboardRequestBuilder.makeURLRequest(url: url)

        let t0 = CFAbsoluteTimeGetCurrent()
//        print("🚀 ASYNC START -> \(league.rawValue)  t=\(t0)  main=\(Thread.isMainThread)")

        let (data, response) = try await session.data(for: req)

        let t1 = CFAbsoluteTimeGetCurrent()
        print("✅ ASYNC END   -> \(league.rawValue)  dt=\(Int((t1 - t0) * 1000))ms  bytes=\(data.count)")

        guard let http = response as? HTTPURLResponse else { throw ESPNAPIError.responseError(statusCode: -1) }
        guard (200..<300).contains(http.statusCode) else { throw ESPNAPIError.responseError(statusCode: http.statusCode) }

        do { return try ScoreboardRequestBuilder.decoder.decode(Scoreboard.self, from: data) }
        catch { throw ESPNAPIError.decodingError(error) }
    }
}

// =====================================================
// MARK: - Client B: Combine
// =====================================================

final class SpeedTesterClientCombine {
    private let session: URLSession
    init(session: URLSession) { self.session = session }

    func scoreboard(
        sport: ESPN_Sport,
        league: ESPN_League,
        dates: String
    ) -> AnyPublisher<Scoreboard, Error> {

        do {
            let url = try ScoreboardRequestBuilder.makeScoreboardURL(sport: sport, league: league, dates: dates)
            let req = ScoreboardRequestBuilder.makeURLRequest(url: url)

            let t0 = CFAbsoluteTimeGetCurrent()

            return session.dataTaskPublisher(for: req)
                .handleEvents(
                    receiveSubscription: { _ in
                        print("🚀 COMBINE START -> \(league.rawValue)  t=\(t0)  main=\(Thread.isMainThread)")
                    },
                    receiveOutput: { output in
                        let t1 = CFAbsoluteTimeGetCurrent()
                        print("✅ COMBINE DATA  -> \(league.rawValue)  dt=\(Int((t1 - t0) * 1000))ms  bytes=\(output.data.count)")
                    },
                    receiveCompletion: { completion in
                        if case .failure(let err) = completion {
                            print("❌ COMBINE FAIL -> \(league.rawValue): \(err)")
                        }
                    }
                )
                .tryMap { output -> Data in
                    guard let http = output.response as? HTTPURLResponse else { throw ESPNAPIError.responseError(statusCode: -1) }
                    guard (200..<300).contains(http.statusCode) else { throw ESPNAPIError.responseError(statusCode: http.statusCode) }
                    return output.data
                }
                .tryMap { data -> Scoreboard in
                    do { return try ScoreboardRequestBuilder.decoder.decode(Scoreboard.self, from: data) }
                    catch { throw ESPNAPIError.decodingError(error) }
                }
                .eraseToAnyPublisher()

        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
}

// =====================================================
// MARK: - Speed Test Harness
// =====================================================

struct LeagueRequest: Identifiable, Hashable {
    let id = UUID()
    let sport: ESPN_Sport
    let league: ESPN_League
}

struct LeagueTiming: Identifiable {
    let id = UUID()
    let league: ESPN_League
    let ms: Int
    let eventsCount: Int
    let error: String?
}

@MainActor
final class SpeedTestViewModel: ObservableObject {

    @Published var isRunning = false
    @Published var lastRunTitle: String = ""
    @Published var totalMS: Int = 0
    @Published var results: [LeagueTiming] = []

    private var cancellables = Set<AnyCancellable>()

    private let requests: [LeagueRequest] = [
        .init(sport: .football, league: .nfl),
        .init(sport: .football, league: .ncaaf),
        .init(sport: .basketball, league: .nba),
        .init(sport: .basketball, league: .ncaam),
        .init(sport: .basketball, league: .wnba),
        .init(sport: .baseball, league: .mlb),
        .init(sport: .hockey, league: .nhl),
        .init(sport: .golf, league: .pga),
        .init(sport: .golf, league: .liv),
    ]

    // ✅ For fairness: clear cache + use fresh ephemeral session each run
    private func makeClients() -> (SpeedTesterClientAsync, SpeedTesterClientCombine) {
        SpeedTestSessionFactory.resetGlobalCache()
        let session = SpeedTestSessionFactory.makeEphemeralSession()
        return (SpeedTesterClientAsync(session: session), SpeedTesterClientCombine(session: session))
    }

    func runAsyncSpeedTest(dates: String) {
        guard !isRunning else { return }
        isRunning = true
        lastRunTitle = "Async/Await"
        results = []
        totalMS = 0

        let (asyncClient, _) = makeClients()

        Task {
            let startTotal = CFAbsoluteTimeGetCurrent()
            print("🧪 ASYNC TEST START t=\(startTotal)")

            var timings: [LeagueTiming] = []
            timings.reserveCapacity(requests.count)

            await withTaskGroup(of: LeagueTiming.self) { group in
                for req in requests {
                    group.addTask {
                        let t0 = CFAbsoluteTimeGetCurrent()
                        do {
                            let sb = try await asyncClient.scoreboard(
                                sport: req.sport,
                                league: req.league,
                                dates: dates
                            )
                            let dt = CFAbsoluteTimeGetCurrent() - t0
                            return LeagueTiming(league: req.league, ms: Int(dt * 1000), eventsCount: sb.events.count, error: nil)
                        } catch {
                            let dt = CFAbsoluteTimeGetCurrent() - t0
                            return LeagueTiming(league: req.league, ms: Int(dt * 1000), eventsCount: 0, error: error.localizedDescription)
                        }
                    }
                }

                for await timing in group {
                    timings.append(timing)
                }
            }

            timings.sort { $0.league.displayName < $1.league.displayName }

            let totalDT = CFAbsoluteTimeGetCurrent() - startTotal
            print("🏁 ASYNC TEST END dt=\(Int(totalDT * 1000))ms")

            self.results = timings
            self.totalMS = Int(totalDT * 1000)
            self.isRunning = false
        }
    }

    func runCombineSpeedTest(dates: String) {
        guard !isRunning else { return }
        isRunning = true
        lastRunTitle = "Combine"
        results = []
        totalMS = 0
        cancellables.removeAll()

        let (_, combineClient) = makeClients()

        let startTotal = CFAbsoluteTimeGetCurrent()
        print("🧪 COMBINE TEST START t=\(startTotal)")

        let pubs: [AnyPublisher<LeagueTiming, Never>] = requests.map { req in
            let t0 = CFAbsoluteTimeGetCurrent()

            return combineClient
                .scoreboard(sport: req.sport, league: req.league, dates: dates)
                .map { sb -> LeagueTiming in
                    let dt = CFAbsoluteTimeGetCurrent() - t0
                    return LeagueTiming(league: req.league, ms: Int(dt * 1000), eventsCount: sb.events.count, error: nil)
                }
                .catch { err -> Just<LeagueTiming> in
                    let dt = CFAbsoluteTimeGetCurrent() - t0
                    return Just(LeagueTiming(league: req.league, ms: Int(dt * 1000), eventsCount: 0, error: err.localizedDescription))
                }
                .eraseToAnyPublisher()
        }

        Publishers.MergeMany(pubs)
            .collect()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] collected in
                guard let self else { return }

                var timings = collected
                timings.sort { $0.league.displayName < $1.league.displayName }

                let totalDT = CFAbsoluteTimeGetCurrent() - startTotal
                print("🏁 COMBINE TEST END dt=\(Int(totalDT * 1000))ms")

                self.results = timings
                self.totalMS = Int(totalDT * 1000)
                self.isRunning = false
            }
            .store(in: &cancellables)
    }
}

// =====================================================
// MARK: - SwiftUI Test View
// =====================================================

struct SpeedTestView: View {
    @StateObject private var vm = SpeedTestViewModel()

    // Pick a fixed date range so runs are consistent.
    // You can wire this to your week logic if you want.
    @State private var dates: String = {
        // Default: today only
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f.string(from: Date())
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {

                VStack(alignment: .leading, spacing: 6) {
                    Text("Dates (yyyyMMdd or yyyyMMdd-yyyyMMdd)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("dates", text: $dates)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
                .padding(.horizontal)

                HStack(spacing: 12) {
                    Button {
                        vm.runAsyncSpeedTest(dates: dates)
                    } label: {
                        Text(vm.isRunning && vm.lastRunTitle == "Async/Await" ? "Running..." : "Run Async")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.isRunning)

                    Button {
                        vm.runCombineSpeedTest(dates: dates)
                    } label: {
                        Text(vm.isRunning && vm.lastRunTitle == "Combine" ? "Running..." : "Run Combine")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.isRunning)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Last Run: \(vm.lastRunTitle)")
                        .font(.headline)

                    Text("Total: \(vm.totalMS) ms")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                List {
                    ForEach(vm.results) { r in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.league.displayName)
                                    .font(.headline)
                                if let err = r.error {
                                    Text(err)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                        .lineLimit(2)
                                } else {
                                    Text("events: \(r.eventsCount)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Text("\(r.ms) ms")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(r.error == nil ? .primary : .secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("ESPN Speed Test")
        }
    }
}


// =====================================================
// MARK: - Preview
// =====================================================

#Preview {
    SpeedTestView()
}
