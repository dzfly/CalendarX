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

    public static let shared = HolidayService()

    private let cacheFileName = "holiday_tiaoxiu.json"
    private let lastFetchKey = "\(Bundle.appName).holiday.lastFetchDate"

    private init() {}

    public func refreshIfNeeded() async {
        guard shouldRefresh() else { return }

        let currentYear = Calendar.current.component(.year, from: Date())
        var merged = loadCached()

        for year in [currentYear, currentYear + 1] {
            if let data = await fetchRemote(year: year) {
                let converted = convert(data)
                for (key, value) in converted {
                    merged[key] = value
                }
            }
        }

        saveToCacheFile(merged)
        UserDefaults.group?.set(Date(), forKey: lastFetchKey)
        FestivalStore.Solar.tiaoxiu = merged
    }

    public func loadCached() -> [String: [String: Tiaoxiu]] {
        if let cached = readCacheFile() {
            return cached
        }
        return Bundle.module.jsonModel(resource: "festival_solar_tiaoxiu") ?? [:]
    }

    // MARK: - Private

    private func shouldRefresh() -> Bool {
        guard let last = UserDefaults.group?.object(forKey: lastFetchKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(last) > 86400
    }

    private func fetchRemote(year: Int) async -> HolidayResponse? {
        let urlString = "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/\(year).json"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(HolidayResponse.self, from: data)
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

    private var cacheFileURL: URL? {
        guard let identifier = Bundle.main.bundleIdentifier ?? Bundle.module.bundleIdentifier else {
            return nil
        }
        let groupID = "group.\(identifier.components(separatedBy: ".").prefix(3).joined(separator: "."))"
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            // Fallback: use app support directory
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            return appSupport?.appendingPathComponent(cacheFileName)
        }
        return containerURL.appendingPathComponent(cacheFileName)
    }

    private func readCacheFile() -> [String: [String: Tiaoxiu]]? {
        guard let url = cacheFileURL,
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode([String: [String: Tiaoxiu]].self, from: data)
    }

    private func saveToCacheFile(_ tiaoxiu: [String: [String: Tiaoxiu]]) {
        guard let url = cacheFileURL,
              let data = try? JSONEncoder().encode(tiaoxiu) else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }
}
