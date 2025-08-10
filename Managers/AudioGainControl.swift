//
//  AudioGainControl.swift
//  FloRight
//
//  Automatic Gain Control for consistent audio levels before WhisperKit processing
//

import Foundation
import AVFoundation

// MARK: - AGC Configuration (Using Centralized Config)
// Configuration now managed in Constants.swift -> AGCConfig

// MARK: - Audio Gain Control Processor
class AudioGainControl {
    
    // AGC State Variables
    private var currentGain: Float = 1.0
    private var lastSampleRate: Float = 16000.0
    
    // Error Types
    enum AGCError: Error, LocalizedError {
        case invalidAudioFormat
        case silentAudio
        case processingFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidAudioFormat:
                return "Invalid audio format for AGC processing"
            case .silentAudio:
                return "Audio is too quiet for AGC processing"
            case .processingFailed(let message):
                return "AGC processing failed: \(message)"
            }
        }
    }
    
    init() {
        print("🎚️ [AGC] AudioGainControl initialized")
    }
    
    // MARK: - Main AGC Processing Function
    
    /// Applies Automatic Gain Control to audio buffer
    /// - Parameter audioBuffer: Input AVAudioPCMBuffer
    /// - Returns: Enhanced AVAudioPCMBuffer with consistent levels
    /// - Throws: AGCError for invalid input or processing failures
    func processAudio(_ audioBuffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard AGCConfig.enabled else {
            #if DEBUG
            if Debug.enableAGCDebug {
                print("🎚️ [AGC] AGC disabled - returning original audio")
            }
            #endif
            return audioBuffer
        }
        
        #if DEBUG
        if Debug.skipAGCProcessing {
            print("🎚️ [AGC] AGC processing skipped for debugging")
            return audioBuffer
        }
        #endif
        
        // Validate input buffer
        guard let floatChannelData = audioBuffer.floatChannelData,
              audioBuffer.frameLength > 0,
              audioBuffer.format.channelCount == 1 else {
            throw AGCError.invalidAudioFormat
        }
        
        let frameLength = Int(audioBuffer.frameLength)
        let sampleRate = Float(audioBuffer.format.sampleRate)
        lastSampleRate = sampleRate
        
        #if DEBUG
        if Debug.enableAGCDebug {
            print("🎚️ [AGC] Processing \(frameLength) samples at \(sampleRate)Hz")
        }
        #endif
        
        // Convert to Swift Array for processing
        let inputSamples = Array(UnsafeBufferPointer(start: floatChannelData[0], count: frameLength))
        
        // Apply AGC algorithm
        let processedSamples = try applyAGCAlgorithm(to: inputSamples, sampleRate: sampleRate)
        
        // Create output buffer
        let outputBuffer = try createOutputBuffer(from: processedSamples, format: audioBuffer.format)
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        #if DEBUG
        if Debug.enableAGCDebug {
            let inputRMS = calculateRMS(inputSamples)
            let outputRMS = calculateRMS(processedSamples)
            let inputLevel = 20 * log10(max(inputRMS, 1e-10))
            let outputLevel = 20 * log10(max(outputRMS, 1e-10))
            
            print("🎚️ [AGC] ===== AGC PROCESSING COMPLETE =====")
            print("🎚️ [AGC] Processing time: \(String(format: "%.1f", processingTime * 1000))ms")
            print("🎚️ [AGC] Input level: \(String(format: "%.1f", inputLevel))dB")
            print("🎚️ [AGC] Output level: \(String(format: "%.1f", outputLevel))dB")
            print("🎚️ [AGC] Gain applied: \(String(format: "%.1f", 20 * log10(currentGain)))dB")
            print("🎚️ [AGC] =======================================")
        }
        #endif
        
        return outputBuffer
    }
    
    // MARK: - Core AGC Algorithm
    
    private func applyAGCAlgorithm(to samples: [Float], sampleRate: Float) throws -> [Float] {
        // Check for silent audio
        let rms = calculateRMS(samples)
        let currentLevel = 20 * log10(max(rms, 1e-10))
        
        if currentLevel < AGCConfig.silenceThreshold {
            #if DEBUG
            if Debug.enableAGCDebug {
                print("🎚️ [AGC] ⚠️ Audio too quiet (\(String(format: "%.1f", currentLevel))dB) - minimal processing")
            }
            #endif
            // Apply minimal gain boost for very quiet audio
            return samples.map { $0 * 2.0 } // +6dB boost
        }
        
        // Calculate required gain adjustment
        let gainAdjustment = AGCConfig.targetLevel - currentLevel
        
        // Determine time constant based on gain direction
        let timeConstant = gainAdjustment > 0 ? AGCConfig.releaseTime : AGCConfig.attackTime
        let alpha = exp(-1.0 / (timeConstant * sampleRate))
        
        // Calculate new gain with smoothing
        let targetGain = pow(10, gainAdjustment / 20)
        currentGain = alpha * currentGain + (1 - alpha) * targetGain
        
        // Apply gain limits
        let gainDB = 20 * log10(currentGain)
        let limitedGainDB = max(AGCConfig.minGain, min(AGCConfig.maxGain, gainDB))
        currentGain = pow(10, limitedGainDB / 20)
        
        // Apply gain to samples
        let processedSamples = samples.map { sample in
            let processed = sample * currentGain
            // Soft limiting to prevent clipping
            return tanh(processed * 0.9) / 0.9
        }
        
        return processedSamples
    }
    
    // MARK: - Audio Utility Functions
    
    private func calculateRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0.0 }
        
        let sumSquares = samples.reduce(0) { $0 + ($1 * $1) }
        return sqrt(sumSquares / Float(samples.count))
    }
    
    private func createOutputBuffer(from samples: [Float], format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            throw AGCError.processingFailed("Failed to create output buffer")
        }
        
        guard let floatChannelData = outputBuffer.floatChannelData else {
            throw AGCError.processingFailed("Failed to access output buffer data")
        }
        
        // Copy processed samples to output buffer
        for (index, sample) in samples.enumerated() {
            floatChannelData[0][index] = sample
        }
        
        outputBuffer.frameLength = AVAudioFrameCount(samples.count)
        return outputBuffer
    }
    
    // MARK: - Audio File I/O
    
    /// Loads audio buffer from file URL
    func loadAudioBuffer(from url: URL) throws -> AVAudioPCMBuffer {
        let audioFile = try AVAudioFile(forReading: url)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat,
                                          frameCapacity: AVAudioFrameCount(audioFile.length)) else {
            throw AGCError.processingFailed("Failed to create input buffer")
        }
        
        try audioFile.read(into: buffer)
        return buffer
    }
    
    /// Saves enhanced audio buffer to temporary file
    func saveEnhancedAudio(_ buffer: AVAudioPCMBuffer, originalURL: URL) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let enhancedFileName = "floright_agc_\(Date().timeIntervalSince1970).wav"
        let enhancedURL = tempDir.appendingPathComponent(enhancedFileName)
        
        // Create audio file for writing
        let audioFile = try AVAudioFile(forWriting: enhancedURL,
                                       settings: buffer.format.settings)
        
        try audioFile.write(from: buffer)
        
        #if DEBUG
        if Debug.enableAGCDebug {
            print("🎚️ [AGC] Enhanced audio saved: \(enhancedURL.lastPathComponent)")
        }
        #endif
        
        return enhancedURL
    }
    
    deinit {
        print("🎚️ [AGC] AudioGainControl deallocated")
    }
}

