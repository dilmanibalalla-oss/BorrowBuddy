import SwiftUI

struct LocationView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel = LocationViewModel()
    @StateObject private var model = CommunityViewModel()

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            Button { router.go(to: .home) } label: {
                Label("Back", systemImage: "chevron.left").font(.subheadline.bold())
            }.foregroundStyle(AppTheme.blue).padding(.bottom, 30)

            Text("Find Your Shed")
                .font(AppTheme.rounded(27, weight: .heavy))
                .foregroundStyle(AppTheme.blue)

            Text("Set your location to find nearby shared tools. Use GPS or enter your address manually. Your profile address is private; each listing has its own pickup address.")
                .font(.system(size: 15.5))
                .foregroundStyle(AppTheme.text)
                .lineSpacing(4)
                .padding(.top, 7)

            Button {
                viewModel.useCurrentLocation()
            } label: {
                HStack(spacing: 10) {
                    Image("Location")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 18, height: 22)

                    Text("Use My Location")
                        .font(AppTheme.rounded(16, weight: .bold))
                }
                .foregroundStyle(AppTheme.blue)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(AppTheme.yellow)
                .overlay {
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(AppTheme.blue, lineWidth: 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .shadow(color: AppTheme.shadow, radius: 0, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Use My Location")
            .padding(.top, 28)

            if !viewModel.locationStatus.isEmpty {
                Text(viewModel.locationStatus)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 9)
            }

            HStack(spacing: 12) {
                Rectangle().fill(AppTheme.border).frame(height: 1)
                Text("OR")
                    .font(AppTheme.rounded(13, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)
                Rectangle().fill(AppTheme.border).frame(height: 1)
            }
            .padding(.top, 34)

            fieldLabel("STREET ADDRESS")
                .padding(.top, 28)

            addressField("Street, town, country", text: $viewModel.streetAddress)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    fieldLabel("UNIT / APT")
                    addressField("Optional", text: $viewModel.unit)
                }

                VStack(alignment: .leading, spacing: 7) {
                    fieldLabel("POSTAL CODE")
                    addressField("Postal code", text: $viewModel.postalCode)
                        .keyboardType(.numbersAndPunctuation)
                }
            }
            .padding(.top, 13)

            Spacer(minLength: 30)

            AccountSaveStatus(error: model.error, success: nil)
            PrimaryButton(title: model.isLoading ? "Saving..." : "Confirm Location", enabled: viewModel.canContinue && !model.isLoading) {
                Task {
                    if await model.perform({
                        let coordinate = try await PlaceService.coordinate(for: "\(viewModel.streetAddress), \(viewModel.postalCode)")
                        try await dependencies.communityRepository.saveAddress(street: viewModel.streetAddress, unit: viewModel.unit,
                            postalCode: viewModel.postalCode, latitude: coordinate.latitude, longitude: coordinate.longitude)
                    }) { router.go(to: .home) }
                }
            }
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.background)
        .task {
            do {
                let account = try await dependencies.accountRepository.loadAccount()
                viewModel.streetAddress = account.streetAddress
                viewModel.unit = account.unit
                viewModel.postalCode = account.postalCode
            } catch { model.error = error.localizedDescription }
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(AppTheme.rounded(12, weight: .bold))
            .foregroundStyle(AppTheme.blue)
    }

    private func addressField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 16))
            .padding(.horizontal, 15)
            .frame(height: 47)
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .stroke(AppTheme.border, lineWidth: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}
