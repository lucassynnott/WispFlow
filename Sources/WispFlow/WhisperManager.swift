import Foundation
import WhisperKit

/// Manages Whisper model loading and audio transcription
/// Handles model download, selection, and transcription pipeline
@MainActor
final class WhisperManager: ObservableObject {
    
    // MARK: - Types
    
    /// Available Whisper model sizes
    enum ModelSize: String, CaseIterable, Identifiable {
        case tiny = "tiny"
        case base = "base"
        case small = "small"
        case medium = "medium"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .tiny: return "Tiny (~75MB, fastest)"
            case .base: return "Base (~145MB, fast)"
            case .small: return "Small (~485MB, balanced)"
            case .medium: return "Medium (~1.5GB, accurate)"
            }
        }
        
        var description: String {
            switch self {
            case .tiny: return "Fastest, lower accuracy. Good for quick notes."
            case .base: return "Fast with decent accuracy. Good balance for most uses."
            case .small: return "Good accuracy, moderate speed. Recommended for general use."
            case .medium: return "High accuracy, slower. Best for important transcriptions."
            }
        }
        
        /// The model name pattern for WhisperKit
        var modelPattern: String {
            return "openai_whisper-\(rawValue)"
        }
    }
    
    /// Transcription status
    enum TranscriptionStatus: Equatable {
        case idle
        case loading
        case transcribing
        case completed(String)
        case error(String)
        
        var isProcessing: Bool {
            switch self {
            case .loading, .transcribing:
                return true
            default:
                return false
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
    }
    
    // MARK: - Constants
    
    private struct Constants {
        static let selectedModelKey = "selectedWhisperModel"
        static let modelRepo = "argmaxinc/whisperkit-coreml"
    }
    
    // MARK: - Properties
    
    /// The WhisperKit pipeline instance
    private var whisperKit: WhisperKit?
    
    /// Currently selected model size
    @Published private(set) var selectedModel: ModelSize
    
    /// Status of the current model
    @Published private(set) var modelStatus: ModelStatus = .notDownloaded
    
    /// Current transcription status
    @Published private(set) var transcriptionStatus: TranscriptionStatus = .idle
    
    /// Download progress for current model (0.0 to 1.0)
    @Published private(set) var downloadProgress: Double = 0.0
    
    /// Status messages for UI display
    @Published private(set) var statusMessage: String = "No model loaded"
    
    /// Model download and caching directory
    private var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDir = appSupport.appendingPathComponent("WispFlow/Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        return modelsDir
    }
    
    // MARK: - Callbacks
    
    /// Called when transcription completes
    var onTranscriptionComplete: ((String) -> Void)?
    
    /// Called when an error occurs
    var onError: ((String) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        // Load saved model preference
        if let savedModel = UserDefaults.standard.string(forKey: Constants.selectedModelKey),
           let model = ModelSize(rawValue: savedModel) {
            selectedModel = model
        } else {
            selectedModel = .base // Default to base model
        }
        
        print("WhisperManager initialized with model: \(selectedModel.rawValue)")
    }
    
    // MARK: - Model Management
    
    /// Select a different model size
    func selectModel(_ model: ModelSize) async {
        guard model != selectedModel || modelStatus != .ready else { return }
        
        selectedModel = model
        UserDefaults.standard.set(model.rawValue, forKey: Constants.selectedModelKey)
        
        // Unload current model
        whisperKit = nil
        modelStatus = .notDownloaded
        statusMessage = "Model changed to \(model.displayName)"
        
        print("WhisperManager: Selected model \(model.rawValue)")
    }
    
    /// Load the selected model (downloads if necessary)
    func loadModel() async {
        guard modelStatus != .ready && modelStatus != .loading else {
            print("WhisperManager: Model already loaded or loading")
            return
        }
        
        modelStatus = .loading
        statusMessage = "Loading \(selectedModel.displayName)..."
        
        do {
            print("WhisperManager: Starting model load for \(selectedModel.rawValue)")
            
            // Configure WhisperKit with progress callback
            let config = WhisperKitConfig(
                model: selectedModel.modelPattern,
                downloadBase: modelsDirectory,
                verbose: true,
                prewarm: true
            )
            
            // Initialize WhisperKit (this downloads if needed)
            whisperKit = try await WhisperKit(config)
            
            modelStatus = .ready
            statusMessage = "\(selectedModel.displayName) ready"
            print("WhisperManager: Model loaded successfully")
            
        } catch {
            let errorMessage = "Failed to load model: \(error.localizedDescription)"
            modelStatus = .error(errorMessage)
            statusMessage = errorMessage
            print("WhisperManager: \(errorMessage)")
            onError?(errorMessage)
        }
    }
    
    /// Check if a model is downloaded
    func isModelDownloaded(_ model: ModelSize) -> Bool {
        let modelPath = modelsDirectory.appendingPathComponent(model.modelPattern)
        return FileManager.default.fileExists(atPath: modelPath.path)
    }
    
    /// Delete a downloaded model
    func deleteModel(_ model: ModelSize) async {
        let modelPath = modelsDirectory.appendingPathComponent(model.modelPattern)
        
        do {
            if FileManager.default.fileExists(atPath: modelPath.path) {
                try FileManager.default.removeItem(at: modelPath)
                print("WhisperManager: Deleted model \(model.rawValue)")
                
                // If this was the active model, reset status
                if model == selectedModel {
                    whisperKit = nil
                    modelStatus = .notDownloaded
                    statusMessage = "Model deleted"
                }
            }
        } catch {
            print("WhisperManager: Failed to delete model: \(error)")
        }
    }
    
    /// Get list of downloaded models
    func getDownloadedModels() -> [ModelSize] {
        return ModelSize.allCases.filter { isModelDownloaded($0) }
    }
    
    // MARK: - Transcription
    
    /// Transcribe audio data
    /// - Parameters:
    ///   - audioData: Raw audio data (Float32 samples at 16kHz)
    ///   - sampleRate: Sample rate of the audio (should be 16000)
    /// - Returns: Transcribed text or nil if failed
    func transcribe(audioData: Data, sampleRate: Double = 16000.0) async -> String? {
        // Ensure model is loaded
        guard let whisper = whisperKit else {
            statusMessage = "Model not loaded"
            transcriptionStatus = .error("Model not loaded. Please load a model first.")
            onError?("Model not loaded")
            return nil
        }
        
        guard !audioData.isEmpty else {
            statusMessage = "No audio to transcribe"
            transcriptionStatus = .error("No audio data provided")
            return nil
        }
        
        transcriptionStatus = .transcribing
        statusMessage = "Transcribing..."
        
        do {
            // Convert Data to [Float] samples
            let samples = audioData.withUnsafeBytes { buffer -> [Float] in
                let floatBuffer = buffer.bindMemory(to: Float.self)
                return Array(floatBuffer)
            }
            
            print("WhisperManager: Transcribing \(samples.count) samples (\(Double(samples.count) / sampleRate)s)")
            
            // Perform transcription
            let results = try await whisper.transcribe(audioArray: samples)
            
            // Extract text from results (WhisperKit returns an array of TranscriptionResult)
            let transcribedText = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            
            if transcribedText.isEmpty {
                transcriptionStatus = .completed("")
                statusMessage = "No speech detected"
                print("WhisperManager: No speech detected in audio")
                return ""
            }
            
            transcriptionStatus = .completed(transcribedText)
            statusMessage = "Transcription complete"
            print("WhisperManager: Transcription result: \(transcribedText)")
            
            onTranscriptionComplete?(transcribedText)
            return transcribedText
            
        } catch {
            let errorMessage = "Transcription failed: \(error.localizedDescription)"
            transcriptionStatus = .error(errorMessage)
            statusMessage = errorMessage
            print("WhisperManager: \(errorMessage)")
            onError?(errorMessage)
            return nil
        }
    }
    
    /// Reset transcription status to idle
    func resetStatus() {
        transcriptionStatus = .idle
        if modelStatus == .ready {
            statusMessage = "\(selectedModel.displayName) ready"
        }
    }
    
    // MARK: - Status
    
    /// Check if the manager is ready to transcribe
    var isReady: Bool {
        return modelStatus == .ready && whisperKit != nil
    }
}
