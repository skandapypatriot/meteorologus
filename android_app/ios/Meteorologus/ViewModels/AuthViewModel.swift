import Foundation

/// Observable view model mirroring `auth_provider.dart`.
@MainActor
final class AuthViewModel: ObservableObject {

    @Published private(set) var session: StoredSession?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var infoMessage: String?
    @Published var isSignUpMode = false

    let authService = AuthService()

    private let sessionKey = "stored_session"

    init() {
        restoreSession()
    }

    var userID: String? { session?.uid }
    var userEmail: String? { session?.email }
    var isAuthenticated: Bool { session != nil }

    // MARK: - Session persistence

    private func restoreSession() {
        guard let data = KeychainStore.load(forKey: sessionKey)?.data(using: .utf8) else { return }
        session = StoredSession.fromData(data)
    }

    private func persist(_ newSession: StoredSession) {
        session = newSession
        if let data = newSession.encodedData() {
            KeychainStore.save(value: String(data: data, encoding: .utf8) ?? "", forKey: sessionKey)
        }
    }

    // MARK: - Actions

    func toggleMode() {
        isSignUpMode.toggle()
        errorMessage = nil
    }

    func clearError() {
        errorMessage = nil
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let newSession = try await authService.signIn(email: email, password: password)
            persist(newSession)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let newSession = try await authService.signUp(email: email, password: password)
            persist(newSession)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func sendPasswordReset(email: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authService.sendPasswordReset(email: email)
            infoMessage = "Reset email sent to \(email). Check your inbox."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func signOut() {
        session = nil
        KeychainStore.delete(forKey: sessionKey)
    }
}