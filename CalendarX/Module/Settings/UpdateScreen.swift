//
//  UpdateScreen.swift
//  CalendarX
//
//  Created by zm on 2025/1/9.
//

import CalendarXLib
import SwiftUI

struct UpdateScreen: View {

    @EnvironmentObject
    private var router: Router

    @EnvironmentObject
    private var dialog: Dialog

    @Environment(\.authorizer)
    private var authorizer

    private let updater: Updater

    @State
    private var automaticallyChecksForUpdates: Bool {
        didSet {
            updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }

    @State
    private var includeBetaChannel: Bool {
        didSet {
            updater.includeBetaChannel = includeBetaChannel
        }
    }

    @State
    private var isCheckingForUpdates = false

    @State
    private var lastCheckDate: Date?

    init(updater: Updater) {
        self.automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        self.includeBetaChannel = updater.includeBetaChannel
        self.updater = updater
    }

    var body: some View {
        VStack(spacing: 20) {
            TitleView {
                Text(L10n.Settings.update)
            } leftItems: {
                ScacleImageButton(image: .backward) {
                    router.pop()
                }
            } rightItems: {
                EmptyView()
            }
            
            Section {
                checkRow
                betaRow
                Divider()
                appNameRow
                versionRow
                buildRow
                osRow
                if let lastCheck = lastCheckDate {
                    lastCheckRow(date: lastCheck)
                }
            }

            ScacleCapsuleButton(
                title: isCheckingForUpdates ? "检查中..." : L10n.Updater.checkForUpdates,
                foregroundColor: .appWhite,
                backgroundColor: isCheckingForUpdates ? .gray : .accentColor
            ) {
                checkForUpdates()
            }
            .disabled(isCheckingForUpdates || !updater.canCheckForUpdates)

        }
        .frame(height: .mainHeight, alignment: .top)
        .padding()
    }
    
    private func checkForUpdates() {
        isCheckingForUpdates = true
        lastCheckDate = Date()
        
        // 延迟一下以显示加载状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            updater.checkForUpdates()
            isCheckingForUpdates = false
        }
    }
}

extension UpdateScreen {

    @ViewBuilder
    private var checkRow: some View {
        let isOn = Binding {
            automaticallyChecksForUpdates
        } set: { value in
            Task {
                switch await authorizer.notificationsuStatus {
                case .denied:
                    dialog.popup(.notifications) {
                        router.preference(Privacy.notifications)
                    }
                case .notRequested:
                    automaticallyChecksForUpdates = await authorizer.requestNotificationsAuthorization()
                default:
                    automaticallyChecksForUpdates = value
                }
            }
        }

        Toggle(isOn: isOn) { Text(L10n.Updater.auto).font(.title3) }
            .checkboxStyle()
            .onAppear {
                Task {
                    if await authorizer.allowNotifications { return }
                    if automaticallyChecksForUpdates {
                        automaticallyChecksForUpdates.toggle()
                    }
                }
            }
    }

    private var betaRow: some View {
        Toggle(
            isOn: Binding(
                get: {
                    includeBetaChannel
                },
                set: {
                    includeBetaChannel = $0
                }
            )
        ) { Text(L10n.Updater.beta).font(.title3) }
        .checkboxStyle()
    }

    private var appNameRow: some View {
        SettingsRow(
            title: "应用名称",
            showArrow: false,
            detail: {
                Text("小日历")
            },
            action: {}
        )
    }

    private var versionRow: some View {
        SettingsRow(
            title: L10n.Updater.version,
            showArrow: false,
            detail: {
                Text(Bundle.appVersionName)
            },
            action: {}
        )
    }
    
    @ViewBuilder
    private var buildRow: some View {
        SettingsRow(
            title: L10n.Updater.build,
            showArrow: false,
            detail: {
                Text(Bundle.appBuild)
            },
            action: {}
        )
    }
 
    private var osRow: some View {
        SettingsRow(
            title: "macOS",
            showArrow: false,
            detail: {
                Text(ProcessInfo.osVersionName)
            },
            action: {}
        )
    }
    
    private func lastCheckRow(date: Date) -> some View {
        SettingsRow(
            title: "上次检查",
            showArrow: false,
            detail: {
                Text(date, formatter: dateFormatter)
            },
            action: {}
        )
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }
}
