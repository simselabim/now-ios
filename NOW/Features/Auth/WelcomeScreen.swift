import SwiftUI
import UIKit

enum AuthenticationFormField: Hashable {
    case email
    case password
}

enum AuthenticationFormMode: Equatable {
    case signIn
    case registration
}

struct AuthenticationFormValidation: Equatable {
    let emailError: String?
    let passwordError: String?

    var firstInvalidField: AuthenticationFormField? {
        if emailError != nil { return .email }
        if passwordError != nil { return .password }
        return nil
    }
}

enum AuthenticationFormValidator {
    static func validate(
        mode: AuthenticationFormMode,
        email: String,
        password: String
    ) -> AuthenticationFormValidation {
        guard mode == .registration else {
            return AuthenticationFormValidation(emailError: nil, passwordError: nil)
        }

        return AuthenticationFormValidation(
            emailError: emailError(for: email),
            passwordError: passwordError(for: password)
        )
    }

    static func emailError(for email: String) -> String? {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedEmail.isEmpty {
            return "Email is required."
        }
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        if trimmedEmail.range(of: pattern, options: [.regularExpression, .caseInsensitive]) == nil {
            return "Enter a valid email."
        }
        return nil
    }

    static func passwordError(for password: String) -> String? {
        if password.isEmpty {
            return "Password is required."
        }
        if password.count < 8 {
            return "Password must be at least 8 characters."
        }
        return nil
    }
}

struct WelcomeScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var isPhilosophyPresented = false
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var didAttemptRegistration = false
    @FocusState private var focusedField: AuthenticationFormField?

    init(initialMode: AuthenticationFormMode = .signIn) {
        _isRegistering = State(initialValue: initialMode == .registration)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        NOWLogo()
                        Text("Eat · Walk ♥ Love")
                            .font(.caption.weight(.black))
                            .foregroundStyle(NOWColor.slate)
                    }
                    Spacer()
                    Button {
                        isPhilosophyPresented = true
                    } label: {
                        NOWChip(text: "Today", active: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Learn what NOW is about")
                }

                ZStack(alignment: .bottomLeading) {
                    PhotoSurface(name: NOWPhoto.parkWalkBlur, height: 310, blur: 1.2)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("One person, today.")
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(.white)
                        Text("Find someone nearby for coffee, a walk, dinner, or a small city plan.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.88))
                    }
                    .padding(18)
                }

                if appState.isLoading {
                    ProgressView()
                        .tint(NOWColor.lime)
                        .frame(maxWidth: .infinity)
                }

                if let error = appState.errorMessage {
                    Text(error)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(NOWColor.coral)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NOWColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .foregroundStyle(NOWColor.ink)
                        .tint(NOWColor.laCoral)
                        .padding(14)
                        .background(fieldBackground(hasError: emailError != nil))
                        .focused($focusedField, equals: .email)
                        .accessibilityHint(emailError.map { "Error: \($0)" } ?? "")
                        .accessibilityIdentifier("registration.email")

                    if let emailError {
                        Text(emailError)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(NOWColor.coral)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Email error: \(emailError)")
                            .accessibilityIdentifier("registration.email.error")
                    }

                    SecureField("Password", text: $password)
                        .textContentType(isRegistering ? .newPassword : .password)
                        .foregroundStyle(NOWColor.ink)
                        .tint(NOWColor.laCoral)
                        .padding(14)
                        .background(fieldBackground(hasError: passwordError != nil))
                        .focused($focusedField, equals: .password)
                        .accessibilityHint(passwordError.map { "Error: \($0)" } ?? "")
                        .accessibilityIdentifier("registration.password")

                    if let passwordError {
                        Text(passwordError)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(NOWColor.coral)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Password error: \(passwordError)")
                            .accessibilityIdentifier("registration.password.error")
                    }
                }
                .onChange(of: email) { _, _ in
                    guard isRegistering, didAttemptRegistration else { return }
                    emailError = AuthenticationFormValidator.emailError(for: email)
                }
                .onChange(of: password) { _, _ in
                    guard isRegistering, didAttemptRegistration else { return }
                    passwordError = AuthenticationFormValidator.passwordError(for: password)
                }

                Button(appState.isLoading ? "Connecting..." : (isRegistering ? "Create account" : "Sign in")) {
                    submitAuthentication()
                }
                .disabled(appState.isLoading || (!isRegistering && !canSubmit))
                .buttonStyle(PrimaryButtonStyle())

                Button(isRegistering ? "Already have an account? Sign in" : "New here? Create account") {
                    isRegistering.toggle()
                    appState.errorMessage = nil
                    clearFieldErrors()
                }
                .font(.footnote.weight(.bold))
                .foregroundStyle(NOWColor.ink)
                .frame(maxWidth: .infinity)

                Text("You will be visible while you are here. Tonight everything resets.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(NOWColor.inkSoft)
                    .padding(.top, 4)
            }
            .padding(22)
        }
        .accessibilityIdentifier("registration.screen")
        .sheet(isPresented: $isPhilosophyPresented) {
            NOWPhilosophySheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && password.count >= 8
    }

    private func fieldBackground(hasError: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(NOWColor.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(hasError ? NOWColor.coral : .clear, lineWidth: 2)
            }
    }

    private func submitAuthentication() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isRegistering else {
            appState.authenticate(email: trimmedEmail, password: password, register: false)
            return
        }

        didAttemptRegistration = true
        let validation = AuthenticationFormValidator.validate(
            mode: .registration,
            email: email,
            password: password
        )
        emailError = validation.emailError
        passwordError = validation.passwordError

        if let firstInvalidField = validation.firstInvalidField {
            let message = firstInvalidField == .email
                ? validation.emailError
                : validation.passwordError
            focus(on: firstInvalidField, message: message ?? "This field is required.")
            return
        }

        appState.authenticate(
            email: trimmedEmail,
            password: password,
            register: true
        ) { fieldError in
            switch fieldError {
            case let .email(message):
                emailError = message
                focus(on: .email, message: message)
            case let .password(message):
                passwordError = message
                focus(on: .password, message: message)
            }
        }
    }

    private func focus(on field: AuthenticationFormField, message: String) {
        focusedField = field
        let fieldName = field == .email ? "Email" : "Password"
        UIAccessibility.post(notification: .announcement, argument: "\(fieldName) error: \(message)")
    }

    private func clearFieldErrors() {
        emailError = nil
        passwordError = nil
        didAttemptRegistration = false
        focusedField = nil
    }
}

private struct NOWPhilosophySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                NOWLogo(compact: true)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(NOWColor.ink)
                        .frame(width: 38, height: 38)
                        .background(NOWColor.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            Text("One click.\nOne meeting. Now.")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(NOWColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("NOW is not about endless choices. It is about one real meeting today.")
                .font(.title3.weight(.bold))
                .foregroundStyle(NOWColor.slate)

            Text("Choose someone nearby and make a plan for today — no endless swiping, no weeks of messaging.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NOWColor.inkSoft)

            Spacer(minLength: 0)

            Button("Got it") {
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .background(NOWColor.laCream.ignoresSafeArea())
    }
}
