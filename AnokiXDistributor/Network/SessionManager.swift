import Foundation

/// Port of session/SessionManager.java. Persists the bearer token + basic profile
/// in UserDefaults so the session survives across screens and app restarts.
final class SessionManager {

    static let shared = SessionManager()

    private let defaults = UserDefaults.standard
    private enum Key {
        static let token = "auth_token"
        static let firstName = "first_name"
        static let lastName = "last_name"
        static let email = "email"
        static let roleLabel = "role_label"
    }

    private init() {}

    var token: String {
        get { defaults.string(forKey: Key.token) ?? "" }
        set { defaults.set(newValue, forKey: Key.token) }
    }

    var isLoggedIn: Bool { !token.isEmpty }

    func setUser(firstName: String?, lastName: String?, email: String?, roleLabel: String?) {
        defaults.set(firstName ?? "", forKey: Key.firstName)
        defaults.set(lastName ?? "", forKey: Key.lastName)
        defaults.set(email ?? "", forKey: Key.email)
        defaults.set(roleLabel ?? "", forKey: Key.roleLabel)
    }

    var firstName: String { defaults.string(forKey: Key.firstName) ?? "" }
    var lastName: String { defaults.string(forKey: Key.lastName) ?? "" }
    var fullName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }
    var email: String { defaults.string(forKey: Key.email) ?? "" }
    var roleLabel: String { defaults.string(forKey: Key.roleLabel) ?? "" }

    var initials: String {
        let f = firstName.prefix(1)
        let l = lastName.prefix(1)
        let combined = "\(f)\(l)".uppercased()
        return combined.isEmpty ? "A" : combined
    }

    func clear() {
        [Key.token, Key.firstName, Key.lastName, Key.email, Key.roleLabel].forEach {
            defaults.removeObject(forKey: $0)
        }
    }
}
