//
//  SettingsScreen.swift
//  CalendarX
//
//  Created by zm on 2022/1/26.
//

import CalendarXLib
import SwiftUI

@MainActor
struct SettingsScreen: View {

    @EnvironmentObject
    private var router: Router

    @EnvironmentObject
    private var dialog: Dialog

    @EnvironmentObject
    private var appStore: AppStore

    @EnvironmentObject
    private var menubarStore: MenubarStore

    var body: some View {

        let spacing: CGFloat = if #available(macOS 13.0, *) { 10 } else { 16 }

        VStack(spacing: spacing) {
            TitleView {
                Text(L10n.Settings.title).onTapGesture {
                    router.pop()
                }
            } leftItems: {
                EmptyView()
            } rightItems: {
                ScacleImageButton(image: .quit) {
                    dialog.popup(.exit) {
                        router.exit()
                    }
                }
                .focusDisabled()
            }

            Section {
                appearanceRow
                calendarRow
                languageRow
                memubarRow
                launchRow
                updateRow
                aboutRow
            }
        }
        .frame(height: .mainHeight, alignment: .top)
        .padding()

    }

}

extension SettingsScreen {
    var appearanceRow: some View {
        SettingsPickerRow(
            title: L10n.Settings.appearance,
            items: Theme.allCases,
            selection: $appStore.theme,
            itemLabel: { Text($0.title) }
        )
    }

    var calendarRow: some View {
        SettingsRow(title: L10n.Settings.calendar, detail: {}) {
            router.push(.calendarSettings)
        }
    }

    var languageRow: some View {
        SettingsPickerRow(
            title: L10n.Settings.language,
            items: Language.allCases,
            selection: $appStore.language,
            itemLabel: { Text(languageTitle($0)) }
        )
    }

    var memubarRow: some View {
        SettingsRow(
            title: L10n.Settings.menubarStyle,
            detail: { Text(menubarStore.style.title) }
        ) {
            router.push(.menubarSettings)
        }
    }

    @ViewBuilder
    var launchRow: some View {
        if #available(macOS 13.0, *) {
            Launcher.Toggle { Text(L10n.Settings.launchAtLogin).font(.title3) }
                .checkboxStyle()
        } else {
            EmptyView()
        }
    }

    var updateRow: some View {

        SettingsRow(title: L10n.Settings.update, detail: {}) {
            router.push(.update)
        }

    }

//    var recommendRow: some View {
//        SettingsRow(title: L10n.Settings.recommendations, detail: {}) {
//            router.push(.recommendations)
//        }
//    }

    var aboutRow: some View {
        SettingsRow(title: L10n.Settings.about, detail: {}) {
            router.push(.about)
        }
    }

    func languageTitle(_ language: Language) -> String {
        switch language {
        case .zh_CN: "简体中文"
        case .en_US: "English"
        case .system:
            Bundle.main.localizedString(forKey: "theme.system", value: "跟随系统", table: nil)
        }
    }
}

struct SettingsRow<Content: View>: View {
    let title: LocalizedStringKey, titleFont: Font, showArrow: Bool

    @ViewBuilder
    let detail: () -> Content

    let action: VoidClosure

    init(
        title: LocalizedStringKey,
        titleFont: Font = .title3,
        showArrow: Bool = true,
        @ViewBuilder detail: @escaping () -> Content,
        action: @escaping VoidClosure
    ) {
        self.title = title
        self.titleFont = titleFont
        self.showArrow = showArrow
        self.detail = detail
        self.action = action
    }

    var body: some View {
        HStack {
            Text(title)
                .font(titleFont)
            Spacer()

            detail()
                .appForeground(.appSecondary)
            if showArrow {
                Image.rightArrow
                    .font(titleFont)
                    .appForeground(.appSecondary)
            }

        }
        .contentShape(.rect)
        .onTapGesture(perform: action)
    }
}

struct SettingsPickerRow<Item: Hashable, Label: View>: View {
    let title: LocalizedStringKey, items: [Item]

    @Binding
    var selection: Item

    @ViewBuilder
    let itemLabel: (Item) -> Label

    init(
        title: LocalizedStringKey,
        items: [Item],
        selection: Binding<Item>,
        @ViewBuilder itemLabel: @escaping (Item) -> Label
    ) {
        self.title = title
        self.items = items
        self._selection = selection
        self.itemLabel = itemLabel
    }

    var body: some View {
        HStack {
            Text(title).font(.title3)
            Spacer()
            Picker(selection: $selection) {
                ForEach(items, id: \.self) { item in
                    itemLabel(item).tag(item)
                }
            } label: {
                Text(title)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
        }
    }
}
