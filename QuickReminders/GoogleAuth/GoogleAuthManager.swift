//
//  GoogleAuthManager.swift
//  QuickReminders
//
//  Google OAuth authentication manager
//

#if os(iOS)
import Foundation
import Combine
import GoogleSignIn
import UIKit

@MainActor
class GoogleAuthManager: ObservableObject {
    static let shared = GoogleAuthManager()

    @Published var isSignedIn = false
    @Published var userEmail: String?
    @Published var userName: String?
    @Published var userProfileImage: String?

    private var currentUser: GIDGoogleUser?

    // Scopes we need for both Tasks and Calendar
    private let scopes = [
        "https://www.googleapis.com/auth/tasks",
        "https://www.googleapis.com/auth/calendar"
    ]

    private init() {
        // Restore previous sign-in on init
        restorePreviousSignIn()
    }

    func restorePreviousSignIn() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            guard let self = self else { return }

            if error != nil {
                return
            }

            if let user = user {
                Task { @MainActor in
                    self.handleSignInSuccess(user)
                }
            }
        }
    }

    func signIn(presentingViewController: UIViewController) {
        guard let clientID = GIDSignIn.sharedInstance.configuration?.clientID else {
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingViewController,
            hint: nil,
            additionalScopes: scopes
        ) { [weak self] result, error in
            guard let self = self else { return }

            if error != nil {
                return
            }

            guard let user = result?.user else {
                return
            }

            Task { @MainActor in
                self.handleSignInSuccess(user)
            }
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        currentUser = nil
        isSignedIn = false
        userEmail = nil
        userName = nil
        userProfileImage = nil
    }

    private func handleSignInSuccess(_ user: GIDGoogleUser) {
        currentUser = user
        isSignedIn = true
        userEmail = user.profile?.email
        userName = user.profile?.name

        if let imageUrl = user.profile?.imageURL(withDimension: 100) {
            userProfileImage = imageUrl.absoluteString
        }
    }

    func getAccessToken() async throws -> String {
        guard let user = currentUser else {
            throw GoogleAuthError.notSignedIn
        }

        // Refresh token if needed
        if let expirationDate = user.accessToken.expirationDate,
           expirationDate < Date() {
            do {
                try await user.refreshTokensIfNeeded()
            } catch {
                throw GoogleAuthError.tokenRefreshFailed
            }
        }

        return user.accessToken.tokenString
    }

    func hasRequiredScopes() -> Bool {
        guard let user = currentUser else { return false }

        let grantedScopes = user.grantedScopes ?? []
        return scopes.allSatisfy { grantedScopes.contains($0) }
    }

}

enum GoogleAuthError: Error, LocalizedError {
    case notSignedIn
    case tokenRefreshFailed
    case missingScopes

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Not signed in to Google"
        case .tokenRefreshFailed:
            return "Failed to refresh access token"
        case .missingScopes:
            return "Missing required permissions"
        }
    }
}
#endif
