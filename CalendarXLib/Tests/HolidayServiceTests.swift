import Foundation
import XCTest
@testable import CalendarXLib

private struct MockHolidayResponse: Sendable {
    let status: Int
    let data: Data
}

private final class HolidayRequestState: @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [Int: MockHolidayResponse] = [:]
    private var urlResponses: [URL: MockHolidayResponse] = [:]
    private var requests: [URL] = []

    func configure(_ responses: [Int: MockHolidayResponse], urlResponses: [URL: MockHolidayResponse]) {
        lock.withLock {
            self.responses = responses
            self.urlResponses = urlResponses
            requests = []
        }
    }

    func response(for url: URL) -> MockHolidayResponse? {
        lock.withLock {
            requests.append(url)
            guard let year = Int(url.deletingPathExtension().lastPathComponent) else { return nil }
            return urlResponses[url] ?? responses[year]
        }
    }

    var count: Int { lock.withLock { requests.count } }
    var requestedURLs: [URL] { lock.withLock { requests } }
}

private final class HolidayURLProtocol: URLProtocol, @unchecked Sendable {
    static let state = HolidayRequestState()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let mock = Self.state.response(for: url) else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let response = HTTPURLResponse(url: url, statusCode: mock.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: mock.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class UpdateCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() { lock.withLock { count += 1 } }
    var value: Int { lock.withLock { count } }
}

@MainActor
final class HolidayServiceTests: XCTestCase {
    private var year: Int { Calendar.current.component(.year, from: Date()) }
    private var lastFetchKey: String {
        "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "CalendarX").holiday.lastFetchDate"
    }

    private func response(year: Int, status: Int = 200) throws -> MockHolidayResponse {
        let data = try JSONSerialization.data(withJSONObject: [
            "year": year,
            "days": [["name": "元旦", "date": "\(year)-01-01", "isOffDay": true]]
        ])
        return MockHolidayResponse(status: status, data: data)
    }

    private func emptyResponse(year: Int) throws -> MockHolidayResponse {
        let data = try JSONSerialization.data(withJSONObject: ["year": year, "days": []])
        return MockHolidayResponse(status: 200, data: data)
    }

    private func primaryURL(_ year: Int) -> URL {
        URL(string: "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/\(year).json")!
    }

    private func fallbackURL(_ year: Int) -> URL {
        URL(string: "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/\(year).json")!
    }

