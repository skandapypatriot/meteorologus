import SwiftUI

/// Mirrors `auth_screen.dart`.
struct AuthView: View {

    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var theme: ThemeViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var obscurePassword = true
    @State private var infoMessage: String?
    @State private var localError: String?

    private let brandBlue = Color(red: 0.23, green: 0.51, blue: 0.96)

    private var isSignUp: Bool { auth.isSignUpMode }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: theme.theme.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .onTapGesture { hideKeyboard() }

            ScrollView {
                VStack(spacing: 0) {
                    // Hero section
                    Image("Logo")
                        .resizable()
                        .frame(width: 64, height: 64)
                    Text("Meteorologus")
                        .font(.system(size: 26, weight: .heavy))
                        .kerning(-0.5)
                        .foregroundColor(theme.theme.textColor)
                        .padding(.top, 12)
                    Text("Your weather, on your device")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.theme.textColor.opacity(0.78))
                        .padding(.top, 4)
                    Text("Sign in to see your weather nodes, live telemetry and ML forecasts.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.theme.textColor.opacity(0.59))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                        .padding(.horizontal, 32)

                    authCard
                        .padding(.top, 24)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: 480)
            }
        }
        .onAppear {
            if let msg = auth.infoMessage {
                infoMessage = msg
                auth.clearError()
            }
        }
    }

    // MARK: - Auth card

    private var authCard: some View {
        GlassCard(padding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)) {
            VStack(alignment: .leading, spacing: 0) {
                Text(isSignUp ? "Create account" : "Sign in")
                    .font(.system(size: 20, weight: .heavy))
                    .kerning(-0.3)
                    .foregroundColor(theme.theme.textColor)

                // Email
                authLabel("EMAIL")
                    .padding(.top, 18)
                authTextField(hint: "user@example.com", text: $email, isSecure: false)
                    .padding(.top, 6)

                // Password
                authLabel("PASSWORD")
                    .padding(.top, 14)
                authSecureField(hint: "\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}", text: $password, isSecure: obscurePassword, toggle: {
                    obscurePassword.toggle()
                })
                .padding(.top, 6)

                if let msg = localError ?? auth.errorMessage {
                    Text(msg)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.98, green: 0.44, blue: 0.52))
                        .padding(.top, 10)
                }

                if let msg = infoMessage {
                    Text(msg)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.29, green: 0.68, blue: 0.31))
                        .padding(.top, 10)
                }

                // Primary button
                Button {
                    Task { await handleSubmit() }
                } label: {
                    Group {
                        if auth.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(isSignUp ? "Create account" : "Sign in")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.glassProminent)
                .tint(brandBlue)
                .disabled(auth.isLoading)
                .padding(.top, 20)

                // Mode toggle
                Button {
                    auth.toggleMode()
                    infoMessage = nil
                    localError = nil
                } label: {
                    Text(isSignUp ? "I already have an account" : "Create a new account")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.glass)
                .tint(brandBlue)
                .disabled(auth.isLoading)
                .padding(.top, 10)

                if !isSignUp {
                    Button {
                        Task { await handleForgotPassword() }
                    } label: {
                        Text("Forgot password?")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.theme.textColor.opacity(0.63))
                    }
                    .disabled(auth.isLoading)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func authLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .kerning(0.8)
            .foregroundColor(theme.theme.textColor.opacity(0.55))
    }

    private func authTextField(hint: String, text: Binding<String>, isSecure: Bool) -> some View {
        TextField(hint, text: text)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(theme.theme.textColor)
            .padding(14)
            .background(Color.black.opacity(0.16))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func authSecureField(hint: String, text: Binding<String>, isSecure: Bool, toggle: @escaping () -> Void) -> some View {
        HStack {
            Group {
                if isSecure {
                    SecureField(hint, text: text)
                } else {
                    TextField(hint, text: text)
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(theme.theme.textColor)

            Button(action: toggle) {
                Image(systemName: isSecure ? "eye.slash" : "eye")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.theme.textColor.opacity(0.59))
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.16))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    @MainActor
    private func handleSubmit() async {
        hideKeyboard()
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            auth.clearError()
            localError = "Please enter both email and password."
            return
        }
        localError = nil

        if isSignUp {
            if password.count < 6 {
                localError = "Password must be at least 6 characters."
                return
            }
            await auth.signUp(email: email, password: password)
        } else {
            await auth.signIn(email: email, password: password)
        }

        localError = auth.errorMessage
        if auth.isAuthenticated { infoMessage = nil }
    }

    @MainActor
    private func handleForgotPassword() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            localError = "Please enter your email above first."
            return
        }
        localError = nil
        await auth.sendPasswordReset(email: email)
        localError = auth.errorMessage
        if let msg = auth.infoMessage {
            infoMessage = msg
        }
    }

    private func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}