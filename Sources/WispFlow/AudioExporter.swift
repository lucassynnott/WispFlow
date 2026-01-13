import Foundation
import AppKit

/// Utility for exporting audio data to WAV file format
/// Converts Float32 PCM audio data to standard WAV format
final class AudioExporter {
    
    // MARK: - Types
    
    /// WAV export result
    enum ExportResult {
        case success(URL)
        case noAudioData
        case exportFailed(String)
    }
    
    // MARK: - WAV Header Constants
    
    private struct WAVHeader {
        static let riffChunkID: [UInt8] = [0x52, 0x49, 0x46, 0x46] // "RIFF"
        static let waveFormat: [UInt8] = [0x57, 0x41, 0x56, 0x45]   // "WAVE"
        static let fmtChunkID: [UInt8] = [0x66, 0x6D, 0x74, 0x20]   // "fmt "
        static let dataChunkID: [UInt8] = [0x64, 0x61, 0x74, 0x61]  // "data"
        static let pcmFormat: UInt16 = 1       // PCM = 1
        static let bitsPerSample: UInt16 = 16  // 16-bit audio
    }
    
    // MARK: - Singleton
    
    static let shared = AudioExporter()
    
    private init() {}
    
    // MARK: - Export Methods
    
    /// Export Float32 audio data to WAV file
    /// - Parameters:
    ///   - audioData: Raw Float32 audio samples as Data
    ///   - sampleRate: Sample rate of the audio (e.g., 16000)
    ///   - url: Destination URL for the WAV file
    /// - Returns: Export result
    func exportToWAV(audioData: Data, sampleRate: Double, to url: URL) -> ExportResult {
        guard !audioData.isEmpty else {
            return .noAudioData
        }
        
        // Convert Float32 samples to Int16 (16-bit PCM)
        let float32Samples = audioData.withUnsafeBytes { buffer -> [Float] in
            let floatBuffer = buffer.bindMemory(to: Float.self)
            return Array(floatBuffer)
        }
        
        guard !float32Samples.isEmpty else {
            return .noAudioData
        }
        
        // Convert to 16-bit signed integer samples
        let int16Samples = float32Samples.map { sample -> Int16 in
            // Clamp to [-1.0, 1.0] range
            let clampedSample = max(-1.0, min(1.0, sample))
            // Scale to Int16 range
            return Int16(clampedSample * Float(Int16.max))
        }
        
        // Create WAV data
        guard let wavData = createWAVData(samples: int16Samples, sampleRate: UInt32(sampleRate)) else {
            return .exportFailed("Failed to create WAV data")
        }
        
        // Write to file
        do {
            try wavData.write(to: url)
            print("AudioExporter: Successfully exported \(float32Samples.count) samples to \(url.path)")
            return .success(url)
        } catch {
            return .exportFailed("Failed to write WAV file: \(error.localizedDescription)")
        }
    }
    
    /// Show save panel and export audio to WAV
    /// - Parameters:
    ///   - audioData: Raw Float32 audio samples as Data
    ///   - sampleRate: Sample rate of the audio
    ///   - completion: Called with the result
    func exportWithSavePanel(audioData: Data, sampleRate: Double, completion: @escaping (ExportResult) -> Void) {
        guard !audioData.isEmpty else {
            completion(.noAudioData)
            return
        }
        
        DispatchQueue.main.async {
            let savePanel = NSSavePanel()
            savePanel.title = "Export Audio as WAV"
            savePanel.nameFieldStringValue = self.generateDefaultFilename()
            savePanel.allowedContentTypes = [.wav]
            savePanel.canCreateDirectories = true
            savePanel.message = "Choose a location to save the audio recording"
            
            savePanel.begin { [weak self] response in
                guard let self = self else { return }
                
                if response == .OK, let url = savePanel.url {
                    let result = self.exportToWAV(audioData: audioData, sampleRate: sampleRate, to: url)
                    completion(result)
                } else {
                    // User cancelled
                    completion(.exportFailed("Export cancelled"))
                }
            }
        }
    }
    
    // MARK: - WAV Creation
    
    /// Create WAV file data from Int16 samples
    private func createWAVData(samples: [Int16], sampleRate: UInt32) -> Data? {
        let numChannels: UInt16 = 1  // Mono
        let bitsPerSample = WAVHeader.bitsPerSample
        let byteRate = sampleRate * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        
        // Calculate sizes
        let dataSize = UInt32(samples.count * Int(bitsPerSample / 8))
        let fmtChunkSize: UInt32 = 16  // PCM format chunk is always 16 bytes
        let riffChunkSize = 4 + (8 + fmtChunkSize) + (8 + dataSize)  // "WAVE" + fmt chunk + data chunk
        
        var data = Data()
        
        // RIFF header
        data.append(contentsOf: WAVHeader.riffChunkID)           // "RIFF"
        data.append(contentsOf: uint32ToBytes(riffChunkSize))    // File size - 8
        data.append(contentsOf: WAVHeader.waveFormat)            // "WAVE"
        
        // fmt subchunk
        data.append(contentsOf: WAVHeader.fmtChunkID)            // "fmt "
        data.append(contentsOf: uint32ToBytes(fmtChunkSize))     // Subchunk size (16 for PCM)
        data.append(contentsOf: uint16ToBytes(WAVHeader.pcmFormat)) // Audio format (1 = PCM)
        data.append(contentsOf: uint16ToBytes(numChannels))      // Number of channels
        data.append(contentsOf: uint32ToBytes(sampleRate))       // Sample rate
        data.append(contentsOf: uint32ToBytes(byteRate))         // Byte rate
        data.append(contentsOf: uint16ToBytes(blockAlign))       // Block align
        data.append(contentsOf: uint16ToBytes(bitsPerSample))    // Bits per sample
        
        // data subchunk
        data.append(contentsOf: WAVHeader.dataChunkID)           // "data"
        data.append(contentsOf: uint32ToBytes(dataSize))         // Data size
        
        // Audio samples
        for sample in samples {
            data.append(contentsOf: int16ToBytes(sample))
        }
        
        return data
    }
    
    // MARK: - Byte Conversion Helpers
    
    private func uint32ToBytes(_ value: UInt32) -> [UInt8] {
        return [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 24) & 0xFF)
        ]
    }
    
    private func uint16ToBytes(_ value: UInt16) -> [UInt8] {
        return [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF)
        ]
    }
    
    private func int16ToBytes(_ value: Int16) -> [UInt8] {
        return [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF)
        ]
    }
    
    // MARK: - Helpers
    
    /// Generate a default filename with timestamp
    private func generateDefaultFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        return "WispFlow_Recording_\(timestamp).wav"
    }
}
