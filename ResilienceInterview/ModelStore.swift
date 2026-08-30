import Foundation

struct ModelStore {
    func defaultModelURL() -> URL? {
        Bundle.main.url(forResource: "ggml-small", withExtension: "bin", subdirectory: "Models")
            ?? Bundle.main.url(forResource: "ggml-small", withExtension: "bin")
            ?? findBundledModelRecursively()
    }

    private func findBundledModelRecursively() -> URL? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        return FileManager.default
            .enumerator(at: resourceURL, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .first { $0.lastPathComponent == "ggml-small.bin" }
    }
}
