//
//  AppearanceScreen.swift
//  CalendarX
//
//  Created by zm on 2023/2/17.
//

import CalendarXLib
import SwiftUI


struct AppearanceScreen: View {

    @EnvironmentObject
    private var router: Router

    @EnvironmentObject
    private var appStore: AppStore

    var body: some View {
        VStack(spacing: 10) {
            TitleView {
                Text(L10n.Settings.appearance)
            } leftItems: {
                ScacleImageButton(image: .backward) {
                    router.pop()
                }
            } rightItems: {
                EmptyView()
            }

            SettingsPickerRow(
                title: L10n.Settings.appearance,
                items: Theme.allCases,
                selection: $appStore.theme,
                itemLabel: { Text($0.title) }
            )
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding()
    }
}
