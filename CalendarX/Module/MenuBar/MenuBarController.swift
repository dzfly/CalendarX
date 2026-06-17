//
//  MenubarController.swift
//  CalendarX
//
//  Created by zm on 2022/1/4.
//

import AppKit
import CalendarXLib
import Combine
import WidgetKit

@MainActor
class MenubarController {

    private let appStore: AppStore

    private let menubarStore: MenubarStore

    private let popover: MenubarPopover

    private let schedule: MenubarSchedule

    private let menubarItem: NSStatusItem

    private let menubarButton: NSStatusBarButton?

    private var cancellables: Set<AnyCancellable> = []

    private let emptyAttributedString = NSAttributedString()
    
    private var updater: Updater?

    init(appStore: AppStore, menubarStore: MenubarStore, popover: MenubarPopover, updater: Updater? = nil) {
        self.appStore = appStore
        self.menubarStore = menubarStore
        self.popover = popover
        self.updater = updater
        self.schedule = MenubarSchedule(menubarStore: menubarStore)
        // Use NSStatusBar.system to create a status item (NSStatusItem has no `system` member).
        self.menubarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.menubarButton = menubarItem.button

        setupMenubarButton()
        setupMenubarSchedule()
        setupMenubarObservers()
        setupContextMenu()
        print("[CalendarX] MenubarController initialized")
     }

}

extension MenubarController {

    private func setupMenubarSchedule() {
        schedule.action = { [weak self] in
            guard let self = self else { return }
            menubarButton?.image = menubarButtonImage
            menubarButton?.attributedTitle = menubarButtonTitle
        }
        schedule.action?()
        schedule.update()
    }

    private func setupMenubarButton() {
        menubarButton?.imagePosition = .imageOverlaps
        menubarButton?.target = self
        menubarButton?.action = #selector(togglePopover)
        menubarButton?.sendAction(on: [.leftMouseDown, .rightMouseDown])
    }

    private var menubarButtonImage: NSImage? {
        menubarStore.style != .icon
            ? .none
            : menubarStore.iconType.nsImage(locale: appStore.locale)
    }

    private var menubarButtonTitle: NSAttributedString {
        menubarStore.style != .date
            ? emptyAttributedString
            : .init(
                string: menubarStore.dateItemTitle(locale: appStore.locale),
                attributes: [.font: NSFont.statusItem]
            )
    }
}

extension MenubarController {

    private func setupMenubarObservers() {

        NotificationCenter.default
            .publisher(for: .popoverWillCloseManually)
            .sink { [weak self] _ in
                guard let self = self else { return }
                popover.close()
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .titleStyleDidChanged)
            .sink { [weak self] _ in
                guard let self = self else { return }
                schedule.action?()
                schedule.update()
            }
            .store(in: &cancellables)

        if #available(macOS 12.0, *) {
            Task { [weak self] in
                for await _ in NotificationCenter.default
                    .notifications(named: .NSCalendarDayChanged)
                    .compactMap({ _ in })
                {
                    guard let self = self else { return }
                    schedule.action?()
                }
            }
        } else {
            NotificationCenter.default
                .publisher(for: .NSCalendarDayChanged)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    schedule.action?()
                }
                .store(in: &cancellables)
        }

        NotificationCenter.default
            .publisher(for: NSLocale.currentLocaleDidChangeNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                schedule.action?()
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .NSSystemClockDidChange)
            .sink { [weak self] _ in
                guard let self = self else { return }
                schedule.action?()
                schedule.update()
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .EKEventStoreChanged)
            .sink { _ in
                WidgetCenter.shared.reloadAllTimelines()
            }
            .store(in: &cancellables)
    }
}

extension MenubarController {

    @objc private func togglePopover(_ sender: Any?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseDown {
            showContextMenu()
        } else {
            popover.isShown ? popover.close() : popover.show(sender)
        }
    }
    
    private func setupContextMenu() {
        // 右键菜单将通过 togglePopover 中的逻辑处理
    }
    
    private func showContextMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let checkUpdateItem = NSMenuItem(title: "检查更新", action: #selector(checkForUpdates), keyEquivalent: "")
        checkUpdateItem.target = self
        menu.addItem(checkUpdateItem)

        let aboutItem = NSMenuItem(title: "关于小日历", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出小日历", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        guard let button = menubarButton else { return }
        let origin = NSPoint(x: 0, y: button.bounds.height + 5)
        menu.popUp(positioning: nil, at: origin, in: button)
    }
    
    @objc private func checkForUpdates() {
        updater?.checkForUpdates()
    }
    
    @objc private func openSettings() {
        guard let button = menubarButton else { return }
        popover.show(button, screen: .settings)
    }

    @objc private func showAbout() {
        guard let button = menubarButton else { return }
        popover.show(button, screen: .about)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

}
