//
//  MainScreen.swift
//  CalendarX
//
//  Created by zm on 2022/1/26.
//

import Algorithms
import AppKit
import CalendarXLib
import SwiftUI

func calendarPopoverHeight(date: Date, firstWeekday: Int) -> CGFloat {
    var calendar = Calendar.gregorian
    calendar.firstWeekday = firstWeekday
    let count = calendar.generateDates(for: date).count
    let weeks = max(count / Solar.daysInWeek, 1)
    let spacing: CGFloat = count > Solar.minDates ? 0.5 : 8.5
    let grid = 30 + CGFloat(weeks) * 40 + CGFloat(weeks) * spacing
    return 36 + 12 + grid + 16 + 20
}

struct MainScreen: View {

    @EnvironmentObject
    private var appStore: AppStore

    @EnvironmentObject
    private var calendarStore: CalendarStore

    @EnvironmentObject
    private var router: Router

    @ObservedObject
    var viewModel: MainViewModel

    private var calendar: Calendar {
        viewModel.calendar.firstWeekday = calendarStore.weekday.rawValue
        return viewModel.calendar
    }

    private let eventStore = AppEventStore()

    private let festivalStore = FestivalStore()

    var body: some View {

        CalendarView(
            date: viewModel.date,
            calendar: calendar,
            eventStore: eventStore,
            interval: viewModel.interval,
            showWeekNumbers: calendarStore.showWeekNumbers,
            title: title,
            subtitle: subtitle,
            leading: leading,
            element: element
        )
        .padding(.top, 16)
        .padding(.bottom, 20)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing),
            removal: .move(edge: .leading)
        ))
        .onAppear {
            viewModel.date = Date()
        }
    }

    private func title() -> some View {
        HStack(spacing: 0) {
            MonthYearPicker(date: $viewModel.date, tint: appStore.accentColor)
                .focusDisabled()

            Spacer(minLength: 24)

            if calendarStore.keyboardShortcut {

                KeyboardShortcutButton(key: .leftArrow, action: viewModel.lastMonth)
                    .frame(width: 0, height: 0)
                KeyboardShortcutButton(key: .space, action: viewModel.resetToToday)
                    .frame(width: 0, height: 0)
                KeyboardShortcutButton(key: .rightArrow, action: viewModel.nextMonth)
                    .frame(width: 0, height: 0)
                KeyboardShortcutButton(key: .upArrow, action: viewModel.lastYear)
                    .frame(width: 0, height: 0)
                KeyboardShortcutButton(key: .downArrow, action: viewModel.nextYear)
                    .frame(width: 0, height: 0)

            }

            HStack(spacing: 8) {
                if #available(macOS 12.0, *) {
                    ScacleImageButton(image: .leftArrow, action: viewModel.lastMonth)
                        .frame(width: 32)
                        .background {
                            Color.red.opacity(0.000000001)
                            .frame(width: 60, height: 40)
                        }
                        .onTapGesture {
                            viewModel.lastMonth()
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                } else {
                    ScacleImageButton(image: .leftArrow, action: viewModel.lastMonth)
                        .frame(width: 30)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
                ScacleImageButton(image: .circle, action: viewModel.resetToToday)
                    .frame(width: 30)
                if #available(macOS 12.0, *) {
                    ScacleImageButton(image: .rightArrow, action: viewModel.nextMonth)
                        .frame(width: 32)
                        .background {
                            Color.red.opacity(0.000000001)
                            .frame(width: 60, height: 40)
                        }
                        .onTapGesture {
                            viewModel.nextMonth()
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    ScacleImageButton(image: .rightArrow, action: viewModel.nextMonth)
                        .frame(width: 30)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
        }
    }

    private func subtitle(_ dates: [AppDate]) -> some View {
        ForEach(dates, id: \.self) {
            Text($0.shortWeekday(locale: appStore.locale))
                .appForeground($0.inWeekend ? .appSecondary : .appPrimary)
                .sideLength(30)
        }
    }

    private func leading(_ dates: [AppDate], spacing: CGFloat) -> some View {
        VStack(spacing: spacing) {
            Text("#")
                .frame(width: 15, height: 30)
                .appForeground(.accentColor)
            ForEach(dates, id: \.self) {
                Text("\(calendar.component(.weekOfYear, from: $0))")
                    .font(.system(size: 7, weight: .bold))
                    .frame(width: 15, height: 40)
                    .appForeground(.accentColor)
            }
        }
    }

    @ViewBuilder
    private func element(_ appDate: AppDate, events: [AppEvent], month: Date) -> some View {

        let tiaoxiu = festivalStore.tiaoxiu(date: appDate)
        let tiaoxiuColor: Color = tiaoxiu.isXiu ? .offBackground : .workBackground
        let subtitle = festivalStore.display(date: appDate)
        let showHolidays = !tiaoxiu.isOrdinary && calendarStore.showHolidays
        let showEvents = events.isNotEmpty && calendarStore.showEvents
        let showLunar = calendarStore.showLunar
        let defaultColor: Color = appDate.inWeekend ? .appSecondary.opacity(0.75) : .appPrimary
        let inSameMonth = month.inSameMonth(as: appDate)

        ScacleButton {
            let festivals = festivalStore.all(date: appDate)
            router.push(.date(appDate, events, festivals))
        } label: {
            ZStack {
                if appDate.inToday {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.accentColor, lineWidth: 1)
                }

                if showHolidays {
                    tiaoxiuColor.clipShape(.rect(cornerRadius: 4))
                    Text(tiaoxiu.description)
                        .font(.system(size: 8, weight: .bold))
                        .padding(.leading, 3)
                        .padding(.top, 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .appForeground(tiaoxiu.isXiu ? .accentColor : .appSecondary)
                }

                if showEvents {
                    Circle()
                        .size(width: 5, height: 5)
                        .appForeground(.accentColor)
                        .offset(x: 32, y: 3)
                }

                VStack {
                    Text(appDate.title)
                        .font(.title3.monospacedDigit().weight(.medium))
                        .appForeground(showHolidays ? tiaoxiu.isXiu ? .accentColor : defaultColor : defaultColor)
                    if showLunar {
                        Text(subtitle)
                            .font(.caption2.weight(.medium))
                            .appForeground(showHolidays ? tiaoxiu.isXiu ? .accentColor : .appSecondary : .appSecondary)
                    }
                }
            }
            .opacity(inSameMonth ? 1 : 0.72)
            .sideLength(40)
        }
    }
}

struct MonthYearPicker: View {

    @Environment(\.locale)
    private var locale

    @Binding
    var date: Date

    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            AppMenuButton(
                titles: monthItems.map(\.title),
                selection: monthItems.firstIndex { $0.tag == date.month } ?? 0,
                tint: tint
            ) { index in
                guard monthItems.indices.contains(index) else { return }
                date.month = monthItems[index].tag
            }
            .fixedSize()
            AppMenuButton(
                titles: yearItems.map(\.title),
                selection: yearItems.firstIndex { $0.tag == date.year } ?? 0,
                tint: tint
            ) { index in
                guard yearItems.indices.contains(index) else { return }
                date.year = yearItems[index].tag
            }
            .fixedSize()
        }
    }

    private var monthItems: [(tag: Int, title: String)] {
        (Solar.minMonth...Solar.maxMonth).map { (tag: $0, title: monthTitle($0)) }
    }

    private var yearItems: [(tag: Int, title: String)] {
        (Solar.minYear...Solar.maxYear).map { (tag: $0, title: String($0)) }
    }

    private func monthTitle(_ month: Int) -> String {
        var calendar = Calendar.gregorian
        calendar.locale = locale
        let symbols = calendar.shortMonthSymbols
        let index = month - 1
        guard symbols.indices.contains(index) else { return String(month) }
        return symbols[index]
    }
}

