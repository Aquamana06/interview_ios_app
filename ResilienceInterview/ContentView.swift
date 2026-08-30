import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: TranscriptionViewModel

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
        .alert("エラー", isPresented: $viewModel.isShowingError) {
            Button("OK", role: .cancel) {}
        } message: { Text(viewModel.errorMessage) }
    }
}