    private func localDate(year: Int, month: Int, day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func withService(
        responses: [Int: MockHolidayResponse] = [:],
        urlResponses: [URL: MockHolidayResponse] = [:],
        now: Date? = nil,
        writable: Bool = true,
        test: (HolidayService, UserDefaults, URL) async throws -> Void
    ) async throws {
        HolidayURLProtocol.state.configure(responses, urlResponses: urlResponses)
        let suite = "CalendarX.HolidayTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = writable ? directory.appendingPathComponent("holiday.json") : directory
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HolidayURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let service = HolidayService(session: session, defaults: defaults, cacheFileURL: url, clock: { now ?? Date() })
        defer {
            session.invalidateAndCancel()
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
            HolidayService.shared.reloadCached()
        }
        try await test(service, defaults, url)
    }

    func testAllRequestsFailPreservesTimestampAndCache() async throws {
        try await withService { service, defaults, url in
            let previous = Date.distantPast
            defaults.set(previous, forKey: lastFetchKey)
            let cached = [String(year): ["0101": Tiaoxiu.ban]]
            let data = try JSONEncoder().encode(cached)
            try data.write(to: url)
            let counter = UpdateCounter()
            let observer = NotificationCenter.default.addObserver(forName: HolidayService.didUpdate, object: nil, queue: nil) { _ in counter.increment() }
            defer { NotificationCenter.default.removeObserver(observer) }

            let refreshed = await service.refreshIfNeeded()
            XCTAssertFalse(refreshed)
            XCTAssertEqual(defaults.object(forKey: lastFetchKey) as? Date, previous)
            XCTAssertEqual(try Data(contentsOf: url), data)
            XCTAssertEqual(counter.value, 0)
            XCTAssertEqual(HolidayURLProtocol.state.requestedURLs, [primaryURL(year), fallbackURL(year), primaryURL(year + 1), fallbackURL(year + 1)])
        }
    }

    func testPartialSuccessPersistsAndNotifies() async throws {
        try await withService(responses: [year: try response(year: year)]) { service, defaults, url in
            let counter = UpdateCounter()
            let observer = NotificationCenter.default.addObserver(forName: HolidayService.didUpdate, object: nil, queue: nil) { _ in counter.increment() }
            defer { NotificationCenter.default.removeObserver(observer) }

            let refreshed = await service.refreshIfNeeded()
            XCTAssertTrue(refreshed)
            XCTAssertNotNil(defaults.object(forKey: lastFetchKey) as? Date)
            let saved = try JSONDecoder().decode([String: [String: Tiaoxiu]].self, from: Data(contentsOf: url))
            XCTAssertEqual(saved[String(year)]?["0101"], .xiu)
            XCTAssertEqual(counter.value, 1)
            XCTAssertEqual(FestivalStore().tiaoxiu(date: Calendar.gregorian.date(from: DateComponents(year: year, month: 1, day: 1))!), .xiu)
        }
    }

    func testCacheWriteFailureDoesNotAdvanceTimestampOrNotify() async throws {
        try await withService(responses: [year: try response(year: year)], writable: false) { service, defaults, _ in
            let counter = UpdateCounter()
            let observer = NotificationCenter.default.addObserver(forName: HolidayService.didUpdate, object: nil, queue: nil) { _ in counter.increment() }
            defer { NotificationCenter.default.removeObserver(observer) }

            let refreshed = await service.refreshIfNeeded()
            XCTAssertFalse(refreshed)
            XCTAssertNil(defaults.object(forKey: lastFetchKey))
            XCTAssertEqual(counter.value, 0)
        }
    }

    func testRecentSuccessSkipsNetwork() async throws {
        try await withService { service, defaults, url in
            let cached = [String(year + 1): ["0101": Tiaoxiu.xiu]]
            try JSONEncoder().encode(cached).write(to: url)
            defaults.set(Date(), forKey: lastFetchKey)
            let refreshed = await service.refreshIfNeeded()
            XCTAssertFalse(refreshed)
            XCTAssertEqual(HolidayURLProtocol.state.count, 0)
        }
    }

    func testMissingNextYearRefreshesDuringNovemberOrDecember() async throws {
        let testYear = 2030
        for month in [11, 12] {
            let now = localDate(year: testYear, month: month, day: 1)
            try await withService(responses: [testYear + 1: try response(year: testYear + 1)], now: now) { service, defaults, url in
                let previous = now.addingTimeInterval(-60)
                defaults.set(previous, forKey: lastFetchKey)
                try JSONEncoder().encode([String(testYear): ["0101": Tiaoxiu.ban]]).write(to: url)
                let counter = UpdateCounter()
                let observer = NotificationCenter.default.addObserver(forName: HolidayService.didUpdate, object: nil, queue: nil) { _ in counter.increment() }
                defer { NotificationCenter.default.removeObserver(observer) }

                let refreshed = await service.refreshIfNeeded()
                XCTAssertTrue(refreshed)
                XCTAssertEqual(HolidayURLProtocol.state.requestedURLs, [primaryURL(testYear + 1)])
                XCTAssertEqual(defaults.object(forKey: lastFetchKey) as? Date, previous)
                guard refreshed else { return }
                let saved = try JSONDecoder().decode([String: [String: Tiaoxiu]].self, from: Data(contentsOf: url))
                XCTAssertEqual(saved[String(testYear)]?["0101"], .ban)
                XCTAssertEqual(saved[String(testYear + 1)]?["0101"], .xiu)
                let nextNewYear = Calendar.gregorian.date(from: DateComponents(year: testYear + 1, month: 1, day: 1))!
                XCTAssertEqual(FestivalStore().tiaoxiu(date: nextNewYear), .xiu)
                XCTAssertEqual(counter.value, 1)

                let secondRefresh = await service.refreshIfNeeded()
                XCTAssertFalse(secondRefresh)
                XCTAssertEqual(HolidayURLProtocol.state.requestedURLs, [primaryURL(testYear + 1)])
                XCTAssertEqual(counter.value, 1)
            }
        }
    }

    func testMissingNextYearFailureRetriesOnNextStartup() async throws {
        let testYear = 2030
        let now = localDate(year: testYear, month: 12, day: 31, hour: 23, minute: 59)
        try await withService(now: now) { service, defaults, url in
            let previous = now.addingTimeInterval(-60)
            defaults.set(previous, forKey: lastFetchKey)
            let cached = try JSONEncoder().encode([String(testYear): ["0101": Tiaoxiu.ban]])
            try cached.write(to: url)

            let firstRefresh = await service.refreshIfNeeded()
            XCTAssertFalse(firstRefresh)
            XCTAssertEqual(HolidayURLProtocol.state.requestedURLs, [primaryURL(testYear + 1), fallbackURL(testYear + 1)])
            XCTAssertEqual(defaults.object(forKey: lastFetchKey) as? Date, previous)
            XCTAssertEqual(try Data(contentsOf: url), cached)

            let secondRefresh = await service.refreshIfNeeded()
            XCTAssertFalse(secondRefresh)
            XCTAssertEqual(HolidayURLProtocol.state.requestedURLs, [primaryURL(testYear + 1), fallbackURL(testYear + 1), primaryURL(testYear + 1), fallbackURL(testYear + 1)])
        }
    }

    func testOctoberAndJanuaryRespectNormalRefreshInterval() async throws {
        let dates = [
            localDate(year: 2030, month: 10, day: 31, hour: 23, minute: 59),
            localDate(year: 2031, month: 1, day: 1, hour: 0, minute: 1)
        ]
        for now in dates {
            try await withService(now: now) { service, defaults, url in
                let currentYear = Calendar.current.component(.year, from: now)
                let cached = [String(currentYear): ["0101": Tiaoxiu.xiu]]
                try JSONEncoder().encode(cached).write(to: url)
                defaults.set(now.addingTimeInterval(-60), forKey: lastFetchKey)
                let refreshed = await service.refreshIfNeeded()
                XCTAssertFalse(refreshed)
                XCTAssertEqual(HolidayURLProtocol.state.count, 0)
            }
        }
    }

    func testEmptyNextYearCacheUsesFallbackAtStartOfNovember() async throws {
        let testYear = 2030
        let now = localDate(year: testYear, month: 11, day: 1, hour: 0, minute: 1)
        try await withService(
            urlResponses: [primaryURL(testYear + 1): try emptyResponse(year: testYear + 1), fallbackURL(testYear + 1): try response(year: testYear + 1)],
            now: now
        ) { service, defaults, url in
            let cached: [String: [String: Tiaoxiu]] = [String(testYear + 1): [:]]
            try JSONEncoder().encode(cached).write(to: url)
            let previous = now.addingTimeInterval(-60)
            defaults.set(previous, forKey: lastFetchKey)
            let refreshed = await service.refreshIfNeeded()
            XCTAssertTrue(refreshed)
            XCTAssertEqual(HolidayURLProtocol.state.requestedURLs, [primaryURL(testYear + 1), fallbackURL(testYear + 1)])
            XCTAssertEqual(defaults.object(forKey: lastFetchKey) as? Date, previous)
            let saved = try JSONDecoder().decode([String: [String: Tiaoxiu]].self, from: Data(contentsOf: url))
            XCTAssertEqual(saved[String(testYear + 1)]?["0101"], .xiu)
        }
    }

    func testNextYearCachedResumesNormal24HourRefresh() async throws {
        let testYear = 2030
        let now = localDate(year: testYear, month: 11, day: 15)
        try await withService(responses: [testYear: try response(year: testYear), testYear + 1: try response(year: testYear + 1)], now: now) { service, defaults, url in
            let cached = [String(testYear + 1): ["0101": Tiaoxiu.xiu]]
            try JSONEncoder().encode(cached).write(to: url)
            defaults.set(now.addingTimeInterval(-60), forKey: lastFetchKey)
            let earlyRefresh = await service.refreshIfNeeded()
            XCTAssertFalse(earlyRefresh)
            XCTAssertEqual(HolidayURLProtocol.state.count, 0)

            defaults.set(now.addingTimeInterval(-86401), forKey: lastFetchKey)
            let regularRefresh = await service.refreshIfNeeded()
            XCTAssertTrue(regularRefresh)
            XCTAssertEqual(HolidayURLProtocol.state.requestedURLs, [primaryURL(testYear), primaryURL(testYear + 1)])
            XCTAssertEqual(defaults.object(forKey: lastFetchKey) as? Date, now)
        }
    }

    func testYearEndCacheWriteFailureDoesNotStopNextStartup() async throws {
        let testYear = 2030
        let now = localDate(year: testYear, month: 11, day: 1)
        try await withService(responses: [testYear + 1: try response(year: testYear + 1)], now: now, writable: false) { service, defaults, _ in
            let previous = now.addingTimeInterval(-60)
            defaults.set(previous, forKey: lastFetchKey)
            let firstRefresh = await service.refreshIfNeeded()
            let secondRefresh = await service.refreshIfNeeded()
            XCTAssertFalse(firstRefresh)
            XCTAssertFalse(secondRefresh)
            XCTAssertEqual(defaults.object(forKey: lastFetchKey) as? Date, previous)
            XCTAssertEqual(HolidayURLProtocol.state.requestedURLs, [primaryURL(testYear + 1), primaryURL(testYear + 1)])
        }
    }

    func testPrimaryDataDoesNotRequestFallback() async throws {
        try await withService(responses: [year: try response(year: year), year + 1: try response(year: year + 1)]) { service, _, _ in
            let refreshed = await service.refreshIfNeeded()
            XCTAssertTrue(refreshed)
            XCTAssertEqual(HolidayURLProtocol.state.requestedURLs, [primaryURL(year), primaryURL(year + 1)])
        }
    }

    func testEmptyPrimaryUsesFallbackForThatYear() async throws {
        try await withService(
            responses: [year: try response(year: year)],
            urlResponses: [primaryURL(year + 1): try emptyResponse(year: year + 1), fallbackURL(year + 1): try response(year: year + 1)]
        ) { service, _, url in
            let refreshed = await service.refreshIfNeeded()
            XCTAssertTrue(refreshed)
            let saved = try JSONDecoder().decode([String: [String: Tiaoxiu]].self, from: Data(contentsOf: url))
            XCTAssertEqual(saved[String(year + 1)]?["0101"], .xiu)
            XCTAssertEqual(HolidayURLProtocol.state.requestedURLs, [primaryURL(year), primaryURL(year + 1), fallbackURL(year + 1)])
        }
    }

    func testFailedFallbackIsNotRetriedAndPreservesCachedYear() async throws {
        try await withService(
            responses: [year: try response(year: year)],
            urlResponses: [primaryURL(year + 1): try emptyResponse(year: year + 1), fallbackURL(year + 1): try response(year: year + 1, status: 500)]
        ) { service, _, url in
            let cached = [String(year + 1): ["0101": Tiaoxiu.ban]]
            try JSONEncoder().encode(cached).write(to: url)
            let refreshed = await service.refreshIfNeeded()
            XCTAssertTrue(refreshed)
            let saved = try JSONDecoder().decode([String: [String: Tiaoxiu]].self, from: Data(contentsOf: url))
            XCTAssertEqual(saved[String(year)]?["0101"], .xiu)
            XCTAssertEqual(saved[String(year + 1)]?["0101"], .ban)
            XCTAssertEqual(HolidayURLProtocol.state.requestedURLs, [primaryURL(year), primaryURL(year + 1), fallbackURL(year + 1)])
        }
    }

    func testUnavailablePrimaryUsesFallbackOnce() async throws {
        try await withService(urlResponses: [fallbackURL(year): try response(year: year)]) { service, _, url in
            let refreshed = await service.refreshIfNeeded()
            XCTAssertTrue(refreshed)
            XCTAssertEqual(HolidayURLProtocol.state.requestedURLs, [primaryURL(year), fallbackURL(year), primaryURL(year + 1), fallbackURL(year + 1)])
            guard refreshed else { return }
            let saved = try JSONDecoder().decode([String: [String: Tiaoxiu]].self, from: Data(contentsOf: url))
            XCTAssertEqual(saved[String(year)]?["0101"], .xiu)
        }
    }

    func testInvalidHTTPAndWrongYearAreNotSuccessfulRefreshes() async throws {
        try await withService(responses: [
            year: try response(year: year, status: 500),
            year + 1: try response(year: year)
        ]) { service, defaults, _ in
            let refreshed = await service.refreshIfNeeded()
            XCTAssertFalse(refreshed)
            XCTAssertNil(defaults.object(forKey: lastFetchKey))
        }
    }

    func testLegacyCacheMigratesWithoutRecordingNetworkSuccess() async throws {
        try await withService { _, defaults, url in
            let legacy = url.deletingLastPathComponent().appendingPathComponent("legacy.json")
            let data = try JSONEncoder().encode([String(year): ["0101": Tiaoxiu.ban]])
            try data.write(to: legacy)
            let previous = Date.distantPast
            defaults.set(previous, forKey: lastFetchKey)
            let service = HolidayService(session: .shared, defaults: defaults, cacheFileURL: url, fallbackCacheFileURL: legacy)

            XCTAssertEqual(service.loadCached()[String(year)]?["0101"], .ban)
            let saved = try JSONDecoder().decode([String: [String: Tiaoxiu]].self, from: Data(contentsOf: url))
            XCTAssertEqual(saved[String(year)]?["0101"], .ban)
            XCTAssertEqual(defaults.object(forKey: lastFetchKey) as? Date, previous)
            XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.path))
        }
    }

