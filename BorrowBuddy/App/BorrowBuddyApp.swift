//
//  BorrowBuddyApp.swift
//  BorrowBuddy
//

import SwiftUI

@main
struct BorrowBuddyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var router: AppRouter
    @StateObject private var dependencies: AppDependencies
    @AppStorage(AppTheme.darkModeKey) private var darkMode = false

    init() {
        FirebaseBootstrap.configure()
        _router = StateObject(wrappedValue: AppRouter())
        _dependencies = StateObject(wrappedValue: AppDependencies())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environmentObject(router)
                .environmentObject(dependencies)
                .environmentObject(dependencies.borrowingFlow)
                .environmentObject(dependencies.loanLifecycle)
                .preferredColorScheme(darkMode ? .dark : .light)
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