struct CalendarView<Title: View, Subtitle: View, Leading: View, Element: View>: View {

    private let date: AppDate, calendar: Calendar, eventStore: AppEventStore, interval: TimeInterval

    private let showWeekNumbers: Bool

    private let title: () -> Title
    private let subtitle: ([AppDate]) -> Subtitle
    private let leading: ([AppDate], CGFloat) -> Leading
    private let element: (AppDate, [AppEvent], Date) -> Element

    init(
        date: AppDate,
        calendar: Calendar,
        eventStore: AppEventStore,
        interval: TimeInterval,
        showWeekNumbers: Bool,
        @ViewBuilder title: @escaping () -> Title,
        @ViewBuilder subtitle: @escaping ([AppDate]) -> Subtitle,
        @ViewBuilder leading: @escaping ([AppDate], CGFloat) -> Leading,
        @ViewBuilder element: @escaping (AppDate, [AppEvent], Date) -> Element
    ) {
        self.date = date
        self.calendar = calendar
        self.eventStore = eventStore
        self.interval = interval

        self.showWeekNumbers = showWeekNumbers
        self.title = title
        self.subtitle = subtitle
        self.leading = leading
        self.element = element
    }

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            title()
                .padding(.horizontal, 24)

            monthGrid(for: date)
        }
        .transaction { transaction in
            if reduceMotion { transaction.animation = nil }
        }
    }

    private func monthGrid(for month: Date) -> some View {
        let dates = calendar.generateDates(for: month)
        let spacing = dates.count > Solar.minDates ? 0.5 : 8.5
        let eventsMap = eventStore.generateEventsMap(dates)
        let leadingDates = dates.striding(by: Solar.daysInWeek).map(\.self)
        let subtitleDates = dates.prefix(Solar.daysInWeek).map(\.self)
        let columns = Array(
            repeating: GridItem(.fixed(30), spacing: showWeekNumbers ? 11.5 : 15.5),
            count: Solar.daysInWeek
        )

        return HStack(alignment: .top) {
            if showWeekNumbers {
                leading(leadingDates, spacing)
            }
            LazyVGrid(columns: columns, spacing: spacing) {
                subtitle(subtitleDates)
                ForEach(dates, id: \.eventsKey) { appDate in
                    element(appDate, eventsMap[appDate.eventsKey] ?? [], month)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 24)
    }
}

extension CalendarView: @preconcurrency Equatable {

    static func == (lhs: CalendarView<Title, Subtitle, Leading, Element>, rhs: CalendarView<Title, Subtitle, Leading, Element>)
        -> Bool
    {
        lhs.date.year == rhs.date.year
            && lhs.date.month == rhs.date.month
            && lhs.date.day == rhs.date.day
            && lhs.interval == rhs.interval
    }
}
