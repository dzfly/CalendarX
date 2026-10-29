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
    private var requestCount = 0

    func configure(_ responses: [Int: MockHolidayResponse]) {
        lock.withLock {
            self.responses = responses
            requestCount = 0
        }
    }

    func response(for year: Int) -> MockHolidayResponse? {
        lock.withLock {
            requestCount += 1
            return responses[year]
        }
    }

    var count: Int { lock.withLock { requestCount } }
}

private final class HolidayURLProtocol: URLProtocol, @unchecked Sendable {
    static let state = HolidayRequestState()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let year = Int(url.deletingPathExtension().lastPathComponent),
              let mock = Self.state.response(for: year) else {
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

    private func withService(
        responses: [Int: MockHolidayResponse] = [:],
        writable: Bool = true,
        test: (HolidayService, UserDefaults, URL) async throws -> Void
    ) async throws {
        HolidayURLProtocol.state.configure(responses)
        let suite = "CalendarX.HolidayTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = writable ? directory.appendingPathComponent("holiday.json") : directory
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HolidayURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let service = HolidayService(session: session, defaults: defaults, cacheFileURL: url)
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
        try await withService { service, defaults, _ in
            defaults.set(Date(), forKey: lastFetchKey)
            let refreshed = await service.refreshIfNeeded()
            XCTAssertFalse(refreshed)
            XCTAssertEqual(HolidayURLProtocol.state.count, 0)
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
