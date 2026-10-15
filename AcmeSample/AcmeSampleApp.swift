import SwiftUI
import UIKit

// A sample sign-up for trying Proxy Mail QA (https://proxymail.qa) with an iOS
// app: sign up with a test address, send yourself the activation email, then
// activate with the code or the link from it. See README.md.

@main
struct AcmeSampleApp: App {
    @StateObject private var account = Account()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(account)
                .onOpenURL { account.open($0) }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var account: Account

    var body: some View {
        NavigationStack {
            Form {
                switch account.screen {
                case .signUp: SignUpView()
                case .activate: ActivateView()
                case .signedIn: SignedInView()
                case .logIn: LogInView()
                }
                // The activation screen shows its problems under the code field.
                if let problem = account.problem, account.screen != .activate {
                    Section {
                        Text(problem)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("problem")
                    }
                }
            }
            .navigationTitle("Acme")
        }
    }
}

struct SignUpView: View {
    @EnvironmentObject private var account: Account
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        Section("Create your account") {
            EmailField(email: $email)
            SecureField("Password", text: $password)
                .accessibilityIdentifier("password")
            Button("Sign up") { account.signUp(email: email, password: password) }
                .accessibilityIdentifier("signUp")
        }
    }
}

struct ActivateView: View {
    @EnvironmentObject private var account: Account
    @State private var code = ""
    @FocusState private var typing: Bool

    var body: some View {
        Section {
            Text("This sample has no server, so send the activation email yourself: from your app’s backend, or from your own email account.")
            LabeledContent("To") {
                Text(account.email).accessibilityIdentifier("address")
            }
            CopyButton(label: "Copy address", value: account.email)
            LabeledContent("Subject", value: account.subject)
            Text(account.message)
                .font(.callout.monospaced())
                .accessibilityIdentifier("message")
            CopyButton(label: "Copy message", value: account.message)
        } header: {
            Text("1. Send the activation email")
        }

        Section {
            TextField("Activation code", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($typing)
                .accessibilityIdentifier("code")
                // The number pad has no return key and covers the button
                // below, so a whole code activates as soon as it's typed.
                .onChange(of: code) {
                    if code.count == account.code.count { activate() }
                }
            Button("Activate") { activate() }
                .accessibilityIdentifier("activate")
        } header: {
            Text("2. Enter the code from the email")
        } footer: {
            if let problem = account.problem {
                Text(problem)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("problem")
            } else {
                Text("A whole code activates as you type it. Or open the email’s link on this device.")
            }
        }

        Section {
            Button("Start over with another address", role: .destructive) { account.startOver() }
        }
    }

    private func activate() {
        typing = false
        account.activate(code: code)
    }
}

struct SignedInView: View {
    @EnvironmentObject private var account: Account

    var body: some View {
        Section {
            Label("Account activated", systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
            Text("Signed in as \(account.email), activated with \(account.activatedWith).")
                .accessibilityIdentifier("status")
        }
        Section {
            Button("Sign out") { account.signOut() }
                .accessibilityIdentifier("signOut")
        }
    }
}

struct LogInView: View {
    @EnvironmentObject private var account: Account
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        Section("Log in") {
            EmailField(email: $email)
            SecureField("Password", text: $password)
                .accessibilityIdentifier("password")
            Button("Log in") { account.logIn(email: email, password: password) }
                .accessibilityIdentifier("logIn")
        }
        Section {
            Button("Start over with another address", role: .destructive) { account.startOver() }
        }
    }
}

struct EmailField: View {
    @Binding var email: String

    var body: some View {
        TextField("Email", text: $email)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityIdentifier("email")
    }
}

/// Copies to the clipboard. The Simulator shares its clipboard with the Mac,
/// so you can paste the address and message into your email there.
struct CopyButton: View {
    let label: String
    let value: String
    @State private var copied = false

    var body: some View {
        Button(copied ? "Copied" : label) {
            UIPasteboard.general.string = value
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                copied = false
            }
        }
    }
}
