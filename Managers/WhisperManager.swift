//
//  WhisperManager.swift
//  FloRight
//
//  Handles WhisperKit integration for speech-to-text
//

import Foundation
import WhisperKit

class WhisperManager: ObservableObject, @unchecked Sendable {
    private var whisperKit: WhisperKit?
    @Published var isLoading = true
    @Published var isInitialized = false
    
    init() {
        Task {
            await setupWhisperKit()
        }
    }
    
    // MARK: - Simplified Neural Engine Setup
    
    private func setupWhisperKit() async {
        print("🤖 [WHISPERKIT] 🚀 Initializing WhisperKit with small.en...")
        
        await MainActor.run {
            self.isLoading = true
        }
        
        // Primary: Try small.en with Neural Engine
        do {
            print("🤖 [WHISPERKIT] ⚡ Setting up small.en with Neural Engine...")
            
            let primaryConfig = WhisperKitConfig(
                model: "small.en",
                computeOptions: ModelComputeOptions(
                    audioEncoderCompute: .cpuAndNeuralEngine,
                    textDecoderCompute: .cpuAndNeuralEngine
                ),
                verbose: false,
                prewarm: true
            )
            
            let kit = try await WhisperKit(primaryConfig)
            self.whisperKit = kit
            
            await MainActor.run {
                self.isInitialized = true
                self.isLoading = false
            }
            
            print("🤖 [WHISPERKIT] ✅ small.en with Neural Engine ready!")
            return
            
        } catch {
            print("🤖 [WHISPERKIT] ⚠️ small.en Neural Engine failed: \(error)")
            print("🤖 [WHISPERKIT] 🔄 Attempting CPU fallback...")
        }
        
        // Fallback: Try small.en with CPU only
        do {
            print("🤖 [WHISPERKIT] 🔄 Setting up small.en with CPU only...")
            
            let fallbackConfig = WhisperKitConfig(
                model: "small.en",
                computeOptions: ModelComputeOptions(
                    audioEncoderCompute: .cpuOnly,
                    textDecoderCompute: .cpuOnly
                ),
                verbose: false,
                prewarm: true
            )
            
            let kit = try await WhisperKit(fallbackConfig)
            self.whisperKit = kit
            
            await MainActor.run {
                self.isInitialized = true
                self.isLoading = false
            }
            
            print("🤖 [WHISPERKIT] ✅ small.en with CPU ready!")
            
        } catch {
            print("🤖 [WHISPERKIT] ❌ Setup failed: \(error)")
            print("🤖 [WHISPERKIT] 📝 Error details: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
                self.isInitialized = false
            }
        }
    }
    

    
    // CORRECT API: Based on actual WhisperKit v0.6.0+ implementation
    func transcribe(audioURL: URL) async -> String {
        guard let whisperKit = whisperKit else {
            print("🤖 [WHISPERKIT] ⚠️ WhisperKit not initialized")
            return "WhisperKit not initialized"
        }
        
        // START TIMING
        let startTime = CFAbsoluteTimeGetCurrent()
        let audioPath = audioURL.path
        
        print("🤖 [WHISPERKIT] 🎤 Starting transcription: \(audioURL.lastPathComponent)")
        print("🤖 [WHISPERKIT] ⏱️ Start time: \(String(format: "%.3f", startTime))")
        
        // Get file info for benchmarking
        var fileSize: Int64 = 0
        var estimatedDuration: Double = 0
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: audioPath)
            fileSize = attributes[.size] as? Int64 ?? 0
            // Estimate duration: 44.1kHz, 16-bit, mono = ~88KB per second
            estimatedDuration = Double(fileSize) / (44100.0 * 2)
            
            print("🤖 [WHISPERKIT] 📊 Audio file size: \(fileSize) bytes")
            print("🤖 [WHISPERKIT] 📊 Estimated duration: \(String(format: "%.2f", estimatedDuration))s")
        } catch {
            print("🤖 [WHISPERKIT] ⚠️ Could not get file info: \(error)")
        }
        
        do {
            // CORRECT API: transcribe(audioPath: String) async throws -> [TranscriptionResult]
            let results: [TranscriptionResult] = try await whisperKit.transcribe(audioPath: audioPath)
            
            // END TIMING
            let endTime = CFAbsoluteTimeGetCurrent()
            let processingTime = endTime - startTime
            
            // CORRECT: Extract text from array of results
            let fullText = results.map { $0.text }.joined(separator: " ")
            
            // Clean up the transcription
            let cleanText = fullText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "  ", with: " ") // Remove double spaces
            
            // PERFORMANCE BENCHMARK LOGGING
            print("🤖 [WHISPERKIT] ⏱️ ===== PERFORMANCE BENCHMARK =====")
            print("🤖 [WHISPERKIT] ⏱️ Processing time: \(String(format: "%.3f", processingTime))s")
            print("🤖 [WHISPERKIT] ⏱️ Audio duration: ~\(String(format: "%.2f", estimatedDuration))s")
            if estimatedDuration > 0 {
                let realTimeRatio = estimatedDuration / processingTime
                print("🤖 [WHISPERKIT] ⏱️ Real-time factor: \(String(format: "%.2f", realTimeRatio))x (higher = faster)")
            }
            print("🤖 [WHISPERKIT] ⏱️ Text length: \(cleanText.count) characters")
            print("🤖 [WHISPERKIT] ⏱️ Words transcribed: \(cleanText.split(separator: " ").count)")
            if cleanText.count > 0 {
                let charsPerSecond = Double(cleanText.count) / processingTime
                print("🤖 [WHISPERKIT] ⏱️ Transcription speed: \(String(format: "%.1f", charsPerSecond)) chars/sec")
            }
            print("🤖 [WHISPERKIT] ⏱️ =================================")
            
            if cleanText.isEmpty {
                print("🤖 [WHISPERKIT] ⚠️ Empty transcription - audio might be too quiet")
                return "[No speech detected - try speaking louder]"
            }
            
            print("🤖 [WHISPERKIT] ✅ Transcription complete: \"\(cleanText)\"")
            return cleanText
            
        } catch {
            // END TIMING (for errors too)
            let endTime = CFAbsoluteTimeGetCurrent()
            let processingTime = endTime - startTime
            
            print("🤖 [WHISPERKIT] ❌ Transcription failed after \(String(format: "%.3f", processingTime))s: \(error)")
            return "Transcription error: \(error.localizedDescription)"
        }
    }
    
    // Model information
    var modelInfo: String {
        guard isInitialized else { return "Not initialized" }
        return "WhisperKit with small.en (optimized accuracy)"
    }
    
    deinit {
        whisperKit = nil
        print("🤖 [WHISPERKIT] 🗑️ WhisperManager deallocated")
    }
}

// MARK: - WhisperKitError
enum WhisperKitError: Error, LocalizedError {
    case notInitialized
    case transcriptionFailed(String)
    case configurationFailed(String)
    case modelNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "WhisperKit not initialized"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .configurationFailed(let message):
            return "Configuration failed: \(message)"
        case .modelNotFound(let message):
            return "Model not found: \(message)"

        }
    }
}
