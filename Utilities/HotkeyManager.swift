import SwiftUI
import AppKit
import AudioToolbox

// MARK: - SIMPLE SYNCHRONOUS HotkeyManager (no MainActor complexity)
class HotkeyManager: ObservableObject {
    @Published var isRecording = false
    private var recordingManager: SimpleNativePillManager?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isShiftPressed = false
    private var isRecordingInLatchMode = false
    
    // Key code mapping for supported modifier keys
    private let keyCodeMap: [String: Int] = [
        "rightshift": 60,
        "leftshift": 56
    ]
    
    // Simple synchronous init
    init() {
        setupHotkey()
    }
    
    func setRecordingManager(_ manager: SimpleNativePillManager) {
        self.recordingManager = manager
        print("⌨️ ✅ Simple native pill recording manager connected")
    }
    
    // MARK: - Key Type Detection and Mapping
    
    private func getCurrentKeyCode() -> Int? {
        let currentHotkey = AppSettings.shared.recordingHotkey
        let keyCode = keyCodeMap[currentHotkey]
        print("⌨️ [BINDING] \(currentHotkey) → keyCode: \(keyCode ?? -1)")
        return keyCode
    }
    
    private func setupHotkey() {
        print("⌨️ Setting up modifier key flagsChanged monitoring")
        
        // FIXED: Don't request permissions here - only check silently
        let trusted = AXIsProcessTrusted()
        if !trusted {
            print("⌨️ ⚠️ Accessibility permission not granted - hotkeys may not work properly")
        } else {
            print("⌨️ ✅ Accessibility permission granted")
        }
        
        // SIMPLE: Global monitor with immediate synchronous handling
        print("⌨️ [DEBUG] Creating global monitor for flagsChanged events...")
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            print("⌨️ [DEBUG] Global modifier monitor triggered!")
            // CRITICAL: Handle synchronously to avoid race conditions
            self?.handleModifierKeySync(event)
        }
        
        if globalMonitor != nil {
            print("⌨️ [DEBUG] ✅ Global modifier monitor created successfully")
        } else {
            print("⌨️ [DEBUG] ❌ Failed to create global modifier monitor")
        }
        
