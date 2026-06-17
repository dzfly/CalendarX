//
//  Calendar+.swift
//  CalendarX
//
//  Created by zm on 2022/1/26.
//

import Foundation

extension Calendar {

    public func generateDates(for date: Date) -> [Date] {
        var dates: [Date] = []

        guard let range = range(of: .day, in: .month, for: date) else {
            return dates
        }
        // Range(1..<?) to 0..<?
        let startOfMonth = date.startOfMonth
        for value in Array(range).indices {
            let date = self.date(byAdding: .day, value: value, to: startOfMonth) ?? startOfMonth
            dates.append(date)
        }

        var weekday = startOfMonth.weekday
        weekday += weekday >= firstWeekday ? 0 : Solar.daysInWeek

        let lastCount = weekday - firstWeekday

        if lastCount > 0 {
            var lastDates: [Date] = []
            for value in (1...lastCount).reversed() {
                let date = self.date(byAdding: .day, value: -value, to: startOfMonth) ?? startOfMonth
                lastDates.append(date)
            }
            dates = lastDates + dates
        }

        let total = dates.count > Solar.minDates ? Solar.maxDates : Solar.minDates
        let nextCount = total - dates.count

        if nextCount > 0, let endOfMonth = dates.last {
            var nextDates: [Date] = []
            for value in 1...nextCount {
                let date = self.date(byAdding: .day, value: value, to: endOfMonth) ?? endOfMonth
                nextDates.append(date)
            }
            dates += nextDates
        }

        return dates
    }
}

extension AppEventStore {

   
    public func generateEventsMap(_ dates: [AppDate]) -> [String: [AppEvent]] {
        guard dates.isNotEmpty, allowFullAccessToEvents else { return [:] }
        let events = fetchEvents(with: dates.first!, end: dates.last!)
        return .init(grouping: events, by: \.eventsKey)
    }

    
    private var allowFullAccessToEvents: Bool {
        // authorizationStatus(for:) may require being called on the main thread on some macOS versions.
        // Call it on the main thread if we're currently off it to avoid crashes.
        let status: AppAuthorizationStatus = {
            if Thread.isMainThread {
                return Self.authorizationStatus(for: .event)
            } else {
                var s: AppAuthorizationStatus! = nil
                DispatchQueue.main.sync {
                    s = Self.authorizationStatus(for: .event)
                }
                return s
            }
        }()

        if #available(macOS 14.0, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }

    private func fetchEvents(with start: Date, end: Date) -> [AppEvent] {
        let calendars = calendars(for: .event).filter {
            $0.title != "中国大陆节假日"
        }
        let predicate = predicateForEvents(withStart: start.yesterday, end: end.tomorrow, calendars: calendars)

        return events(matching: predicate)
    }

}
