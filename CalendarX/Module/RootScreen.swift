import AppKit
import CalendarXLib
import SwiftUI

struct RootScreen: View {

    @EnvironmentObject
    private var router: Router

    @EnvironmentObject
    private var dialog: Dialog

    @EnvironmentObject
    private var appStore: AppStore

    @EnvironmentObject
    private var calendarStore: CalendarStore
    @EnvironmentObject
    private var menubarStore: MenubarStore

    @Environment(\.popoverResizer)
    private var popoverResizer

    private let updater: Updater

    private let mainVM = MainViewModel()

    init(updater: Updater) {
        self.updater = updater
    }

    var body: some View {
        ZStack {

            keyboardShortcuts
            background
            baseScreen
            topScreen
            dialogScreen

        }
        .frame(width: .mainWidth)
        .appForeground(.appPrimary)
        .preferredLocale(appStore.locale)
        .envTint(appStore.accentColor)
        .envColorScheme(appStore.colorScheme)
        .onChange(of: appStore.locale, notification: NSLocale.currentLocaleDidChangeNotification)
        .onAppear { syncPopoverHeight() }
        .onReceive(router.$path.receive(on: RunLoop.main)) { _ in syncPopoverHeight() }
        .onReceive(mainVM.$date.receive(on: RunLoop.main)) { _ in syncPopoverHeight() }
    }

    private func syncPopoverHeight() {
        let height: CGFloat = if case .calendar = router.root, router.path.count == 1 {
            calendarPopoverHeight(date: mainVM.date, firstWeekday: calendarStore.weekday.rawValue)
        } else if router.path.isEmpty {
            calendarPopoverHeight(date: mainVM.date, firstWeekday: calendarStore.weekday.rawValue)
        } else {
            .mainHeight
        }
        popoverResizer?.setHeight(height)
    }

}

extension RootScreen {

    @ViewBuilder
    private var keyboardShortcuts: some View {
        if calendarStore.keyboardShortcut {
            KeyboardShortcutButton(key: .escape) {
                dialog.isPresented ? dialog.dismiss() : router.popOrNotify(.popoverWillCloseManually)
            }
        }
    }

    private var panelFill: Color {
        if #available(macOS 26, *) {
            appStore.backgroundColor.opacity(0.6)
        } else {
            appStore.backgroundColor
        }
    }

    @ViewBuilder
    private var background: some View {
        panelFill
            .padding(.top, -15)
            .background {
                if #available(macOS 26, *) {
                    PopoverAppearance(colorScheme: appStore.colorScheme)
                }
            }
    }

    @ViewBuilder
    private var baseScreen: some View { screen(from: router.root) }

    @ViewBuilder
    private var topScreen: some View {
        screen(from: router.top)
            .fullScreenCover(appStore.backgroundColor.opacity(0.94))
    }

    @ViewBuilder
    private func screen(from path: Router.Screen) -> some View {
        switch path {
        case .calendar: MainScreen(viewModel: mainVM)
        case .settings: SettingsScreen()
        case .date(let appDate, let events, let festivals): DateScreen(appDate: appDate, events: events, festivals: festivals)
        case .menubarSettings: MenubarScreen(menubarStore: menubarStore)
        case .appearanceSettings: AppearanceScreen()
        case .calendarSettings: CalendarScreen()
        case .update: UpdateScreen(updater: updater)
        case .about: AboutScreen()
        default: EmptyView()
        }
    }

}

extension RootScreen {
    @ViewBuilder
    private var dialogScreen: some View {

        ZStack(alignment: .bottom) {
            Color.black
                .opacity(dialog.isPresented ? 0.5 : 0)
                .onTapGesture(perform: dialog.dismiss)

            if dialog.isPresented {
                VStack {
                    dialog.image
                        .font(.largeTitle)
                        .appForeground(.accentColor)

                    if let message = dialog.message {
                        Text(message)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 5)
                    }

                    if let yesTitle = dialog.yesTitle {
                        ScacleCapsuleButton(
                            title: yesTitle,
                            foregroundColor: .appWhite,
                            backgroundColor: .accentColor
                        ) {
                            dialog.handler?()
                            dialog.dismiss()
                        }
                    }

                    if let noTitle = dialog.noTitle {
                        ScacleCapsuleButton(
                            title: noTitle,
                            foregroundColor: .appWhite,
                            backgroundColor: .disable,
                            action: dialog.dismiss
                        )
                    }
                }
                .padding()
                .background(Color.card)
                .clipShape(.rect(cornerRadius: 5))
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding()
            }
        }
        .zIndex(1)
    }
}

private struct PopoverAppearance: NSViewRepresentable {
    var colorScheme: ColorScheme?

    func makeNSView(context: Context) -> PopoverAppearanceView {
        let view = PopoverAppearanceView()
        view.colorScheme = colorScheme
        return view
    }

    func updateNSView(_ view: PopoverAppearanceView, context: Context) {
        view.colorScheme = colorScheme
        view.apply()
    }
}

private final class PopoverAppearanceView: NSView {
    var colorScheme: ColorScheme?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        apply()
    }

    func apply() {
        guard let window else { return }
        let name: NSAppearance.Name = switch colorScheme {
        case .dark: .darkAqua
        case .light: .aqua
        default:
            NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .darkAqua : .aqua
        }
        window.appearance = NSAppearance(named: name)
    }
}