        // SIMPLE: Local monitor with immediate synchronous handling
        print("⌨️ [DEBUG] Creating local monitor for flagsChanged events...")
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            print("⌨️ [DEBUG] Local modifier monitor triggered!")
            // CRITICAL: Handle synchronously to avoid race conditions
            self?.handleModifierKeySync(event)
            return event
        }
        
        if localMonitor != nil {
            print("⌨️ [DEBUG] ✅ Local modifier monitor created successfully")
        } else {
            print("⌨️ [DEBUG] ❌ Failed to create local modifier monitor")
        }
        
        print("⌨️ ✅ Modifier key flagsChanged monitoring started")
    }
    
    // CRITICAL: Completely synchronous modifier key handling (no async/await)
    private func handleModifierKeySync(_ event: NSEvent) {
        // DEBUG: Log all flagsChanged events to see if handler is working
        print("⌨️ [DEBUG] ModifierKey FlagsChanged event: keyCode=\(event.keyCode), flags=\(event.modifierFlags)")
        
        // Get current expected key code dynamically
        guard let expectedKeyCode = getCurrentKeyCode() else {
            print("⌨️ [DEBUG] No valid key code found - ignoring event")
            return
        }
        
        guard event.keyCode == expectedKeyCode else { 
            print("⌨️ [DEBUG] Ignoring keyCode \(event.keyCode) (not expected \(expectedKeyCode))")
            return 
        }
        
        let isShiftOnly = event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.shift]
        let isShiftCurrentlyPressed = event.modifierFlags.contains(.shift)
        
        print("⌨️ [DEBUG] MODIFIER KEY detected: isShiftOnly=\(isShiftOnly), isPressed=\(isShiftCurrentlyPressed), wasPressed=\(self.isShiftPressed)")
        
        // SIMPLE: Synchronous state management
        if AppSettings.shared.useLatchMode {
            // LATCH MODE: Toggle on each press
            if isShiftOnly && isShiftCurrentlyPressed && !self.isShiftPressed {
                print("⌨️ 🎤 SHIFT PRESSED - Latch mode...")
                self.isShiftPressed = true
                
                if !isRecordingInLatchMode {
                    print("⌨️ 🎤 Starting latch recording...")
                    isRecordingInLatchMode = true
                    startRecordingSync()
                } else {
                    print("⌨️ 🛑 Stopping latch recording...")
                    isRecordingInLatchMode = false
                    stopRecordingSync()
                }
            } else if !isShiftCurrentlyPressed && self.isShiftPressed {
                self.isShiftPressed = false
                // Do nothing on key release in latch mode - recording continues
            }
        } else {
            // EXISTING: Press-and-hold mode (unchanged)
            if isShiftOnly && isShiftCurrentlyPressed && !self.isShiftPressed {
                print("⌨️ 🎤 SHIFT PRESSED - Starting recording...")
                self.isShiftPressed = true
                startRecordingSync()
            } else if !isShiftCurrentlyPressed && self.isShiftPressed {
                print("⌨️ 🛑 SHIFT RELEASED - Stopping recording...")
                self.isShiftPressed = false
                stopRecordingSync()
            }
        }
    }
    
    // CRITICAL: Synchronous recording start (no complex async)
    private func startRecordingSync() {
        guard !isRecording, let manager = recordingManager else {
            print("⌨️ [⚠️] Cannot start - already recording or no manager")
            return
        }
        
        print("⌨️ [SYNC] Starting recording synchronously...")
        
        // Play click sound immediately when hotkey is pressed (before recording starts)
        if AppSettings.shared.playFeedbackSounds {
            playClickSound()
        }
        
        // Update UI state on main thread if needed
        DispatchQueue.main.async {
            self.isRecording = true
        }
        
        // Start recording (this can be async internally, but we don't wait)
        manager.startRecording()
        
        print("⌨️ [SYNC] ✅ Recording started")
    }
    
    // CRITICAL: Synchronous recording stop (this is where crashes happen!)
    private func stopRecordingSync() {
        guard isRecording, let manager = recordingManager else {
            print("⌨️ [⚠️] Cannot stop - not recording or no manager")
            return
        }
        
        print("⌨️ [SYNC] Stopping recording synchronously...")
        
        // Update UI state immediately
        DispatchQueue.main.async {
            self.isRecording = false
        }
        
        // Play notification sound immediately upon hotkey release
        if AppSettings.shared.playFeedbackSounds {
            playNotificationSound()
        }
        
        // CRITICAL: Stop recording without waiting (let it clean up internally)
        manager.stopRecording()
        
        print("⌨️ [SYNC] ✅ Recording stopped - no waiting for cleanup")
    }
    
    // PUBLIC: Stop recording from UI (latch mode pill click)
    func stopRecordingFromUI() {
        guard isRecording, let manager = recordingManager else {
            print("⌨️ [⚠️] Cannot stop from UI - not recording or no manager")
            return
        }
        
        print("⌨️ [UI] Stopping recording from UI click...")
        
        // Reset latch state (critical for proper state management)
        isRecordingInLatchMode = false
        
        // Update UI state immediately
        DispatchQueue.main.async {
            self.isRecording = false
        }
        
        // Play notification sound (same as hotkey)
        if AppSettings.shared.playFeedbackSounds {
            playNotificationSound()
        }
        
        // Stop recording (same logic as hotkey)
        manager.stopRecording()
        
        print("⌨️ [UI] ✅ Recording stopped from UI - latch mode reset")
    }
    
    private func playClickSound() {
        // CRITICAL: Non-blocking sound with graceful error handling
        // If CLICK.mp3 is missing, don't break recording functionality
        guard let soundURL = Bundle.main.url(forResource: "CLICK", withExtension: "mp3") else {
            print("⌨️ ⚠️ Could not find CLICK.mp3 - continuing without start sound")
            return // Gracefully continue without sound
        }
        
        var soundID: SystemSoundID = 0
        let createResult = AudioServicesCreateSystemSoundID(soundURL as CFURL, &soundID)
        
        if createResult != noErr {
            print("⌨️ ⚠️ Failed to create CLICK sound (error: \(createResult)) - continuing without start sound")
            return // Gracefully continue without sound
        }
        
        AudioServicesPlaySystemSound(soundID)
        print("⌨️ 🔊 CLICK sound played on hotkey press")
    }
    
    private func playNotificationSound() {
        // CRITICAL: Non-blocking sound with graceful error handling
        guard let soundURL = Bundle.main.url(forResource: "808C", withExtension: "wav") else {
            print("⌨️ ⚠️ Could not find 808C.wav - continuing without completion sound")
            return // Gracefully continue without sound
        }
        
        var soundID: SystemSoundID = 0
        let createResult = AudioServicesCreateSystemSoundID(soundURL as CFURL, &soundID)
        
        if createResult != noErr {
            print("⌨️ ⚠️ Failed to create 808C sound (error: \(createResult)) - continuing without completion sound")
            return // Gracefully continue without sound
        }
        
        AudioServicesPlaySystemSound(soundID)
        print("⌨️ 🔊 808C sound played on hotkey release")
    }
    
    // CRITICAL: Simple synchronous cleanup (no Tasks or MainActor)
    func cleanup() {
        print("⌨️ [CLEANUP] Starting simple cleanup...")
        
        // Remove monitors immediately and synchronously
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
            print("⌨️ [CLEANUP] ✅ Global monitor removed")
        }
        
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
            print("⌨️ [CLEANUP] ✅ Local monitor removed")
        }
        
        // Clear state synchronously
        isShiftPressed = false
        isRecordingInLatchMode = false
        recordingManager = nil
        
        // Update UI state
        DispatchQueue.main.async {
            self.isRecording = false
        }
        
        print("⌨️ [CLEANUP] ✅ Simple cleanup complete")
    }
    
    deinit {
        print("⌨️ [DEINIT] HotkeyManager deinit - calling simple cleanup")
        cleanup()
        print("⌨️ [DEINIT] HotkeyManager deallocated")
    }
}
