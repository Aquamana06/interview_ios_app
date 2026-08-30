import Foundation

struct ModelStore {
    func defaultModelURL() -> URL? {
        Bundle.main.url(forResource: "ggml-small", withExtension: "bin", subdirectory: "Models")
            ?? Bundle.main.url(forResource: "ggml-small", withExtension: "bin")
    }
}
