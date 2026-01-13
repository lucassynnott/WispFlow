import Foundation
import LlamaSwift

/// Manages local LLM loading and text generation for text cleanup
/// Uses llama.cpp backend for inference via llama.swift
@MainActor
final class LLMManager: ObservableObject {
    
    // MARK: - Types
    
    /// Available LLM model sizes
    enum ModelSize: String, CaseIterable, Identifiable {
        case qwen1_5b = "qwen1.5b"
        case phi3_mini = "phi3-mini"
        case gemma2b = "gemma-2b"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .qwen1_5b: return "Qwen 2.5 1.5B (~1GB)"
            case .phi3_mini: return "Phi-3 Mini 3.8B (~2GB)"
            case .gemma2b: return "Gemma 2B (~1.4GB)"
            }
        }
        
        var description: String {
            switch self {
            case .qwen1_5b: return "Small but capable model. Good balance of speed and quality."
            case .phi3_mini: return "High quality model from Microsoft. Excellent for text cleanup."
            case .gemma2b: return "Google's Gemma model. Fast and efficient."
            }
        }
        
        /// Hugging Face model ID
        var huggingFaceID: String {
            switch self {
            case .qwen1_5b: return "Qwen/Qwen2.5-1.5B-Instruct-GGUF"
            case .phi3_mini: return "microsoft/Phi-3-mini-4k-instruct-gguf"
            case .gemma2b: return "google/gemma-2b-it-GGUF"
            }
        }
        
        /// GGUF filename
        var ggufFilename: String {
            switch self {
            case .qwen1_5b: return "qwen2.5-1.5b-instruct-q4_k_m.gguf"
            case .phi3_mini: return "Phi-3-mini-4k-instruct-q4.gguf"
            case .gemma2b: return "gemma-2b-it.Q4_K_M.gguf"
            }
        }
    }
    
    /// Model status
    enum ModelStatus: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case downloaded
        case loading
        case ready
        case error(String)
        
        var isAvailable: Bool {
            if case .ready = self { return true }
            return false
        }
    }
    
    /// Cleanup status
    enum CleanupStatus: Equatable {
        case idle
        case processing
        case completed(String)
        case error(String)
    }
    
    // MARK: - Constants
    
    private struct Constants {
        static let selectedModelKey = "selectedLLMModel"
        static let llmEnabledKey = "llmCleanupEnabled"
        static let contextSize: UInt32 = 2048
        static let batchSize: Int32 = 512
        static let maxTokens: Int = 256
    }
    
    /// System prompt for text cleanup
    static let cleanupSystemPrompt = """
    You are a text cleanup assistant. Your task is to improve transcribed speech by:
    1. Removing filler words (um, uh, like, you know, etc.)
    2. Fixing grammar and punctuation
    3. Maintaining the original meaning and intent
    4. Keeping a natural conversational tone
    5. NOT adding new information or changing the meaning
    
    Important rules:
    - Only return the cleaned text, nothing else
    - Do not add explanations or commentary
    - If the input is very short, just clean it and return
    - Preserve technical terms and proper nouns
    """
    
    // MARK: - Properties
    
    /// Currently selected model size
    @Published var selectedModel: ModelSize {
        didSet {
            UserDefaults.standard.set(selectedModel.rawValue, forKey: Constants.selectedModelKey)
        }
    }
    
    /// Status of the current model
    @Published private(set) var modelStatus: ModelStatus = .notDownloaded
    
    /// Current cleanup status
    @Published private(set) var cleanupStatus: CleanupStatus = .idle
    
    /// Download progress for current model (0.0 to 1.0)
    @Published private(set) var downloadProgress: Double = 0.0
    
    /// Status messages for UI display
    @Published private(set) var statusMessage: String = "No LLM model loaded"
    
    /// Whether LLM cleanup is enabled
    @Published var isLLMEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isLLMEnabled, forKey: Constants.llmEnabledKey)
        }
    }
    
    /// llama.cpp model instance (opaque pointer)
    private var llamaModel: OpaquePointer?
    
    /// llama.cpp context instance (opaque pointer)
    private var llamaContext: OpaquePointer?
    
    /// LLM models directory
    private var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDir = appSupport.appendingPathComponent("WispFlow/LLMModels", isDirectory: true)
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        return modelsDir
    }
    
    // MARK: - Callbacks
    
    /// Called when cleanup completes
    var onCleanupComplete: ((String) -> Void)?
    
    /// Called when an error occurs
    var onError: ((String) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        // Load saved preferences
        if let savedModel = UserDefaults.standard.string(forKey: Constants.selectedModelKey),
           let model = ModelSize(rawValue: savedModel) {
            selectedModel = model
        } else {
            selectedModel = .qwen1_5b // Default to Qwen 1.5B
        }
        
        // Load LLM enabled preference (default to true)
        isLLMEnabled = UserDefaults.standard.object(forKey: Constants.llmEnabledKey) as? Bool ?? true
        
        // Check if model is already downloaded
        if isModelDownloaded(selectedModel) {
            modelStatus = .downloaded
            statusMessage = "\(selectedModel.displayName) available"
        }
        
        print("LLMManager initialized with model: \(selectedModel.rawValue), enabled: \(isLLMEnabled)")
    }
    
    deinit {
        // Free llama resources directly in deinit (can't call actor-isolated methods)
        if let context = llamaContext {
            llama_free(context)
        }
        if let model = llamaModel {
            llama_model_free(model)
        }
    }
    
    // MARK: - Model Management
    
    /// Select a different model
    func selectModel(_ model: ModelSize) {
        guard model != selectedModel else { return }
        
        selectedModel = model
        
        // Unload current model
        unloadModel()
        
        // Check if new model is downloaded
        if isModelDownloaded(model) {
            modelStatus = .downloaded
            statusMessage = "\(model.displayName) available"
        } else {
            modelStatus = .notDownloaded
            statusMessage = "Model not downloaded"
        }
        
        print("LLMManager: Selected model \(model.rawValue)")
    }
    
    /// Unload the current model and free resources
    private func unloadModel() {
        if let context = llamaContext {
            llama_free(context)
            llamaContext = nil
        }
        if let model = llamaModel {
            llama_model_free(model)
            llamaModel = nil
        }
    }
    
    /// Check if a model is downloaded
    func isModelDownloaded(_ model: ModelSize) -> Bool {
        let modelPath = modelsDirectory.appendingPathComponent(model.ggufFilename)
        return FileManager.default.fileExists(atPath: modelPath.path)
    }
    
    /// Get the local path for a model
    func modelPath(for model: ModelSize) -> URL {
        return modelsDirectory.appendingPathComponent(model.ggufFilename)
    }
    
    /// Download the selected model from Hugging Face
    func downloadModel() async {
        guard modelStatus != .downloading(progress: 0), modelStatus != .loading else {
            print("LLMManager: Model is already downloading or loading")
            return
        }
        
        modelStatus = .downloading(progress: 0)
        downloadProgress = 0
        statusMessage = "Downloading \(selectedModel.displayName)..."
        
        do {
            // Construct Hugging Face download URL
            let urlString = "https://huggingface.co/\(selectedModel.huggingFaceID)/resolve/main/\(selectedModel.ggufFilename)"
            guard let url = URL(string: urlString) else {
                throw NSError(domain: "LLMManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL"])
            }
            
            let destinationURL = modelPath(for: selectedModel)
            
            // Remove existing file if present (in case of interrupted download)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            print("LLMManager: Downloading from \(urlString)")
            
            // Download the file with progress tracking using URLSessionDownloadDelegate
            let (tempURL, response) = try await downloadWithProgress(from: url)
            
            // Check for valid response
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                throw NSError(domain: "LLMManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Download failed with HTTP error \(statusCode)"])
            }
            
            // Move downloaded file to destination
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)
            
            modelStatus = .downloaded
            downloadProgress = 1.0
            statusMessage = "\(selectedModel.displayName) downloaded"
            print("LLMManager: Model downloaded successfully to \(destinationURL.path)")
            
        } catch {
            let errorMessage = "Download failed: \(error.localizedDescription)"
            modelStatus = .error(errorMessage)
            statusMessage = errorMessage
            downloadProgress = 0
            print("LLMManager: \(errorMessage)")
            onError?(errorMessage)
        }
    }
    
    /// Download file with progress tracking
    private func downloadWithProgress(from url: URL) async throws -> (URL, URLResponse) {
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = DownloadProgressDelegate { [weak self] progress in
                Task { @MainActor in
                    self?.downloadProgress = progress
                    self?.modelStatus = .downloading(progress: progress)
                    self?.statusMessage = "Downloading... \(Int(progress * 100))%"
                }
            }
            
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let task = session.downloadTask(with: url) { tempURL, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let tempURL = tempURL, let response = response {
                    // Copy temp file to a stable location before returning
                    let stableURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    do {
                        try FileManager.default.copyItem(at: tempURL, to: stableURL)
                        continuation.resume(returning: (stableURL, response))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                } else {
                    continuation.resume(throwing: NSError(domain: "LLMManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unknown download error"]))
                }
            }
            task.resume()
        }
    }
    
    /// Load the selected model
    func loadModel() async {
        guard modelStatus != .loading else {
            print("LLMManager: Model is already loading")
            return
        }
        
        // Download if not available
        if !isModelDownloaded(selectedModel) {
            await downloadModel()
        }
        
        guard isModelDownloaded(selectedModel) else {
            let errorMessage = "Model not downloaded"
            modelStatus = .error(errorMessage)
            statusMessage = errorMessage
            onError?(errorMessage)
            return
        }
        
        modelStatus = .loading
        statusMessage = "Loading \(selectedModel.displayName)..."
        
        // Run heavy loading on background thread
        let modelURL = modelPath(for: selectedModel)
        
        do {
            // Load model on background thread
            let result = try await Task.detached {
                return try self.loadLlamaModel(at: modelURL)
            }.value
            
            self.llamaModel = result.model
            self.llamaContext = result.context
            
            modelStatus = .ready
            statusMessage = "\(selectedModel.displayName) ready"
            print("LLMManager: Model loaded successfully")
            
        } catch {
            let errorMessage = "Failed to load model: \(error.localizedDescription)"
            modelStatus = .error(errorMessage)
            statusMessage = errorMessage
            unloadModel()
            print("LLMManager: \(errorMessage)")
            onError?(errorMessage)
        }
    }
    
    /// Load llama.cpp model (runs on background thread)
    private nonisolated func loadLlamaModel(at url: URL) throws -> (model: OpaquePointer, context: OpaquePointer) {
        // Initialize llama backend
        llama_backend_init()
        
        // Load model
        var modelParams = llama_model_default_params()
        guard let model = llama_model_load_from_file(url.path, modelParams) else {
            throw NSError(domain: "LLMManager", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to load model file"])
        }
        
        // Create context
        var contextParams = llama_context_default_params()
        contextParams.n_ctx = Constants.contextSize
        contextParams.n_batch = UInt32(Constants.batchSize)
        
        guard let context = llama_init_from_model(model, contextParams) else {
            llama_model_free(model)
            throw NSError(domain: "LLMManager", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to create model context"])
        }
        
        return (model, context)
    }
    
    /// Delete a downloaded model
    func deleteModel(_ model: ModelSize) {
        let modelPath = self.modelPath(for: model)
        
        do {
            if FileManager.default.fileExists(atPath: modelPath.path) {
                try FileManager.default.removeItem(at: modelPath)
                print("LLMManager: Deleted model \(model.rawValue)")
                
                // If this was the active model, reset status
                if model == selectedModel {
                    unloadModel()
                    modelStatus = .notDownloaded
                    statusMessage = "Model deleted"
                }
            }
        } catch {
            print("LLMManager: Failed to delete model: \(error)")
        }
    }
    
    /// Get list of downloaded models
    func getDownloadedModels() -> [ModelSize] {
        return ModelSize.allCases.filter { isModelDownloaded($0) }
    }
    
    // MARK: - Text Cleanup
    
    /// Clean up transcribed text using the LLM
    /// - Parameter text: Raw transcribed text
    /// - Returns: Cleaned text or nil if LLM unavailable
    func cleanupText(_ text: String) async -> String? {
        guard isLLMEnabled else {
            print("LLMManager: LLM cleanup disabled")
            return nil
        }
        
        guard let model = llamaModel, let context = llamaContext, modelStatus == .ready else {
            print("LLMManager: Model not ready for cleanup")
            return nil
        }
        
        // Skip very short text
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.count > 5 else {
            print("LLMManager: Text too short for LLM cleanup")
            return nil
        }
        
        cleanupStatus = .processing
        statusMessage = "Cleaning up text..."
        
        print("LLMManager: Starting LLM cleanup for: \(trimmedText)")
        
        // Create prompt
        let prompt = """
        <|system|>
        \(Self.cleanupSystemPrompt)
        </s>
        <|user|>
        Clean up this transcribed speech:
        
        \(trimmedText)
        </s>
        <|assistant|>
        """
        
        do {
            // Run generation on background thread
            let result = try await Task.detached { [model, context] in
                return try self.generateText(prompt: prompt, model: model, context: context)
            }.value
            
            // Clean up the result
            let cleanedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Validate result
            guard !cleanedResult.isEmpty, cleanedResult.count > 2 else {
                print("LLMManager: LLM returned empty or invalid result")
                cleanupStatus = .error("Invalid LLM response")
                return nil
            }
            
            cleanupStatus = .completed(cleanedResult)
            statusMessage = "Cleanup complete"
            print("LLMManager: Cleanup result: \(cleanedResult)")
            
            onCleanupComplete?(cleanedResult)
            return cleanedResult
            
        } catch {
            let errorMessage = "LLM cleanup failed: \(error.localizedDescription)"
            cleanupStatus = .error(errorMessage)
            statusMessage = errorMessage
            print("LLMManager: \(errorMessage)")
            onError?(errorMessage)
            return nil
        }
    }
    
    /// Generate text using llama.cpp (runs on background thread)
    private nonisolated func generateText(prompt: String, model: OpaquePointer, context: OpaquePointer) throws -> String {
        let vocab = llama_model_get_vocab(model)
        
        // Tokenize the prompt
        let utf8Count = prompt.utf8.count
        let maxTokenCount = utf8Count + 1
        var tokens = [llama_token](repeating: 0, count: maxTokenCount)
        
        let tokenCount = llama_tokenize(
            vocab,
            prompt,
            Int32(utf8Count),
            &tokens,
            Int32(maxTokenCount),
            true,  // add BOS
            true   // special tokens
        )
        
        guard tokenCount > 0 else {
            throw NSError(domain: "LLMManager", code: 20, userInfo: [NSLocalizedDescriptionKey: "Failed to tokenize prompt"])
        }
        
        let promptTokens = Array(tokens.prefix(Int(tokenCount)))
        
        // Create batch
        var batch = llama_batch_init(Int32(Constants.batchSize), 0, 1)
        defer { llama_batch_free(batch) }
        
        // Prepare batch with prompt tokens
        batch.n_tokens = Int32(promptTokens.count)
        
        for i in 0..<promptTokens.count {
            batch.token[i] = promptTokens[i]
            batch.pos[i] = Int32(i)
            batch.n_seq_id[i] = 1
            
            if let seq_ids = batch.seq_id, let seq_id = seq_ids[i] {
                seq_id[0] = 0
            }
            
            batch.logits[i] = 0
        }
        
        // Only compute logits for the last token
        if batch.n_tokens > 0 {
            batch.logits[Int(batch.n_tokens) - 1] = 1
        }
        
        // Decode the prompt
        guard llama_decode(context, batch) == 0 else {
            throw NSError(domain: "LLMManager", code: 21, userInfo: [NSLocalizedDescriptionKey: "llama_decode failed"])
        }
        
        // Generate tokens
        var generatedText = ""
        var n_cur = batch.n_tokens
        let eosToken = llama_vocab_eos(vocab)
        
        for _ in 0..<Constants.maxTokens {
            // Get logits for the last token
            guard let logits = llama_get_logits_ith(context, batch.n_tokens - 1) else {
                break
            }
            
            // Simple greedy sampling
            let vocabSize = llama_vocab_n_tokens(vocab)
            var maxLogit = logits[0]
            var nextToken: llama_token = 0
            
            for i in 1..<Int(vocabSize) {
                if logits[i] > maxLogit {
                    maxLogit = logits[i]
                    nextToken = llama_token(i)
                }
            }
            
            // Check for EOS
            if nextToken == eosToken {
                break
            }
            
            // Convert token to text
            var buffer = [CChar](repeating: 0, count: 32)
            let length = llama_token_to_piece(
                vocab,
                nextToken,
                &buffer,
                Int32(buffer.count),
                0,
                false
            )
            
            if length > 0 {
                let tokenText = String(cString: buffer)
                generatedText += tokenText
            }
            
            // Prepare batch for next token
            batch.n_tokens = 1
            batch.token[0] = nextToken
            batch.pos[0] = n_cur
            batch.n_seq_id[0] = 1
            
            if let seq_ids = batch.seq_id, let seq_id = seq_ids[0] {
                seq_id[0] = 0
            }
            
            batch.logits[0] = 1
            n_cur += 1
            
            // Decode
            guard llama_decode(context, batch) == 0 else {
                break
            }
        }
        
        return generatedText
    }
    
    /// Reset cleanup status to idle
    func resetStatus() {
        cleanupStatus = .idle
        if modelStatus == .ready {
            statusMessage = "\(selectedModel.displayName) ready"
        }
    }
    
    // MARK: - Status
    
    /// Check if the manager is ready for text cleanup
    var isReady: Bool {
        return modelStatus == .ready && llamaModel != nil && llamaContext != nil && isLLMEnabled
    }
}

// MARK: - Download Progress Delegate

private class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    private let progressHandler: (Double) -> Void
    
    init(progressHandler: @escaping (Double) -> Void) {
        self.progressHandler = progressHandler
        super.init()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            progressHandler(progress)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Handled in the completion handler
    }
}
