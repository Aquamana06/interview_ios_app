import Combine
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var account: Account?
    @Published private(set) var interview: TranscriptionViewModel?
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var isShowingError = false

    private let baseURL = URL(string: "https://audiointerview.namako-kabe.workers.dev")!
    private var token = ""

    var isLoggedIn: Bool { account != nil }
    var isAdmin: Bool { account?.role == "admin" }

    func login(id: String, password: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await InterviewAPIClient(baseURL: baseURL, token: "").login(id: id, password: password)
            token = response.token
            account = response.account
        } catch { show(error) }
    }

    func startNewInterview(language: String) async {
        guard !token.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let api = InterviewAPIClient(baseURL: baseURL, token: token)
            let session = try await api.createSession(language: language, title: "現場インタビュー")
            _ = try await api.startSession(sessionID: session.id)
            interview = TranscriptionViewModel(api: api, sessionID: session.id, language: language)
        } catch { show(error) }
    }

    func logout() {
        account = nil
        interview = nil
        token = ""
    }

    func endInterview() { interview = nil }

    func issueOperator(id: String, displayName: String) async {
        guard !token.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await InterviewAPIClient(baseURL: baseURL, token: token)
                .createOperatorAccount(id: id, displayName: displayName)
        } catch { show(error) }
    }

    private func show(_ error: Error) {
        errorMessage = error.localizedDescription
        isShowingError = true
    }
}
