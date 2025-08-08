//
//  AppSettings.swift
//  FloRight
//
//  Manages user preferences and settings
//

import Foundation
import SwiftUI

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @AppStorage("selectedTonePreset") var selectedTonePresetRaw: String = TonePreset.neutral.rawValue
    @AppStorage("recordingHotkey") var recordingHotkey: String = "rightshift"
    @AppStorage("useUKSpelling") var useUKSpelling: Bool = true
    @AppStorage("showRecordingPill") var showRecordingPill: Bool = true
    @AppStorage("autoInsertText") var autoInsertText: Bool = true
    @AppStorage("playFeedbackSounds") var playFeedbackSounds: Bool = true
    @AppStorage("useLatchMode") var useLatchMode: Bool = false
    
    var selectedTonePreset: TonePreset {
        get { TonePreset(rawValue: selectedTonePresetRaw) ?? .neutral }
        set { selectedTonePresetRaw = newValue.rawValue }
    }
    
    private init() {}
    
    // Version info
    static let appVersion = "1.0"
    static let buildNumber = "1"
    
    // Whisper model info
    static let whisperModel = "small.en"
    static let modelSize = "244MB"  // WhisperKit small.en actual size
    
    // Memory usage target
    static let targetMemoryUsage = "< 200MB"
}
