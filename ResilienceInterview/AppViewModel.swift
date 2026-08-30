import Combine
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var account: Account?
    @Published private(set) var interview: TranscriptionViewModel?
    @Published private(set) var adminAccounts: [AdminAccount] = []
    @Published private(set) var adminHistories: [AdminHistory] = []
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
            if response.account.role == "admin" { await loadAdminData() }
        } catch { show(error) }
    }

    func startNewInterview(language: String) async {
        guard !token.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let api = InterviewAPIClient(baseURL: baseURL, token: token)
            let session = try await api.createSession(language: language, title: "現場インタビュー")
            let started = try await api.startSession(sessionID: session.id)
            interview = TranscriptionViewModel(api: api, sessionID: session.id, language: language,
                                                initialMessages: started.messages)
            interview?.speakInitialMessage()
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
            await loadAdminData()
        } catch { show(error) }
    }

    func loadAdminData() async {
        guard isAdmin, !token.isEmpty else { return }
        do {
            let api = InterviewAPIClient(baseURL: baseURL, token: token)
            async let accounts = api.listAdminAccounts()
            async let histories = api.listAdminHistories()
            adminAccounts = try await accounts
            adminHistories = try await histories
        } catch { show(error) }
    }

    func deleteOperator(id: String) async {
        guard !token.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await InterviewAPIClient(baseURL: baseURL, token: token).deleteOperatorAccount(id: id)
            await loadAdminData()
        } catch { show(error) }
    }

    private func show(_ error: Error) {
        errorMessage = error.localizedDescription
        isShowingError = true
    }
}
