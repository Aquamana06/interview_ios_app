import SwiftUI

struct HomeView: View {
    @ObservedObject var app: AppViewModel
    @State private var language = "ja"
    @State private var operatorID = ""
    @State private var displayName = ""
    @State private var accountToDelete: AdminAccount?
    @State private var isActiveAccountsExpanded = false
    @State private var isInactiveAccountsExpanded = false
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                Text("こんにちは、\(app.account?.displayName ?? "")さん")
                    .font(.title2)
                Picker("言語", selection: $language) {
                    Text("日本語").tag("ja")
                    Text("English").tag("en")
                    Text("Deutsch").tag("de")
                }
                .pickerStyle(.segmented)
                Button("新しいインタビューを開始") {
                    Task { await app.startNewInterview(language: language) }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, minHeight: 64)
                .disabled(app.isLoading)
                if app.isAdmin {
                    Label("管理者アカウント", systemImage: "person.badge.key")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("オペレータIDを発行").font(.headline)
                        TextField("ID（英数字・_・-）", text: $operatorID)
                            .textInputAutocapitalization(.never).textFieldStyle(.roundedBorder)
                        TextField("表示名", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                        Button("アカウントを発行") {
                            Task { await app.issueOperator(id: operatorID, displayName: displayName) }
                        }
                        .disabled(operatorID.isEmpty || displayName.isEmpty || app.isLoading)
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("オペレータアカウント").font(.headline)
                            Spacer()
                            Button { Task { await app.loadAdminData() } } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        DisclosureGroup("有効なアカウント（\(activeAccounts.count)）", isExpanded: $isActiveAccountsExpanded) {
                            accountRows(activeAccounts, canDisable: true)
                        }
                        DisclosureGroup("無効化済み（\(inactiveAccounts.count)）", isExpanded: $isInactiveAccountsExpanded) {
                            accountRows(inactiveAccounts, canDisable: false)
                        }
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("過去のインタビュー").font(.headline)
                            Spacer()
                            Text("全\(app.adminHistories.count)回").font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(app.adminHistories) { history in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(history.displayName).font(.subheadline.bold())
                                    Spacer()
                                    Text(history.statusLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(history.title)
                                Text("\(history.startedDate.map { dateFormatter.string(from: $0) } ?? history.startedAt)・\(history.messageCount)メッセージ")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        if app.adminHistories.isEmpty { Text("履歴はありません").foregroundStyle(.secondary) }
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                }
            }
            .padding()
            .task { await app.loadAdminData() }
            .navigationTitle("ホーム")
            .toolbar {
                Button("ログアウト") { app.logout() }
            }
            .navigationDestination(isPresented: Binding(
                get: { app.interview != nil },
                set: { if !$0 { app.endInterview() } }
            )) {
                if let interview = app.interview { ContentView(viewModel: interview) }
            }
            .alert("エラー", isPresented: $app.isShowingError) {
                Button("OK", role: .cancel) {}
            } message: { Text(app.errorMessage) }
            .confirmationDialog("このアカウントを無効化しますか？", isPresented: Binding(
                get: { accountToDelete != nil },
                set: { if !$0 { accountToDelete = nil } }
            ), titleVisibility: .visible) {
                Button("無効化する", role: .destructive) {
                    if let account = accountToDelete {
                        Task { await app.deleteOperator(id: account.id) }
                    }
                    accountToDelete = nil
                }
                Button("キャンセル", role: .cancel) { accountToDelete = nil }
            } message: {
                Text("このアカウントはログインできなくなります。過去の履歴は保持されます。")
            }
        }
    }

    private var activeAccounts: [AdminAccount] {
        app.adminAccounts.filter { $0.role == "operator" && $0.isActive }
    }

    private var inactiveAccounts: [AdminAccount] {
        app.adminAccounts.filter { $0.role == "operator" && !$0.isActive }
    }

    @ViewBuilder
    private func accountRows(_ accounts: [AdminAccount], canDisable: Bool) -> some View {
        if accounts.isEmpty {
            Text("該当するアカウントはありません")
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
        } else {
            ForEach(accounts) { account in
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(account.displayName)（\(account.id)）")
                        Text("発行日 \(account.issuedDateLabel)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if canDisable {
                        Button("無効化", role: .destructive) { accountToDelete = account }
                            .font(.caption)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
