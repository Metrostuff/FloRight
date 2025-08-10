//
//  Constants.swift
//  FloRight
//
//  App-wide constants and configuration
//

import Foundation

struct Constants {
    // App Info
    static let appName = "FloRight"
    static let appTagline = "Light as a feather. Writes like a pro."
    static let appWebsite = "https://floright.app"
    
    // Pricing
    static let price = "£24"
    static let priceUSD = "$29"
    
    // Technical
    static let targetMemoryUsage = 200 // MB
    static let maxRecordingDuration: TimeInterval = 300 // 5 minutes
    static let processingTimeout: TimeInterval = 10 // seconds
    
    // Whisper Model
    static let whisperModelName = "ggml-small.en.q5_0.bin"
    static let whisperModelSize = 390 // MB
    
    // UI
    static let recordingPillWidth: CGFloat = 280
    static let recordingPillHeight: CGFloat = 60
    static let animationDuration: TimeInterval = 0.3
    
    // File Management
    static let tempFilePrefix = "floright_recording_"
    static let logFileName = "floright.log"
    
    // Update Check
    static let updateCheckURL = "https://api.floright.app/check-update"
    static let downloadURL = "https://floright.app/download"
    
    // Support
    static let supportEmail = "support@floright.app"
    static let privacyPolicyURL = "https://floright.app/privacy"
    static let termsOfServiceURL = "https://floright.app/terms"
}

// MARK: - Feature Flags
struct FeatureFlags {
    static let enableAnalytics = false
    static let enableCrashReporting = true
    static let enableAutoUpdate = true
    static let enableBetaFeatures = false
    
    // AGC Feature Control
    static let enableAGC = true  // Master switch for AGC feature
}

// MARK: - AGC Configuration
struct AGCConfig {
    static let enabled = FeatureFlags.enableAGC
    static let debugMode = false  // Set to true for detailed AGC logging
    
    // AGC Algorithm Parameters
    static let targetLevel: Float = -20.0     // dB target level
    static let attackTime: Float = 0.001      // 1ms attack time
    static let releaseTime: Float = 0.1       // 100ms release time
    static let silenceThreshold: Float = -60.0 // Below this = silence
    static let maxGain: Float = 20.0          // Maximum gain boost (dB)
    static let minGain: Float = -20.0         // Maximum gain reduction (dB)
    
    // Performance Limits
    static let maxProcessingTime: TimeInterval = 0.1  // 100ms timeout
    static let maxMemorySpikeMB: Int = 10             // 10MB temporary spike limit
}

// MARK: - Debug Settings
#if DEBUG
struct Debug {
    static let skipWhisperProcessing = false
    static let mockTranscription = "This is a test transcription for debugging purposes."
    static let logLevel = "verbose"
    static let showMemoryUsage = true
    
    // AGC Debug Settings
    static let enableAGCDebug = true   // Detailed AGC logging in debug builds
    static let skipAGCProcessing = false  // Skip AGC for debugging
}
#endif
