import Foundation
import Metal
import MLXLLM
import MLXLMCommon

enum PostProcessingError: Error {
    case notLoaded
    case formatFailed(String)
    case metalUnavailable
}

actor PostProcessingEngine {
    private var model: ModelContainer?

    var isLoaded: Bool { model != nil }

    func load(onProgress: @escaping (Double) -> Void) async throws {
        // Guard: MLX requires Metal GPU + its metallib bundled in the app.
        // If Metal is unavailable the MLX C++ layer calls abort(), which
        // cannot be caught in Swift, so we check before touching any MLX API.
        guard MTLCreateSystemDefaultDevice() != nil,
              Bundle.main.path(forResource: "default", ofType: "metallib") != nil
        else {
            print("[Murmur] Metal default library not available — skipping LLM post-processing")
            throw PostProcessingError.metalUnavailable
        }

        let config = ModelConfiguration(id: "mlx-community/Qwen3-1.7B-4bit")
        let container = try await LLMModelFactory.shared.loadContainer(
            configuration: config,
            progressHandler: { progress in
                onProgress(progress.fractionCompleted)
            }
        )
        self.model = container
    }

    func format(_ rawText: String) async throws -> String {
        guard let model else {
            throw PostProcessingError.notLoaded
        }
        let prompt = "你是一個文字格式化助手。將以下語音辨識文字加上正確的中文標點符號，不要在中文字之間加空格，不要更改內容。只輸出格式化後的文字。\n輸入：\(rawText)\n輸出："
        let session = ChatSession(model)
        let result = try await session.respond(to: prompt)
        let stripped = result.replacingOccurrences(
            of: "<think>[\\s\\S]*?</think>",
            with: "",
            options: .regularExpression
        )
        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
