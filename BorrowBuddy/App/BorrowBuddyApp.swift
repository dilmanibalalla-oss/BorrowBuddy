//
//  BorrowBuddyApp.swift
//  BorrowBuddy
//

import FirebaseCore
import SwiftUI

@main
struct BorrowBuddyApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var dependencies = AppDependencies()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(router)
                .environmentObject(dependencies)
                .preferredColorScheme(.light)
                .onAppear {
                    dependencies.observeAuthentication()
                }
        }
    }
}
