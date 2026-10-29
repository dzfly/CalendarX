//
//  MenubarPopover.swift
//  CalendarX
//
//  Created by zm on 2022/1/4.
//

import AppKit
import SwiftUI

@MainActor
class MenubarPopover: NSPopover {

    private let privateKey = "shouldHideAnchor"

    private var eventMonitor: Any?

    private let router: Router

    init<Content>(_ router: Router, rootScreen: Content) where Content: View {

        self.router = router
        super.init()
        contentViewController = NSHostingController(rootView: rootScreen)
        contentSize = .init(width: .mainWidth, height: .mainHeight)
        behavior = .applicationDefined
        shouldHideAnchor()
        animates = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(_ sender: Any?) {
        guard let button = sender as? NSStatusBarButton else { return }
        guard let event = NSApp.currentEvent else { return }
        show(button, screen: event.isRightClicked ? .settings : .calendar)
    }

    func show(_ button: NSStatusBarButton, screen: Router.Screen) {
        router.set(screen)
        if case .calendar = screen {} else {
            contentSize.height = .mainHeight
        }
        show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        revealSystemGlass()
        contentViewController?.view.window?.becomeKey()
        startEventMonitor()
    }

    override func close() {
        super.close()
        contentViewController?.view.window?.resignKey()
        stopEventMonitor()
    }

}

extension MenubarPopover {

    func startEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            guard isShown else { return }
            close()
        }
    }

    func stopEventMonitor() {
        guard eventMonitor != nil else { return }
        NSEvent.removeMonitor(eventMonitor!)
        eventMonitor = .none
    }
}

extension MenubarPopover {

    private func revealSystemGlass() {
        guard #available(macOS 26.0, *) else { return }
        guard let hosting = contentViewController?.view else { return }
        let windowContent = hosting.window?.contentView
        var view: NSView? = hosting
        while let current = view, current !== windowContent {
            current.wantsLayer = true
            current.layer?.backgroundColor = NSColor.clear.cgColor
            view = current.superview
        }
    }

    private func shouldHideAnchor() {
        if value(forKey: privateKey) is String {
            return
        }
        setValue(true, forKey: privateKey)
    }

    override func value(forUndefinedKey key: String) -> Any? {
        key == privateKey ? key : .none
    }

}

@MainActor
final class PopoverResizer {
    var apply: ((CGFloat) -> Void)?

    func setHeight(_ height: CGFloat) {
        apply?(height)
    }
}

private struct PopoverResizerKey: EnvironmentKey {
    static let defaultValue: PopoverResizer? = nil
}

extension EnvironmentValues {
    var popoverResizer: PopoverResizer? {
        get { self[PopoverResizerKey.self] }
        set { self[PopoverResizerKey.self] = newValue }
    }
}
