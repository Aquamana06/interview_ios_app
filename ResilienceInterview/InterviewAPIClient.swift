import Foundation

nonisolated struct SessionPayload: Decodable {
    let session: InterviewSession?
    let messages: [InterviewMessage]
    let stateLabel: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        session = try c.decodeIfPresent(InterviewSession.self, forKey: .session)
        messages = try c.decodeIfPresent([InterviewMessage].self, forKey: .messages) ?? []
        stateLabel = try c.decodeIfPresent(String.self, forKey: .stateLabel)
    }
    private enum CodingKeys: String, CodingKey { case session, messages, stateLabel }
}

nonisolated struct InterviewSession: Decodable {
    let id: String
    let language: String
    let status: String
}

nonisolated struct InterviewMessage: Decodable {
    let id: String
    let role: String
    let content: String
}

nonisolated struct Account: Decodable {
    let id: String
    let role: String
    let displayName: String
}

nonisolated struct AdminAccount: Decodable, Identifiable {
    let id: String
    let role: String
    let displayName: String
    let isActive: Bool
    let createdAt: String
    private enum CodingKeys: String, CodingKey { case id, role, displayName = "display_name", isActive = "is_active", createdAt = "created_at" }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        role = try values.decode(String.self, forKey: .role)
        displayName = try values.decode(String.self, forKey: .displayName)
        if let boolValue = try? values.decode(Bool.self, forKey: .isActive) {
            isActive = boolValue
        } else {
            isActive = (try values.decode(Int.self, forKey: .isActive)) != 0
        }
        createdAt = try values.decode(String.self, forKey: .createdAt)
    }
    var isActiveLabel: String { isActive ? "有効" : "無効" }
    var issuedDateLabel: String { String(createdAt.prefix(10)) }
}

nonisolated struct AdminHistory: Decodable, Identifiable {
    let id: String
    let accountID: String
    let displayName: String
    let title: String
    let language: String
    let status: String
    let startedAt: String
    let endedAt: String?
    let updatedAt: String
    let messageCount: Int
    private enum CodingKeys: String, CodingKey {
        case id, accountID = "account_id", displayName = "display_name", title, language, status
        case startedAt = "started_at", endedAt = "ended_at", updatedAt = "updated_at", messageCount = "message_count"
    }
    var startedDate: Date? { ISO8601DateFormatter().date(from: startedAt) }
    var statusLabel: String { status == "ended" ? "終了" : "進行中" }
}

nonisolated struct LoginResponse: Decodable {
    let account: Account
    let token: String
}

nonisolated struct MessageRequest: Encodable {
    let content: String
    let inputMode: String
    let language: String
    let clientMessageId: String
}

nonisolated struct APIError: Decodable {
    let error: String
}

actor InterviewAPIClient {
    private let session = URLSession(configuration: .ephemeral)
    private let baseURL: URL
    private let token: String

    init(baseURL: URL, token: String) {
        self.baseURL = baseURL
        self.token = token
    }

    func sendTranscript(sessionID: String, text: String, language: String, clientMessageID: String) async throws -> SessionPayload {
        let body = MessageRequest(
            content: text,
            inputMode: "voice",
            language: language,
            clientMessageId: clientMessageID
        )
        let path = "/api/sessions/\(sessionID)/messages"
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode(APIError.self, from: data).error)
                ?? "Workerへの送信に失敗しました（HTTP \(httpResponse.statusCode)）"
            throw NSError(domain: "ResilienceInterview", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
        return try JSONDecoder().decode(SessionPayload.self, from: data)
    }

    func login(id: String, password: String) async throws -> LoginResponse {
        try await request(path: "/api/auth/login", method: "POST", body: ["id": id, "password": password])
    }

    func createSession(language: String, title: String) async throws -> InterviewSession {
        let response: SessionCreateResponse = try await request(path: "/api/sessions", method: "POST", body: ["language": language, "title": title])
        return response.session
    }

    func startSession(sessionID: String) async throws -> SessionPayload {
        try await request(path: "/api/sessions/\(sessionID)/start", method: "POST", body: nil)
    }

    func createOperatorAccount(id: String, displayName: String) async throws -> Account {
        let response: AccountCreateResponse = try await request(path: "/api/admin/accounts", method: "POST", body: ["id": id, "displayName": displayName])
        return response.account
    }

    func listAdminAccounts() async throws -> [AdminAccount] {
        let response: AdminAccountsResponse = try await request(path: "/api/admin/accounts", method: "GET", body: nil)
        return response.accounts
    }

    func listAdminHistories() async throws -> [AdminHistory] {
        let response: AdminHistoriesResponse = try await request(path: "/api/admin/histories", method: "GET", body: nil)
        return response.histories
    }

    func deleteOperatorAccount(id: String) async throws {
        let _: DeleteResponse = try await request(path: "/api/admin/accounts/\(id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id)", method: "DELETE", body: nil)
    }

    private func request<T: Decodable>(path: String, method: String, body: [String: String]?) async throws -> T {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(APIError.self, from: data).error) ?? "Workerへのリクエストに失敗しました"
            throw NSError(domain: "ResilienceInterview", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

nonisolated struct SessionCreateResponse: Decodable { let session: InterviewSession }
nonisolated struct AccountCreateResponse: Decodable { let account: Account }
nonisolated struct AdminAccountsResponse: Decodable { let accounts: [AdminAccount] }
nonisolated struct AdminHistoriesResponse: Decodable { let histories: [AdminHistory] }
nonisolated struct DeleteResponse: Decodable { let ok: Bool }
