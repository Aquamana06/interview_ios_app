import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingEndConfirmation = false
    @State private var isShowingTranscript = false
    @State private var isShowingHistory = false

    private var latestAIMessage: InterviewMessage? { viewModel.messages.last(where: { $0.role == "system" }) }
    private var statusText: String {
        if viewModel.isRecording { return "録音中" }
        if viewModel.isTranscribing { return "文字起こし中" }
        if viewModel.isSending { return "AIが考えています" }
        return "お話しください"
    }
    private var statusColor: Color {
        if viewModel.isRecording { return .red }
        if viewModel.isTranscribing || viewModel.isSending { return .orange }
        return .teal
    }

    var body: some View {
        ZStack {
            Color(red: 0.98, green: 0.98, blue: 0.97).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    statusPill
                    alpacaCard
                    recordingControl
                    if viewModel.isTranscribing || viewModel.isSending { processingCard }
                    if !viewModel.transcript.isEmpty { transcriptSection }
                    if viewModel.messages.count > 1 { historySection }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("インタビュー")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("終了", role: .destructive) { isShowingEndConfirmation = true }
            }
        }
        .confirmationDialog("インタビューを終了しますか？", isPresented: $isShowingEndConfirmation, titleVisibility: .visible) {
            Button("終了する", role: .destructive) { viewModel.forceEndInterview(); dismiss() }
            Button("キャンセル", role: .cancel) {}
        } message: { Text("録音中の場合は保存・送信せずに破棄します。") }
        .alert("エラー", isPresented: $viewModel.isShowingError) {
            Button("OK", role: .cancel) {}
        } message: { Text(viewModel.errorMessage) }
    }

    private var statusPill: some View {
        HStack(spacing: 10) {
            Circle().fill(statusColor).frame(width: 11, height: 11)
            Text(statusText).font(.headline)
            Spacer()
            Image(systemName: "speaker.wave.2.fill").foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(.white, in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
    }

    private var alpacaCard: some View {
        VStack(spacing: 16) {
            Image("InterviewAlpaca")
                .resizable().scaledToFit().frame(width: 190, height: 190).clipShape(Circle())
            VStack(alignment: .leading, spacing: 10) {
                Text("interviewer")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(red: 0.38, green: 0.30, blue: 0.08))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color.yellow.opacity(0.65), in: Capsule())
                Text(latestAIMessage == nil
                     ? "準備ができました。ゆっくりお話しください。"
                     : (viewModel.displayedAIText.isEmpty ? "…" : viewModel.displayedAIText))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(red: 0.24, green: 0.21, blue: 0.17))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .background(Color(red: 1.0, green: 0.98, blue: 0.82), in: RoundedRectangle(cornerRadius: 28))
            .overlay { RoundedRectangle(cornerRadius: 28).stroke(Color.teal.opacity(0.18), lineWidth: 5) }
        }
    }

    private var recordingControl: some View {
        VStack(spacing: 12) {
            Button { Task { await viewModel.toggleRecording() } } label: {
                ZStack {
                    Circle().fill(viewModel.isRecording ? Color.red : Color.teal)
                        .frame(width: 92, height: 92)
                        .shadow(color: statusColor.opacity(0.3), radius: 14, y: 7)
                    Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 32, weight: .bold)).foregroundStyle(.white)
                }
            }
            .disabled(!viewModel.hasModel || viewModel.isTranscribing || viewModel.isSending)
            Text(viewModel.isRecording ? "タップして回答を送信" : "タップして回答を録音")
                .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            if viewModel.isRecording { Text(viewModel.elapsedRecordingTime).font(.system(.title3, design: .monospaced).weight(.semibold)).foregroundStyle(.red) }
        }
        .frame(maxWidth: .infinity)
    }

    private var processingCard: some View {
        VStack(spacing: 10) {
            if viewModel.isTranscribing {
                Label("端末内で文字起こし中…", systemImage: "waveform")
                ProgressView(value: min(max(viewModel.progress, 0), 1))
            } else { Label("Workerで次の質問を準備中…", systemImage: "sparkles") }
        }
        .font(.subheadline).foregroundStyle(.secondary).padding(16).frame(maxWidth: .infinity)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 18))
    }

    private var transcriptSection: some View {
        DisclosureGroup("今回のTranscript", isExpanded: $isShowingTranscript) {
            Text(viewModel.transcript).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8).textSelection(.enabled)
        }
        .padding(16).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 18))
    }

    private var historySection: some View {
        DisclosureGroup("これまでの会話（\(viewModel.messages.count)件）", isExpanded: $isShowingHistory) {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.messages, id: \.id) { message in
                    HStack {
                        if message.role == "user" { Spacer(minLength: 28) }
                        Text(message.content).font(.subheadline).padding(12)
                            .background(message.role == "system" ? Color.white : Color.teal.opacity(0.14), in: RoundedRectangle(cornerRadius: 15))
                        if message.role == "system" { Spacer(minLength: 28) }
                    }
                }
            }.padding(.top, 8)
        }
        .padding(16).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 18))
    }
}
