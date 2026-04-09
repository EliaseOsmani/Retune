//
//  SpotifyAuthManager.swift
//  Retune
//
//  Created by Eliase Osmani on 4/6/26.
//

import Foundation
import Combine
import AuthenticationServices

@MainActor
final class SpotifyAuthManager: NSObject, ObservableObject {

    static let shared = SpotifyAuthManager()

    @Published var isAuthenticated = false
    @Published var isAuthenticating = false
    @Published var errorMessage: String?

    private let clientID     = Secrets.spotifyClientID
    private let redirectURI  = Secrets.spotifyRedirectURI
    private let scopes       = "playlist-read-private playlist-read-collaborative playlist-modify-public playlist-modify-private"

    private let tokenKey        = "spotify_access_token"
    private let refreshKey      = "spotify_refresh_token"
    private let expiryKey       = "spotify_token_expiry"

    private var authSession: ASWebAuthenticationSession?

    private override init() {
        super.init()
        isAuthenticated = storedAccessToken != nil && !isTokenExpired
    }

    // MARK: - Login

    func login() {
        isAuthenticating = true
        errorMessage = nil

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            .init(name: "client_id",      value: clientID),
            .init(name: "response_type",  value: "code"),
            .init(name: "redirect_uri",   value: redirectURI),
            .init(name: "scope",          value: scopes),
            .init(name: "show_dialog",    value: "true")
        ]

        guard let url = components.url else { return }

        authSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "retune"
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                await self?.handleCallback(url: callbackURL, error: error)
            }
        }
        authSession?.presentationContextProvider = self
        authSession?.prefersEphemeralWebBrowserSession = true
        authSession?.start()
    }

    func logout() {
        removeToken(key: tokenKey)
        removeToken(key: refreshKey)
        UserDefaults.standard.removeObject(forKey: expiryKey)
        isAuthenticated = false
    }

    // MARK: - Callback handling

    private func handleCallback(url: URL?, error: Error?) async {
        isAuthenticating = false

        if let error {
            if (error as NSError).code != ASWebAuthenticationSessionError.canceledLogin.rawValue {
                errorMessage = error.localizedDescription
            }
            return
        }

        guard let url,
              let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "code" })?.value
        else {
            errorMessage = "Spotify didn't return an authorization code."
            return
        }

        await exchangeCodeForToken(code: code)
    }

    // MARK: - Token exchange

    private func exchangeCodeForToken(code: String) async {
        guard let request = tokenRequest(body: [
            "grant_type":    "authorization_code",
            "code":          code,
            "redirect_uri":  redirectURI,
            "client_id":     clientID,
            "client_secret": Secrets.spotifyClientSecret  // add this
        ]) else { return }

        await performTokenRequest(request)
    }

    func refreshAccessToken() async {
        guard let refresh = storedRefreshToken else {
            isAuthenticated = false
            return
        }

        guard let request = tokenRequest(body: [
            "grant_type":    "refresh_token",
            "refresh_token": refresh,
            "client_id":     clientID,
            "client_secret": Secrets.spotifyClientSecret  // add this line
        ]) else { return }

        await performTokenRequest(request)
    }

    private func tokenRequest(body: [String: String]) -> URLRequest? {
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        return request
    }

    private func performTokenRequest(_ request: URLRequest) async {
        do {
            let (data, _) = try await URLSession.shared.data(for: request)

            // Temporary debug — remove before release
            print("🎵 Spotify token response:", String(data: data, encoding: .utf8) ?? "unreadable")

            let response = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)

            saveToken(response.access_token, key: tokenKey)
            if let refresh = response.refresh_token {
                saveToken(refresh, key: refreshKey)
            }
            let expiry = Date().addingTimeInterval(TimeInterval(response.expires_in - 60))
            UserDefaults.standard.set(expiry, forKey: expiryKey)
            isAuthenticated = true
        } catch {
            errorMessage = "Couldn't get Spotify token: \(error.localizedDescription)"
            isAuthenticated = false
        }
    }

    // MARK: - Token accessors

    var accessToken: String? {
        guard !isTokenExpired else { return nil }
        return storedAccessToken
    }

    var validAccessToken: String? {
        get async {
            if isTokenExpired { await refreshAccessToken() }
            return storedAccessToken
        }
    }

    private var isTokenExpired: Bool {
        guard let expiry = UserDefaults.standard.object(forKey: expiryKey) as? Date else { return true }
        return Date() >= expiry
    }

    private var storedAccessToken:  String? { retrieveToken(key: tokenKey) }
    private var storedRefreshToken: String? { retrieveToken(key: refreshKey) }

    // MARK: - Keychain

    private func saveToken(_ token: String, key: String) {
        let data = Data(token.utf8)
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData:   data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func retrieveToken(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func removeToken(key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Presentation context

extension SpotifyAuthManager: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Hop to the main actor synchronously to access UI properties
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { !$0.windows.isEmpty }
                .flatMap { scene in scene.windows.first { $0.isKeyWindow } }
                ?? UIWindow()
        }
    }
}

// MARK: - Token response model

private struct SpotifyTokenResponse: Decodable {
    let access_token:  String
    let expires_in:    Int
    let refresh_token: String?
}