    func testLegacyCacheWriteFailurePreservesOriginalDataAndTimestamp() async throws {
        try await withService(writable: false) { _, defaults, directory in
            let legacy = directory.appendingPathComponent("legacy.json")
            let data = try JSONEncoder().encode([String(year): ["0101": Tiaoxiu.ban]])
            try data.write(to: legacy)
            let previous = Date.distantPast
            defaults.set(previous, forKey: lastFetchKey)
            let service = HolidayService(session: .shared, defaults: defaults, cacheFileURL: directory, fallbackCacheFileURL: legacy)

            XCTAssertEqual(service.loadCached()[String(year)]?["0101"], .ban)
            XCTAssertEqual(try Data(contentsOf: legacy), data)
            XCTAssertEqual(defaults.object(forKey: lastFetchKey) as? Date, previous)
        }
    }

    func testReloadCachedRefreshesAlreadyInitializedFestivalStore() async throws {
        try await withService { service, _, url in
            let date = Calendar.gregorian.date(from: DateComponents(year: year, month: 1, day: 1))!
            for expected in [Tiaoxiu.ban, .xiu] {
                let data = try JSONEncoder().encode([String(year): ["0101": expected]])
                try data.write(to: url, options: .atomic)
                service.reloadCached()
                XCTAssertEqual(FestivalStore().tiaoxiu(date: date), expected)
            }
        }
    }
}
