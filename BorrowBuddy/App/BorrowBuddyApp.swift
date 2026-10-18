//
//  BorrowBuddyApp.swift
//  BorrowBuddy
//

import SwiftUI

@main
struct BorrowBuddyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var router = AppRouter()
    @StateObject private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(router)
                .environmentObject(dependencies)
                .preferredColorScheme(.light)
                .onAppear {
                    dependencies.observeAuthentication()
                }
                .onOpenURL { url in
                    _ = appDelegate.application(
                        UIApplication.shared,
                        open: url,
                        options: [:]
                    )
                }
        }
    }
}
