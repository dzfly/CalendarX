//
//  CalendarXApp.swift
//  CalendarX
//
//  Created by zm on 2021/12/1.
//

import CalendarXLib
import SwiftUI
import WidgetKit


extension EnvironmentValues {
    @Entry var authorizer = Authorizer()
}

@main
struct CalendarXApp: App {
    @NSApplicationDelegateAdaptor(CalendarXDelegate.self)
    private var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class CalendarXDelegate: NSObject & NSApplicationDelegate {
    
    private var menubarController: MenubarController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSRunningApplication
            .runningApplications(withBundleIdentifier: Bundle.identifier)
            .filter(\.isFinishedLaunching)
            .forEach { $0.terminate() }
    }

    // Use a synchronous delegate method (AppKit won't call the async variant).
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[CalendarX] applicationDidFinishLaunching called")
        Task { @MainActor in
            print("[CalendarX] bootstrap begin")
            let appStore = AppStore()
            let menubarStore = MenubarStore()
            let calendarStore = CalendarStore()
            let router = Router()
            let dialog = Dialog()
            let authorizer = Authorizer()
            let updater = Updater(appStore: appStore)
            
            await bootstrap(calendarStore: calendarStore, authorizer: authorizer, updater: updater)
            print("[CalendarX] bootstrap end")
            
            let rootScreen = RootScreen(updater: updater)
                .environment(\.authorizer, authorizer)
                .environmentObject(appStore)
                .environmentObject(menubarStore)
                .environmentObject(calendarStore)
                .environmentObject(router)
                .environmentObject(dialog)
            let popover = MenubarPopover(router, rootScreen: rootScreen)
            
            print("[CalendarX] creating MenubarController")
            menubarController = MenubarController(appStore: appStore, menubarStore: menubarStore, popover: popover, updater: updater)
            print("[CalendarX] menubarController assigned")
        }
    }
}


extension CalendarXDelegate {
    
    private func bootstrap(calendarStore: CalendarStore, authorizer: Authorizer, updater: Updater) async {
        await resolveEventsAuthorization(authorizer: authorizer, calendarStore: calendarStore)
        resolveNotificationsAuthorization(authorizer: authorizer, updater: updater)
        Task { await HolidayService.shared.refreshIfNeeded() }
    }
    
    private func resolveEventsAuthorization(authorizer: Authorizer, calendarStore: CalendarStore) async {
        WidgetCenter.shared.reloadAllTimelines()
        if authorizer.allowFullAccessToEvents { return }
        if calendarStore.showEvents { calendarStore.showEvents.toggle() }
    }
    
    private func resolveNotificationsAuthorization(authorizer: Authorizer, updater: Updater) {
        Task {
            if await authorizer.allowNotifications { return }
            if updater.automaticallyChecksForUpdates {
                updater.automaticallyChecksForUpdates.toggle()
            }
        }
    }
}
