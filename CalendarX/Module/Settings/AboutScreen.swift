//
//  AboutScreen.swift
//  CalendarX
//
//  Created by zm on 2023/3/1.
//

import CalendarXLib
import SwiftUI

struct AboutScreen: View {

    @EnvironmentObject
    private var router: Router
    

    var body: some View {
        VStack {
            TitleView {
                Text("小日历")
            } leftItems: {
                ScacleImageButton(image: .backward) {
                    router.pop()
                }
            } rightItems: {
                ScacleImageButton(image: .feedback) {
                    router.open(AppLink.gitHub)
                }
            }

            Image(nsImage: NSApp.applicationIconImage)

            Text(Bundle.appName)
                .font(.title)
                .bold()

            HStack {
                Text(L10n.Updater.version)
                Text(Bundle.appVersionName)
            }
            .appForeground(.appSecondary)

            Spacer()
        }
        .frame(height: .mainHeight, alignment: .top)
        .padding()
    }
}
