import SwiftUI

struct HomeView: View {
    @ObservedObject var app: AppViewModel
    @State private var language = "ja"
    @State private var operatorID = ""
    @State private var displayName = ""

    var body: some View {
        NavigationStack {
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
                }
                Spacer()
            }
            .padding()
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
        }
    }
}
