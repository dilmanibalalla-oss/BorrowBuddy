//
//  RootView.swift
//  BorrowBuddy
//

import CoreLocation
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var noticeTitle = ""
    @State private var noticeBody = ""
    @State private var showsNotice = false

    var body: some View {
        Group {
            switch router.route {
            case .splash:
                SplashView()
            case .onboardingOne:
                OnboardingOneView()
            case .onboardingTwo:
                OnboardingTwoView()
            case .signUp:
                SignUpView()
            case .login:
                LoginView()
            case .signIn:
                PhoneSignInView()
            case .verification:
                VerificationView()
            case .faceID:
                FaceIDSetupView()
            case .location:
                LocationSetupView()
            case .savedLocation:
                LocationView()
            case .home:
                HomeView()
            case .profile:
                ProfileView()
            case .wallet:
                WalletView()
            case .calendar:
                CalendarView()
            case .nearbyMap:
                NearbyMapView()
            case .toolDetails:
                ToolDetailsView()
            case .reservationReview:
                ReservationReviewView()
            case .loanList:
                LoanListView()
            case .reservationPending:
                LoanSessionView { ReservationPendingView() }
            case .loanChat:
                LoanSessionView { LoanChatView() }
            case .baselineReview:
                LoanSessionView { BaselineReviewView() }
            case .baselineCapture:
                LoanSessionView { EvidenceCaptureView(phase: .pickup) }
            case .conditionGuide:
                LoanSessionView { ConditionGuideView() }
            case .pickupMeet:
                LoanSessionView { PickupMeetView() }
            case .pickupConfirmed:
                LoanSessionView { PickupConfirmedView() }
            case .activeLoan:
                LoanSessionView { ActiveLoanView() }
            case .toolReturn:
                LoanSessionView { ToolReturnView() }
            case .arrivalConfirmed:
                LoanSessionView { ArrivalConfirmedView() }
            case .returnCapture:
                LoanSessionView { EvidenceCaptureView(phase: .return) }
            case .compareCondition:
                LoanSessionView { CompareConditionView() }
            case .ownerReview:
                LoanSessionView { OwnerReviewView() }
            case .loanCompleted:
                LoanSessionView { LoanCompletedView() }
            case .loanRating:
                LoanSessionView { LoanRatingView() }
            case .helpSupport:
                LoanSessionView { HelpSupportView() }
            case .nonReturnCase:
                LoanSessionView { NonReturnCaseView() }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: router.route)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                if !dependencies.connectivity.isOnline {
                    Text("You're offline. Saved profile, tools, and loans are still available.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.onYellow)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(AppTheme.yellow)
                        .accessibilityLabel("Offline. Showing saved information.")
                }
                if showsNotice {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(noticeTitle)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(AppTheme.onYellow)
                            Text(noticeBody)
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.onYellow)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(noticeTitle). \(noticeBody)")
                        Button {
                            showsNotice = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.onYellow)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 8)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.yellow)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .borrowBuddyDidNotify)) { notification in
            noticeTitle = notification.userInfo?["title"] as? String ?? "BorrowBuddy"
            noticeBody = notification.userInfo?["body"] as? String ?? ""
            showsNotice = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .dropOffRegionEntered)) { notification in
            let info = notification.userInfo ?? [:]
            guard let reservationID = info["reservationID"] as? String else { return }
            let location = info["location"] as? CLLocation
            Task {
                await dependencies.handleDropOff(
                    reservationID: reservationID,
                    location: location,
                    router: router
                )
            }
        }
        .task(id: dependencies.isAuthenticated) {
            await reconcileAuthState()
        }
    }

    private func reconcileAuthState() async {
        guard dependencies.isAuthenticated else {
            if router.route == .home {
                router.go(to: .signUp)
            }
            return
        }

        // Returning users who finished onboarding land on the dashboard.
        if router.route == .splash || router.route == .login || router.route == .signUp {
            do {
                if try await dependencies.authenticationService.hasCompletedOnboarding() {
                    router.go(to: .home)
                } else if router.route == .splash {
                    // Fresh session mid-onboarding — continue from phone step.
                    router.go(to: .signIn)
                }
            } catch {
                // Stay on the current screen if profile lookup fails.
            }
        }
    }
}
