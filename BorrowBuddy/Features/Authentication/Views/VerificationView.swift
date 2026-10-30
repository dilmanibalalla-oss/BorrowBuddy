//
//  VerificationView.swift
//  BorrowBuddy
//
//  Created by Dilmani Balalla on 2026-10-17.
//

import SwiftUI

struct VerificationView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel = VerificationViewModel()
    @State private var focusTrigger = 0
    @State private var isFieldFocused = false

    var body: some View {
        GeometryReader { proxy in
        ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            BackButton {
                router.go(to: .signIn)
            }
            .padding(.top, 8)
            .padding(.leading, -18)

            ThemeClipart(name: "ClipartChat", height: 140, label: "Neighbors talking on a porch")
                .padding(.top, 12)

            Text("Enter 6-Digit Code")
                .font(AppTheme.rounded(28, weight: .heavy))
                .foregroundStyle(AppTheme.blue)
                .accessibilityAddTraits(.isHeader)

            (Text("Enter \(DevAuthFixtures.testVerificationCode) for ") + Text(dependencies.verificationPhoneNumber).bold())
                .font(AppTheme.system(16))
                .foregroundStyle(AppTheme.text)
                .padding(.top, 8)

            ZStack {
                RespondableTextField(
                    text: Binding(
                        get: { viewModel.code },
                        set: viewModel.updateCode
                    ),
                    placeholder: "",
                    keyboardType: .numberPad,
                    textContentType: .oneTimeCode,
                    isInvisible: true,
                    maxLength: 6,
                    filterDigitsOnly: true,
                    focusTrigger: focusTrigger,
                    accessibilityLabelText: "Six digit verification code"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Six digit verification code")
                .accessibilityValue(viewModel.code.isEmpty ? "Empty" : "\(viewModel.code.count) of 6 digits entered")
                .accessibilityHint("Enter the 6 digit code.")

                HStack(spacing: 9) {
                    ForEach(0..<6, id: \.self) { index in
                        digitBox(at: index)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .frame(minHeight: 58)
            .padding(.top, 31)
            .contentShape(Rectangle())
            .onTapGesture {
                focusTrigger += 1
                isFieldFocused = true
            }

            HStack(spacing: 5) {
                Text("Didn't get the text?")
                    .foregroundStyle(AppTheme.text)
                    .accessibilityAddTraits(.isStaticText)

                if viewModel.secondsRemaining == 0 && !viewModel.isLoading {
                    Button {
                        Task {
                            if let verificationID = await viewModel.resend(
                                to: dependencies.verificationPhoneNumber,
                                using: dependencies.authenticationService
                            ) {
                                dependencies.verificationID = verificationID
                                focusTrigger += 1
                            }
                        }
                    } label: {
                        Text("Resend Code")
                            .fontWeight(.bold)
                            .underline()
                            .foregroundStyle(AppTheme.blue)
                    }
                    .accessibilityLabel("Resend code")
                    .accessibilityHint("Sends the verification code again.")
                    .accessibilityAddTraits(.isButton)
                } else {
                    Text("Resend Code (\(viewModel.secondsRemaining)s)")
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.secondaryText)
                        .accessibilityLabel("Resend code")
                        .accessibilityValue("Available in \(viewModel.secondsRemaining) seconds")
                        .accessibilityAddTraits(.isStaticText)
                        .accessibilityRemoveTraits(.isButton)
                }
            }
            .font(AppTheme.system(14))
            .padding(.top, 31)
            .accessibilityElement(children: .contain)

            if let errorMessage = viewModel.errorMessage {
                DismissingErrorText(message: errorMessage, topPadding: 12)
            }

            if let statusMessage = viewModel.statusMessage {
                Label(statusMessage, systemImage: "checkmark.shield")
                    .font(AppTheme.system(13, weight: .semibold))
                    .foregroundStyle(AppTheme.green)
                    .padding(.top, 12)
                    .accessibilityLabel(statusMessage)
            }

            Spacer()

            PrimaryButton(
                title: viewModel.isLoading ? "Verifying..." : "Verify Code",
                enabled: viewModel.canVerify && !viewModel.isLoading,
                accessibilityHint: "Checks the code and continues."
            ) {
                Task {
                    if await viewModel.verify(
                        phoneNumber: dependencies.verificationPhoneNumber,
                        verificationID: dependencies.verificationID,
                        using: dependencies.authenticationService
                    ) {
                        dependencies.verificationID = nil
                        await dependencies.notificationService.registerToken()
                        router.go(to: .faceID)
                    }
                }
            }
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
        }
        .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .accessibilityAnnounce(viewModel.errorMessage ?? viewModel.statusMessage)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                focusTrigger += 1
                isFieldFocused = true
            }
        }
    }

    private func digitBox(at index: Int) -> some View {
        let value = index < viewModel.code.count
            ? String(viewModel.code[viewModel.code.index(viewModel.code.startIndex, offsetBy: index)])
            : ""
        let isActive = isFieldFocused && !viewModel.isLoading && index == viewModel.code.count

        return Text(value)
            .font(AppTheme.rounded(24, weight: .bold))
            .foregroundStyle(AppTheme.blue)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .background(AppTheme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .stroke(isActive || !value.isEmpty ? AppTheme.blue : AppTheme.border, lineWidth: 2)
            }
            .overlay {
                if isActive {
                    OTPBlinkingCaret()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
    }
}

private struct OTPBlinkingCaret: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = true

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(AppTheme.blue)
            .frame(width: 2, height: 24)
            .opacity(isVisible ? 1 : 0)
            .task(id: reduceMotion) {
                isVisible = true
                guard !reduceMotion else { return }
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(500)) }
                    catch { return }
                    guard !Task.isCancelled else { return }
                    isVisible.toggle()
                }
            }
    }
}
