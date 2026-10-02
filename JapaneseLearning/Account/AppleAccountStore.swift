import AuthenticationServices
import Foundation
import Observation

@MainActor
@Observable
final class AppleAccountStore {
    private enum Keys {
        static let userID = "apple.account.userID"
        static let email = "apple.account.email"
        static let displayName = "apple.account.displayName"
    }

    private(set) var userID: String?
    private(set) var email: String?
    private(set) var displayName: String?
    private(set) var credentialState: ASAuthorizationAppleIDProvider.CredentialState = .revoked

    var isSignedIn: Bool {
        userID != nil && credentialState != .revoked && credentialState != .notFound
    }

    init() {
        userID = UserDefaults.standard.string(forKey: Keys.userID)
        email = UserDefaults.standard.string(forKey: Keys.email)
        displayName = UserDefaults.standard.string(forKey: Keys.displayName)
    }

    func handleAuthorization(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }

        userID = credential.user
        email = credential.email ?? email
        displayName = formattedName(credential.fullName) ?? displayName
        credentialState = .authorized
        persist()
    }

    func refreshCredentialState() async {
        guard let userID else { return }

        credentialState = await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }

    func signOut() {
        userID = nil
        email = nil
        displayName = nil
        credentialState = .revoked
        clearPersistedData()
    }

    func deleteLocalAccountData() {
        signOut()
        UserDefaults.standard.removeObject(forKey: "cached_videos")
        UserDefaults.standard.removeObject(forKey: "cached_playlist_categories")
    }

    private func persist() {
        UserDefaults.standard.set(userID, forKey: Keys.userID)
        UserDefaults.standard.set(email, forKey: Keys.email)
        UserDefaults.standard.set(displayName, forKey: Keys.displayName)
    }

    private func clearPersistedData() {
        [Keys.userID, Keys.email, Keys.displayName].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
    }

    private func formattedName(_ name: PersonNameComponents?) -> String? {
        guard let name else { return nil }
        let value = [name.familyName, name.givenName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return value.isEmpty ? nil : value
    }
}
