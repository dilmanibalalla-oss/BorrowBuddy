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
        VStack(alignment: .leading, spacing: 0) {
            BackButton {
                router.go(to: .signIn)
            }
            .padding(.top, 8)
            .padding(.leading, -18)

            Spacer()

            Text("Enter 6-Digit Code")
                .font(AppTheme.rounded(28, weight: .heavy))
                .foregroundStyle(AppTheme.blue)

            (Text("We texted a secure code to ") + Text(dependencies.verificationPhoneNumber).bold())
                .font(.system(size: 16))
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
                    focusTrigger: focusTrigger
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Six digit verification code")

                HStack(spacing: 9) {
                    ForEach(0..<6, id: \.self) { index in
                        digitBox(at: index)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .frame(height: 58)
            .padding(.top, 31)
            .contentShape(Rectangle())
            .onTapGesture {
                focusTrigger += 1
                isFieldFocused = true
            }

            HStack(spacing: 5) {
                Text("Didn't get the text?")
                    .foregroundStyle(AppTheme.text)

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
                    Text("Resend Code (\(viewModel.secondsRemaining)s)")
                        .fontWeight(.bold)
                        .underline()
                        .foregroundStyle(AppTheme.blue)
                }
                .disabled(viewModel.secondsRemaining > 0 || viewModel.isLoading)
            }
            .font(.system(size: 14))
            .padding(.top, 31)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.coral)
                    .padding(.top, 12)
            }

            if let statusMessage = viewModel.statusMessage {
                Label(statusMessage, systemImage: "checkmark.shield")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.green)
                    .padding(.top, 12)
            }

            Spacer()

            PrimaryButton(
                title: viewModel.isLoading ? "Verifying..." : "Verify Code",
                enabled: viewModel.canVerify && !viewModel.isLoading
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
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
            .frame(height: 54)
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
