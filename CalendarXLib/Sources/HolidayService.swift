//
//  HolidayService.swift
//  CalendarXLib
//
//  Created by zm on 2025/06/17.
//

import Foundation

private struct HolidayResponse: Decodable {
    let year: Int
    let days: [Day]

    struct Day: Decodable {
        let name: String
        let date: String
        let isOffDay: Bool
    }
}

@MainActor
public final class HolidayService {

    public static let shared = HolidayService(
        session: .shared,
        defaults: .standard,
        cacheFileURL: defaultCacheFileURL,
        fallbackCacheFileURL: legacyCacheFileURL
    )

    public nonisolated static let didUpdate = Notification.Name("holidayDataDidUpdate")

    private static let cacheFileName = "holiday_tiaoxiu.json"
    private let lastFetchKey = "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "CalendarX").holiday.lastFetchDate"
    private let session: URLSession
    private let defaults: UserDefaults?
    private let cacheFileURL: URL?
    private let fallbackCacheFileURL: URL?

    init(session: URLSession, defaults: UserDefaults?, cacheFileURL: URL?, fallbackCacheFileURL: URL? = nil) {
        self.session = session
        self.defaults = defaults
        self.cacheFileURL = cacheFileURL
        self.fallbackCacheFileURL = fallbackCacheFileURL
    }

    public func refreshIfNeeded() async -> Bool {
        guard shouldRefresh() else { return false }

        let currentYear = Calendar.current.component(.year, from: Date())
        var merged = loadCached()
        var didFetch = false

        for year in [currentYear, currentYear + 1] {
            if let data = await fetchRemote(year: year),
               let days = convert(data)[String(year)], !days.isEmpty {
                merged[String(year)] = days
                didFetch = true
            }
        }

        guard didFetch, saveToCacheFile(merged) else { return false }
        defaults?.set(Date(), forKey: lastFetchKey)
        FestivalStore.Solar.tiaoxiu = merged
        NotificationCenter.default.post(name: Self.didUpdate, object: nil)
        return true
    }

    public func reloadCached() {
        FestivalStore.Solar.tiaoxiu = loadCached()
    }

    public func loadCached() -> [String: [String: Tiaoxiu]] {
        if let cached = readCacheFile() {
            return cached
        }
        return Bundle.module.jsonModel(resource: "festival_solar_tiaoxiu") ?? [:]
    }

    // MARK: - Private

    private func shouldRefresh() -> Bool {
        guard let last = defaults?.object(forKey: lastFetchKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(last) > 86400
    }

    private func fetchRemote(year: Int) async -> HolidayResponse? {
        let urlString = "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/\(year).json"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await session.data(from: url)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else { return nil }
            let holiday = try JSONDecoder().decode(HolidayResponse.self, from: data)
            return holiday.year == year ? holiday : nil
        } catch {
            return nil
        }
    }

    private func convert(_ response: HolidayResponse) -> [String: [String: Tiaoxiu]] {
        let yearKey = String(response.year)
        var dayMap: [String: Tiaoxiu] = [:]

        for day in response.days {
            // date format: "2025-01-01" → "0101"
            let parts = day.date.split(separator: "-")
            guard parts.count == 3 else { continue }
            let mdKey = "\(parts[1])\(parts[2])"
            dayMap[mdKey] = day.isOffDay ? .xiu : .ban
        }

        return [yearKey: dayMap]
    }

    // MARK: - File Cache

    private static var legacyCacheFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(cacheFileName)
    }

    private static var defaultCacheFileURL: URL? {
        guard let groupID = Bundle.main.object(forInfoDictionaryKey: "HolidayAppGroupIdentifier") as? String,
              let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            return legacyCacheFileURL
        }
        return containerURL.appendingPathComponent(cacheFileName)
    }

    private func readCacheFile() -> [String: [String: Tiaoxiu]]? {
        for url in [cacheFileURL, fallbackCacheFileURL].compactMap({ $0 }) {
            if let data = try? Data(contentsOf: url),
               let cached = try? JSONDecoder().decode([String: [String: Tiaoxiu]].self, from: data) {
                if url != cacheFileURL { _ = saveToCacheFile(cached) }
                return cached
            }
        }
        return nil
    }

    private func saveToCacheFile(_ tiaoxiu: [String: [String: Tiaoxiu]]) -> Bool {
        guard let url = cacheFileURL,
              let data = try? JSONEncoder().encode(tiaoxiu) else {
            return false
        }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
