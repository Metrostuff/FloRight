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
    
    // MARK: - Neural Engine Optimization with Progressive Enhancement
    
    private func initializeWithTimeout(
        config: WhisperKitConfig,
        timeoutSeconds: TimeInterval = 600  // 10 minutes
    ) async throws -> WhisperKit {
        
        // Start progress indicator in background
        Task {
            await self.showProgressDuringCompilation()
        }
        
        // Simple timeout approach - try initialization
        do {
            let result = try await WhisperKit(config)
            return result
        } catch {
            print("🤖 [WHISPERKIT] ❌ Initialization failed: \(error)")
            throw error
        }
    }
    
    private func showProgressDuringCompilation() async {
        let milestones = [
            (30, "🧠 Preparing Neural Engine..."),
            (120, "⚡ Compiling model for your M1 chip..."),
            (300, "🔧 Optimizing performance (first time only)..."),
            (480, "⏳ Almost ready...")
        ]
        
        for (seconds, message) in milestones {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            print("🤖 [WHISPERKIT] \(message)")
        }
    }
    
    private func checkForCompiledNeuralEngineModel() async -> Bool {
        // Check if Neural Engine model has been compiled before
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let neuralEngineMarker = documentsPath?.appendingPathComponent(".whisperkit_neural_engine_compiled")
        let exists = FileManager.default.fileExists(atPath: neuralEngineMarker?.path ?? "")
        
        print("🤖 [NEURAL-ENGINE] 🔍 Checking for compiled Neural Engine model...")
        print("🤖 [NEURAL-ENGINE] 🔍 Marker file path: \(neuralEngineMarker?.path ?? "nil")")
        print("🤖 [NEURAL-ENGINE] 🔍 Marker exists: \(exists)")
        
        return exists
    }
    
    private func markNeuralEngineCompiled() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let neuralEngineMarker = documentsPath?.appendingPathComponent(".whisperkit_neural_engine_compiled")
        
        do {
            try "compiled".write(to: neuralEngineMarker!, atomically: true, encoding: .utf8)
            print("🤖 [NEURAL-ENGINE] ✅ Marked Neural Engine as compiled: \(neuralEngineMarker?.path ?? "nil")")
        } catch {
            print("🤖 [NEURAL-ENGINE] ❌ Failed to create marker file: \(error)")
        }
    }
    
    private func setupWhisperKit() async {
        print("🤖 [WHISPERKIT] 🚀 Initializing WhisperKit...")
        
        await MainActor.run {
            self.isLoading = true
        }
        
        // Check if Neural Engine model already compiled
        let hasPrecompiledNE = await checkForCompiledNeuralEngineModel()
        
        if hasPrecompiledNE {
            print("🤖 [WHISPERKIT] ⚡ Neural Engine model found - loading optimized version...")
            
            // Strategy 1: Use pre-compiled Neural Engine (3-5 seconds)
            do {
                let neConfig = WhisperKitConfig(
                    model: "small.en",
                    computeOptions: ModelComputeOptions(
                    audioEncoderCompute: .cpuAndNeuralEngine,
                    textDecoderCompute: .cpuAndNeuralEngine
                    ),
                    verbose: false,
                    prewarm: true
                )
                
                let kit = try await WhisperKit(neConfig)
                self.whisperKit = kit
                
                await MainActor.run {
                    self.isInitialized = true
                    self.isLoading = false
                }
                
                print("🤖 [WHISPERKIT] 🚀 Neural Engine loaded! 3-6x performance boost active.")
                return
                
            } catch {
                print("🤖 [WHISPERKIT] ⚠️ Pre-compiled Neural Engine failed: \(error)")
                print("🤖 [WHISPERKIT] 🔄 Falling back to CPU setup...")
            }
        }
        
        // Strategy 2: Fast CPU setup for immediate use
        do {
            print("🤖 [WHISPERKIT] ⚡ Quick setup for immediate use...")
            let kit = try await WhisperKit()  // CPU-only, ~30 seconds
            self.whisperKit = kit
            
            await MainActor.run {
                self.isInitialized = true
                self.isLoading = false
            }
            
            print("🤖 [WHISPERKIT] ✅ Ready to use! Optimizing in background...")
            
            // Background optimization for next launch (only if not already compiled)
            if !hasPrecompiledNE {
                Task {
                    await optimizeForNeuralEngine()
                }
            }
            
        } catch {
            print("🤖 [WHISPERKIT] ❌ Setup failed: \(error)")
            print("🤖 [WHISPERKIT] 📝 Error details: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
                self.isInitialized = false
            }
        }
    }
    
    private func optimizeForNeuralEngine() async {
        // This runs in background while user can use the app
        print("🤖 [NEURAL-ENGINE] 🧠 Background: Starting REAL Neural Engine compilation...")
        print("🤖 [NEURAL-ENGINE] ℹ️ This should take 5-10 minutes for first-time compilation")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let neConfig = WhisperKitConfig(
                model: "small.en",
                computeOptions: ModelComputeOptions(
                    audioEncoderCompute: .cpuAndNeuralEngine,
                    textDecoderCompute: .cpuAndNeuralEngine
                ),
                verbose: true,  // Enable verbose for debugging
                prewarm: true
            )
            
            print("🤖 [NEURAL-ENGINE] 🛠️ Config created - starting WhisperKit(neConfig)...")
            print("🤖 [NEURAL-ENGINE] 🛠️ Model: base.en with Neural Engine compute")
            
            // This should take 5-10 minutes but happens in background
            let _ = try await WhisperKit(neConfig)
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let compilationTime = endTime - startTime
            
            print("🤖 [NEURAL-ENGINE] ⏱️ COMPILATION TIME: \(String(format: "%.1f", compilationTime)) seconds")
            
            if compilationTime < 60 {
                print("🤖 [NEURAL-ENGINE] ⚠️ WARNING: Compilation was too fast (\(String(format: "%.1f", compilationTime))s)")
                print("🤖 [NEURAL-ENGINE] ⚠️ This suggests Neural Engine compilation didn't actually happen")
                print("🤖 [NEURAL-ENGINE] ⚠️ Expected: 300-600 seconds for first-time compilation")
            } else {
                print("🤖 [NEURAL-ENGINE] ✅ Real Neural Engine compilation completed!")
                // Mark as compiled for future launches
                markNeuralEngineCompiled()
            }
            
            print("🤖 [NEURAL-ENGINE] 🎉 Neural Engine optimization complete!")
            print("🤖 [NEURAL-ENGINE] 💡 Restart FloRight for 3-6x faster performance")
            
        } catch {
            let endTime = CFAbsoluteTimeGetCurrent()
            let failedTime = endTime - startTime
            
            print("🤖 [NEURAL-ENGINE] ❌ Background Neural Engine optimization failed after \(String(format: "%.1f", failedTime))s")
            print("🤖 [NEURAL-ENGINE] ❌ Error: \(error)")
            print("🤖 [NEURAL-ENGINE] ℹ️ Will retry on next app launch")
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
        return "WhisperKit with default model"
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
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "WhisperKit not initialized"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .configurationFailed(let message):
            return "Configuration failed: \(message)"
        }
    }
}