// MARK: - AGC Integration Helpers

extension AudioGainControl {
    
    /// Convenient method to process audio file and return enhanced file URL
    /// This is the main integration point for SimpleNativePillManager
    func processAudioFile(_ originalURL: URL) throws -> URL {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        #if DEBUG
        if Debug.enableAGCDebug {
            print("🎚️ [AGC] 🎵 Processing audio file: \(originalURL.lastPathComponent)")
        }
        #endif
        
        // Load original audio
        let audioBuffer = try loadAudioBuffer(from: originalURL)
        
        // Apply AGC
        let enhancedBuffer = try processAudio(audioBuffer)
        
        // Save enhanced audio
        let enhancedURL = try saveEnhancedAudio(enhancedBuffer, originalURL: originalURL)
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        
        #if DEBUG
        if Debug.enableAGCDebug {
            print("🎚️ [AGC] ✅ File processing complete in \(String(format: "%.1f", totalTime * 1000))ms")
        }
        #endif
        
        return enhancedURL
    }
    
    /// Memory-safe cleanup of temporary enhanced audio files
    static func cleanupEnhancedAudio(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            #if DEBUG
            if Debug.enableAGCDebug {
                print("🎚️ [AGC] 🗑️ Cleaned up enhanced audio: \(url.lastPathComponent)")
            }
            #endif
        } catch {
            print("🎚️ [AGC] ⚠️ Failed to cleanup enhanced audio: \(error)")
        }
    }
}
