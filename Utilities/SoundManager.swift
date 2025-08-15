//
//  SoundManager.swift
//  FloRight
//
//  Centralized sound management with proper resource lifecycle
//

import Foundation
import AudioToolbox

class SoundManager {
    private var startSoundID: SystemSoundID = 0
    private var stopSoundID: SystemSoundID = 0
    
    init() {
        setupSounds()
        print("🔊 [SOUND] SoundManager initialized with cached sounds")
    }
    
    private func setupSounds() {
        // Load start sound once
        if let url = Bundle.main.url(forResource: "UI-rim", withExtension: "wav") {
            let result = AudioServicesCreateSystemSoundID(url as CFURL, &startSoundID)
            if result == noErr {
                print("🔊 [SOUND] ✅ Start sound cached (ID: \(startSoundID))")
            } else {
                print("🔊 [SOUND] ❌ Failed to cache start sound (error: \(result))")
            }
        } else {
            print("🔊 [SOUND] ⚠️ UI-rim.wav not found in bundle")
        }
        
        // Load stop sound once
        if let url = Bundle.main.url(forResource: "808C", withExtension: "wav") {
            let result = AudioServicesCreateSystemSoundID(url as CFURL, &stopSoundID)
            if result == noErr {
                print("🔊 [SOUND] ✅ Stop sound cached (ID: \(stopSoundID))")
            } else {
                print("🔊 [SOUND] ❌ Failed to cache stop sound (error: \(result))")
            }
        } else {
            print("🔊 [SOUND] ⚠️ 808C.wav not found in bundle")
        }
    }
    
    func playStartSound() {
        guard startSoundID != 0 else {
            print("🔊 [SOUND] ⚠️ Start sound not available")
            return
        }
        AudioServicesPlaySystemSound(startSoundID)
        print("🔊 [SOUND] 🎵 Start sound played (cached)")
    }
    
    func playStopSound() {
        guard stopSoundID != 0 else {
            print("🔊 [SOUND] ⚠️ Stop sound not available")
            return
        }
        AudioServicesPlaySystemSound(stopSoundID)
        print("🔊 [SOUND] 🎵 Stop sound played (cached)")
    }
    
    deinit {
        print("🔊 [SOUND] Cleaning up cached sounds...")
        
        if startSoundID != 0 {
            AudioServicesDisposeSystemSoundID(startSoundID)
            print("🔊 [SOUND] ✅ Start sound disposed")
        }
        
        if stopSoundID != 0 {
            AudioServicesDisposeSystemSoundID(stopSoundID)
            print("🔊 [SOUND] ✅ Stop sound disposed")
        }
        
        print("🔊 [SOUND] SoundManager cleanup complete")
    }
}
