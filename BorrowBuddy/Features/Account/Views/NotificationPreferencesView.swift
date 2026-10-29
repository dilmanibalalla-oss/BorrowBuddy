//
//  NotificationPreferencesView.swift
//  BorrowBuddy
//

import SwiftUI
import UIKit
import UserNotifications

struct NotificationPreferencesView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = AccountSettingsViewModel()
    @State private var waitingForSystemSettings = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    AccountSettingsHeader(title: "Notifications", subtitle: "Choose the updates you receive") {
                        dismiss()
                    }
                    settingsCard
                    AccountNotice(
                        icon: "bell.badge",
                        title: "Important loan alerts",
                        message: "Pickup, return, and safety notices may also appear inside the app."
                    )
                    AccountSaveStatus(error: viewModel.errorMessage, success: viewModel.successMessage)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            PrimaryButton(title: viewModel.isLoading ? "Saving..." : "Save preferences", enabled: !viewModel.isLoading) {
                Task { await savePreferences(openSettingsIfNeeded: true) }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .background(AppTheme.surface)
        }
        .background(AppTheme.background)
        .navigationBarHidden(true)
        .task {
            await viewModel.loadNotifications(using: dependencies.accountRepository)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, waitingForSystemSettings else { return }
            waitingForSystemSettings = false
            Task { await savePreferences(openSettingsIfNeeded: false) }
        }
    }

    private func savePreferences(openSettingsIfNeeded: Bool) async {
        let wantsAlerts = viewModel.notifications.reservationUpdates
            || viewModel.notifications.pickupReminders
            || viewModel.notifications.returnReminders
            || viewModel.notifications.neighborhoodActivity
        if wantsAlerts {
            let allowed = await systemNotificationsAllowed(openSettingsIfNeeded: openSettingsIfNeeded)
            guard await viewModel.saveNotifications(using: dependencies.accountRepository) else { return }
            await dependencies.notificationService.registerToken()
            guard allowed else { return }
            let loans = (try? await dependencies.borrowingRepository.fetchMyLoans()) ?? []
            for loan in loans {
                await dependencies.notificationService.schedule(for: loan, preferences: viewModel.notifications)
            }
            await dependencies.notificationService.deliver(
                title: "Notifications are on",
                body: "BorrowBuddy will send pickup, return, and loan updates."
            )
        } else {
            guard await viewModel.saveNotifications(using: dependencies.accountRepository) else { return }
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }

    private func systemNotificationsAllowed(openSettingsIfNeeded: Bool) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        case .denied:
            guard openSettingsIfNeeded, let url = URL(string: UIApplication.openSettingsURLString) else { return false }
            waitingForSystemSettings = true
            await UIApplication.shared.open(url)
            return false
        @unknown default:
            return false
        }
    }

    private var settingsCard: some View {
        AccountCard {
            VStack(spacing: 0) {
                preference(
                    "Reservation updates",
                    detail: "Approvals, cancellations, and credit holds",
                    value: $viewModel.notifications.reservationUpdates
                )
                Divider().padding(.vertical, 4)
                preference(
                    "Pickup reminders",
                    detail: "Meeting time and pickup checklist",
                    value: $viewModel.notifications.pickupReminders
                )
                Divider().padding(.vertical, 4)
                preference(
                    "Return reminders",
                    detail: "Due-time and return-area alerts",
                    value: $viewModel.notifications.returnReminders
                )
                Divider().padding(.vertical, 4)
                preference(
                    "Neighborhood activity",
                    detail: "New nearby tools and community news",
                    value: $viewModel.notifications.neighborhoodActivity
                )
            }
        }
    }

    private func preference(_ title: String, detail: String, value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .tint(AppTheme.blue)
        .padding(.vertical, 8)
    }
}
