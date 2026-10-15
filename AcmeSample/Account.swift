import CryptoKit
import Foundation

/// The sample's whole "backend": one account, kept on this device.
///
/// A real app keeps accounts on its server and sends the activation email from
/// there. This sample has no server, so it makes up the activation code itself
/// and shows you the email to send: from your own app's backend, or from your
/// own email account. Whoever is testing then reads the code (or the link) from
/// the email that arrives at the Proxy Mail QA address, and enters it here.
@MainActor
final class Account: ObservableObject {
    enum Screen: Equatable {
        case signUp, activate, signedIn, logIn
    }

    /// The app link in the activation email. Info.plist registers the scheme.
    static let scheme = "acmesample"

    @Published private(set) var screen: Screen
    @Published private(set) var email: String
    @Published private(set) var code: String
    @Published private(set) var activatedWith: String
    @Published var problem: String?

    private let store = UserDefaults.standard

    init() {
        let saved = UserDefaults.standard
        let email = saved.string(forKey: Key.email) ?? ""
        let activatedWith = saved.string(forKey: Key.activatedWith) ?? ""
        self.email = email
        self.activatedWith = activatedWith
        code = saved.string(forKey: Key.code) ?? ""
        if email.isEmpty {
            screen = .signUp
        } else if activatedWith.isEmpty {
            screen = .activate
        } else {
            screen = saved.bool(forKey: Key.signedIn) ? .signedIn : .logIn
        }
    }

    // MARK: The activation email to send

    var subject: String { "Activate your Acme account" }
    var link: String { "\(Self.scheme)://activate?code=\(code)" }
    var message: String {
        "Your Acme activation code is \(code).\n\nOr open this link in the app: \(link)"
    }

    // MARK: Actions

    func signUp(email: String, password: String) {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard email.contains("@") else { return fail("Enter an email address.") }
        guard password.count >= 8 else { return fail("Use a password of 8 or more characters.") }
        code = String(format: "%06d", Int.random(in: 0..<1_000_000))
        self.email = email
        activatedWith = ""
        store.set(email, forKey: Key.email)
        store.set(Self.hash(password), forKey: Key.password)
        store.set(code, forKey: Key.code)
        store.removeObject(forKey: Key.activatedWith)
        show(.activate)
    }

    func activate(code entered: String) {
        guard entered.trimmingCharacters(in: .whitespacesAndNewlines) == code else {
            return fail("That code doesn’t match the one in the activation email.")
        }
        activated(with: "the code")
    }

    /// acmesample://activate?code=…, opened from the activation email.
    func open(_ url: URL) {
        guard url.scheme == Self.scheme, url.host == "activate" else { return }
        let sent = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "code" }?.value
        guard screen == .activate, sent == code else {
            return fail("That link isn’t for this sign-up.")
        }
        activated(with: "the link")
    }

    func logIn(email: String, password: String) {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard email == self.email, Self.hash(password) == store.string(forKey: Key.password) else {
            return fail("That email and password don’t match the account on this device.")
        }
        store.set(true, forKey: Key.signedIn)
        show(.signedIn)
    }

    func signOut() {
        store.set(false, forKey: Key.signedIn)
        show(.logIn)
    }

    /// Forget the account, to sign up again with a new address.
    func startOver() {
        for key in [Key.email, Key.password, Key.code, Key.activatedWith, Key.signedIn] {
            store.removeObject(forKey: key)
        }
        email = ""
        code = ""
        activatedWith = ""
        show(.signUp)
    }

    // MARK: Private

    private func activated(with how: String) {
        activatedWith = how
        store.set(how, forKey: Key.activatedWith)
        store.set(true, forKey: Key.signedIn)
        show(.signedIn)
    }

    private func show(_ next: Screen) {
        problem = nil
        screen = next
    }

    private func fail(_ message: String) {
        problem = message
    }

    // The only account lives on this device, so a hash in UserDefaults is
    // enough for a sample. A real app checks passwords on its server.
    private static func hash(_ password: String) -> String {
        SHA256.hash(data: Data(password.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private enum Key {
        static let email = "email"
        static let password = "passwordHash"
        static let code = "activationCode"
        static let activatedWith = "activatedWith"
        static let signedIn = "signedIn"
    }
}
