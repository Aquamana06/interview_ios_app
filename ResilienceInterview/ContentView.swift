import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingEndConfirmation = false

    var body: some View {
        VStack(spacing: 20) {
            Label(viewModel.hasModel ? "ggml-small 準備完了" : "ggml-small がありません",
                  systemImage: viewModel.hasModel ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(viewModel.hasModel ? .green : .orange)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button { Task { await viewModel.toggleRecording() } } label: {
                Label(viewModel.isRecording ? "録音を停止" : "回答を録音",
                      systemImage: viewModel.isRecording ? "stop.fill" : "mic.fill")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 64)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isRecording ? .red : .orange)
            .disabled(!viewModel.hasModel || viewModel.isTranscribing || viewModel.isSending)

            if !viewModel.messages.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("インタビュー").font(.headline)
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(viewModel.messages, id: \.id) { message in
                                HStack {
                                    if message.role == "user" { Spacer(minLength: 32) }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(message.role == "system" ? "AIインタビュアー" : "あなた")
                                            .font(.caption.bold())
                                        Text(message.content)
                                    }
                                    .padding(12)
                                    .background(message.role == "system" ? Color(.secondarySystemBackground) : Color.orange.opacity(0.18))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    if message.role == "system" { Spacer(minLength: 32) }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
            }

            if viewModel.isRecording {
                Label(viewModel.elapsedRecordingTime, systemImage: "record.circle").foregroundStyle(.red)
            } else if viewModel.isTranscribing {
                Label("端末内で文字起こし中…", systemImage: "waveform").foregroundStyle(.secondary)
                ProgressView(value: viewModel.progress)
            } else if viewModel.isSending {
                Label("Workerへ送信中…", systemImage: "arrow.up.circle").foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Transcript").font(.headline)
                    Spacer()
                    Button("消去") { viewModel.clearTranscript() }
                        .disabled(viewModel.transcript.isEmpty || viewModel.isTranscribing || viewModel.isSending)
                }
                ScrollView {
                    Text(viewModel.transcript.isEmpty ? "録音後、ここに文字起こし結果が表示されます" : viewModel.transcript)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled).padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding()
        .navigationTitle("インタビュー")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("強制終了", role: .destructive) {
                    isShowingEndConfirmation = true
                }
            }
        }
        .confirmationDialog("インタビューを終了しますか？", isPresented: $isShowingEndConfirmation,
                            titleVisibility: .visible) {
            Button("終了する", role: .destructive) {
                viewModel.forceEndInterview()
                dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("録音中の場合は保存・送信せずに破棄します。")
        }
        .alert("エラー", isPresented: $viewModel.isShowingError) {
            Button("OK", role: .cancel) {}
        } message: { Text(viewModel.errorMessage) }
    }
}
