import SwiftUI

struct LoginView: View {
    @ObservedObject var app: AppViewModel
    @State private var id = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Resilience Interview").font(.largeTitle.bold())
            TextField("ユーザーID", text: $id)
                .textInputAutocapitalization(.never).textFieldStyle(.roundedBorder)
            SecureField("管理者パスワード（管理者のみ）", text: $password)
                .textFieldStyle(.roundedBorder)
            Button("ログイン") { Task { await app.login(id: id, password: password) } }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, minHeight: 50)
                .disabled(id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || app.isLoading)
            if app.isLoading { ProgressView() }
            Spacer()
        }
        .padding(24)
        .alert("ログインエラー", isPresented: $app.isShowingError) {
            Button("OK", role: .cancel) {}
        } message: { Text(app.errorMessage) }
    }
}
