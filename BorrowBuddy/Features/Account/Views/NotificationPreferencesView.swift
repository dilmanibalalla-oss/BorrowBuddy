//
//  NotificationPreferencesView.swift
//  BorrowBuddy
//

import SwiftUI
import UserNotifications

struct NotificationPreferencesView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AccountSettingsViewModel()

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
                Task {
                    if viewModel.notifications.reservationUpdates
                        || viewModel.notifications.pickupReminders
                        || viewModel.notifications.returnReminders {
                        _ = try? await UNUserNotificationCenter.current()
                            .requestAuthorization(options: [.alert, .badge, .sound])
                    }
                    _ = await viewModel.saveNotifications(using: dependencies.accountRepository)
                    await dependencies.notificationService.registerToken()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .background(Color.white)
        }
        .background(AppTheme.background)
        .navigationBarHidden(true)
        .task {
            await viewModel.loadNotifications(using: dependencies.accountRepository)
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
