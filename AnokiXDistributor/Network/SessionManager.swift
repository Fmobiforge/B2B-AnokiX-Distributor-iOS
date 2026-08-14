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
        static let phone = "phone_number"
        static let roleLabel = "role_label"
        static let companyName = "company_name"
        static let companyLegalName = "company_legal_name"
        static let companyLogoUrl = "company_logo_url"
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

    /// The account's mobile number. Kept apart from `setUser` because login and the profile
    /// editor learn it at different moments, and screens that pre-fill a form from the
    /// signed-in operator (Airtime & VAS › Onboard customer) need it on its own.
    var phone: String {
        get { defaults.string(forKey: Key.phone) ?? "" }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespaces), forKey: Key.phone) }
    }

    /// Absolute URL of the distributor company logo (from login `portal_info`), or "" when none.
    var companyLogoUrl: String {
        get { defaults.string(forKey: Key.companyLogoUrl) ?? "" }
        set { defaults.set(newValue, forKey: Key.companyLogoUrl) }
    }

    /// Display name from the login `portal_info`.
    var companyName: String {
        get { defaults.string(forKey: Key.companyName) ?? "" }
        set { defaults.set(newValue, forKey: Key.companyName) }
    }

    /// The registered entity name from `base-info`'s `portal_info`. Login only returns
    /// `company_name`, so this is cached separately once base-info answers and the
    /// dashboard can paint it immediately on the next launch.
    var companyLegalName: String {
        get { defaults.string(forKey: Key.companyLegalName) ?? "" }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespaces), forKey: Key.companyLegalName) }
    }

    /// What to call the distributor on screen: the registered legal name when we know it,
    /// otherwise the display name login returned.
    var distributorName: String {
        companyLegalName.isEmpty ? companyName : companyLegalName
    }

    var initials: String {
        let f = firstName.prefix(1)
        let l = lastName.prefix(1)
        let combined = "\(f)\(l)".uppercased()
        return combined.isEmpty ? "A" : combined
    }

    func clear() {
        [Key.token, Key.firstName, Key.lastName, Key.email, Key.phone, Key.roleLabel,
         Key.companyName, Key.companyLegalName, Key.companyLogoUrl].forEach {
            defaults.removeObject(forKey: $0)
        }
    }
}
