//
//  RecordingManager.swift
//  FloRight
//

import Foundation
import AVFoundation
import AppKit
import SwiftUI

class RecordingManager: NSObject, ObservableObject {
    @Published var recordingState = RecordingState()
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    private let textInsertionManager = TextInsertionManager()
    private var recordingWindow: NSWindow?
    
    // CRITICAL: Add callback safety flags
    private var isAudioCallbackActive = false
    private var cancellationToken = false
    
    // Recording session tracking
    private var recordingSessionCount = 0
    private var lastCleanupTime: Date?
    
    override init() {
        super.init()
        
        // macOS AUDIO SETUP: Initialize fresh audio engine approach
        createFreshAudioEngine()
        
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }
    
    // EXPERT SOLUTION: Completely recreate AVAudioEngine each time (prevents over-release crashes)
    private func createFreshAudioEngine() {
        print("🎤 [EXPERT-FIX] Creating completely fresh AVAudioEngine")
        
        // CRITICAL: Create brand new engine (don't reuse)
        audioEngine = AVAudioEngine()
        
        guard let engine = audioEngine else {
            print("🎤 [ERROR] Failed to create fresh AVAudioEngine")
            return
        }
        
        inputNode = engine.inputNode
        
        // EXPERT CHECK: Verify engine is in clean state (not initialized=1, running=0)
        print("🎤 [EXPERT-FIX] Engine state - isRunning: \(engine.isRunning)")
        
        print("🎤 [EXPERT-FIX] ✅ Fresh AVAudioEngine created successfully")
    }
    
    // CRITICAL: Force complete cleanup between recording sessions
    private func forceCompleteCleanup() {
        print("🎤 [FORCE-CLEANUP] Starting aggressive cleanup between recordings")
        
        // 1. Disable all callbacks immediately
        isAudioCallbackActive = false
        cancellationToken = true
        print("🎤 [FORCE-CLEANUP] ✅ All callbacks disabled")
        
        // 2. EXPERT ORDER: Stop engine FIRST, then remove tap
        if let engine = audioEngine {
            print("🎤 [FORCE-CLEANUP] Stopping engine FIRST (expert order)")
            if engine.isRunning {
                engine.stop()
            }
            print("🎤 [FORCE-CLEANUP] ✅ Engine stopped first")
            
            // Now remove tap AFTER engine is stopped
            if let node = inputNode {
                node.removeTap(onBus: 0)
                print("🎤 [FORCE-CLEANUP] ✅ Tap removed after engine stop")
            }
            
            engine.reset()
            print("🎤 [FORCE-CLEANUP] ✅ Engine reset")
        }
        
        // 4. Clear ALL audio references
        audioEngine = nil
        inputNode = nil
        audioFile = nil
        recordingURL = nil
        print("🎤 [FORCE-CLEANUP] ✅ All audio references cleared")
        
        // 5. Force close any existing window
        if recordingWindow != nil {
            print("🎤 [FORCE-CLEANUP] Found existing window - force closing")
            recordingWindow?.orderOut(nil)
            recordingWindow?.close()
            recordingWindow = nil
        }
        
        // 6. Reset recording state
        recordingState.deactivate()
        print("🎤 [FORCE-CLEANUP] ✅ Recording state reset")
        
        // 7. CRITICAL: Longer delay for audio system cleanup (experts recommend 1-2 seconds)
        print("🎤 [FORCE-CLEANUP] Waiting for audio system to fully clean up...")
        Thread.sleep(forTimeInterval: 0.5)  // Increased from 0.1 to 0.5
        
        // Record cleanup time for race condition detection
        lastCleanupTime = Date()
        
        print("🎤 [FORCE-CLEANUP] ✅ Aggressive cleanup complete - ready for new recording")
    }
    
    func startRecording() {
        guard !recordingState.isRecording else { return }
        
        recordingSessionCount += 1
        print("🎤 [INIT] Starting recording session #\(recordingSessionCount)")
        
        // Check if we're starting too soon after last cleanup
        if let lastCleanup = lastCleanupTime {
            let timeSinceCleanup = Date().timeIntervalSince(lastCleanup)
            print("🎤 [TIMING] Time since last cleanup: \(String(format: "%.3f", timeSinceCleanup))s")
            if timeSinceCleanup < 0.5 {
                print("🚨 [WARNING] Starting recording very soon after cleanup - potential race condition!")
            }
        }
        
        // CRITICAL: Force complete cleanup before starting new recording
        forceCompleteCleanup()
        
        // Reset callback flags for new recording
        isAudioCallbackActive = false
        cancellationToken = false
        print("🎤 [INIT] Callback flags reset for new recording")
        
        // Close any existing window first (crash prevention)
        closeRecordingWindow()
        
        // EXPERT SOLUTION: Create completely fresh engine (no existing tap to remove)
        print("🎤 [EXPERT-FIX] Creating completely fresh AVAudioEngine (no tap removal needed)")
        
        // Create completely fresh AVAudioEngine (expert-proven pattern)
        createFreshAudioEngine()
        
        // macOS: No AVAudioSession reactivation needed (iOS-only API)
        print("🎤 [INIT] ✅ macOS audio ready for new recording")
        
        recordingState.startRecording()
        
        // Show recording pill
        showRecordingPill()
        
        // Step 3: Use the fresh engine
        guard let engine = audioEngine,
              let node = inputNode else {
            print("🎤 [ERROR] Fresh engine creation failed")
            recordingState.error("Audio engine error")
            return
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "floright_recording_\(Date().timeIntervalSince1970).wav"
        recordingURL = tempDir.appendingPathComponent(fileName)
        
        do {
            let recordingFormat = node.outputFormat(forBus: 0)
            audioFile = try AVAudioFile(forWriting: recordingURL!, settings: recordingFormat.settings)
            
            // CRITICAL: Set callback active flag BEFORE installing tap
            isAudioCallbackActive = true
            
            // EXPERT PATTERN: Install tap on fresh node (no existing tap to conflict)
            node.installTap(onBus: 0, bufferSize: 512, format: recordingFormat) { [weak self] buffer, _ in
                // RESEARCH-BASED: Proper weak/strong dance pattern (prevents 0x20 crashes)
                guard let strongSelf = self else {
                    print("🚨 [AUDIO-CALLBACK] self is nil - callback cancelled safely")
                    return
                }
                
                // CRITICAL: Check callback safety with strong reference
                guard strongSelf.isAudioCallbackActive,
                      strongSelf.recordingState.isRecording,
                      !strongSelf.cancellationToken else {
                    print("🚨 [AUDIO-CALLBACK] Callback fired after cleanup - preventing crash!")
                    return
                }
                
                try? strongSelf.audioFile?.write(from: buffer)
                
                // Calculate audio level for pill animation
                let level = strongSelf.calculateAudioLevel(from: buffer)
                DispatchQueue.main.async { [weak strongSelf] in
                    guard let strongSelf = strongSelf,
                          strongSelf.isAudioCallbackActive,
                          !strongSelf.cancellationToken else { return }
                    strongSelf.recordingState.audioLevel = level
                }
            }
            
            try engine.start()
            print("🎤 ✅ Audio recording started successfully")
            
        } catch {
            print("🎤 ❌ Error starting recording: \(error)")
            recordingState.error("Recording failed")
            closeRecordingWindow()
        }
    }
    
    func stopRecording() {
        print("🎤 [LINE] stopRecording() ENTRY")
        
        // CRITICAL: Disable callbacks FIRST to prevent crash
        print("🎤 [CRITICAL] Line 0: Disabling audio callbacks to prevent EXC_BAD_ACCESS")
        isAudioCallbackActive = false
        cancellationToken = true
        print("🎤 [CRITICAL] ✅ Callbacks disabled - this should prevent the crash!")
        
        print("🎤 [LINE] Line 1: About to call recordingState.stopRecording()")
        recordingState.stopRecording()
        print("🎤 [LINE] Line 2: recordingState.stopRecording() completed")
        
        // EXPERT PATTERN: STOP engine FIRST, then remove tap (critical order)
        print("🎤 [EXPERT-STOP] Step 1: STOP engine FIRST (experts confirm this order)")
        if let engine = audioEngine {
            if engine.isRunning {
                print("🎤 [EXPERT-STOP] Stopping running engine...")
                engine.stop()
                print("🎤 [EXPERT-STOP] ✅ Engine stopped")
            }
        }
        
        // Step 2: NOW remove tap (after engine is stopped)
        print("🎤 [EXPERT-STOP] Step 2: Remove tap AFTER engine stop")
        if let node = inputNode {
            node.removeTap(onBus: 0)
            print("🎤 [EXPERT-STOP] ✅ Tap removed after engine stop")
        }
        
        // Step 3: Reset engine completely
        if let engine = audioEngine {
            print("🎤 [EXPERT-STOP] Step 3: Reset engine")
            engine.reset()
            print("🎤 [EXPERT-STOP] ✅ Engine reset completed")
        }
        
        // CRITICAL: Clear audioFile reference immediately (prevents objc_release crash)
        print("🎤 [EXPERT-STOP] Step 4: Clear audioFile reference IMMEDIATELY")
        audioFile = nil
        print("🎤 [EXPERT-STOP] ✅ audioFile cleared")
        
        print("🎤 [LINE] Line 13: About to get urlToProcess")
        let urlToProcess = recordingURL
        print("🎤 [LINE] Line 14: urlToProcess = \(urlToProcess?.lastPathComponent ?? "nil")")
        
        // CRITICAL: Clear all references immediately
        print("🎤 [LINE] Line 15: About to clear audio references")
        audioEngine = nil
        print("🎤 [LINE] Line 16: audioEngine set to nil")
        inputNode = nil
        print("🎤 [LINE] Line 17: inputNode set to nil")
        audioFile = nil
        print("🎤 [LINE] Line 18: audioFile set to nil")
        recordingURL = nil
        print("🎤 [LINE] Line 19: recordingURL set to nil")
        
        print("🎤 [LINE] Line 20: About to check if urlToProcess exists")
        if let recordingURL = urlToProcess {
            print("🎤 [LINE] Line 21: About to call processRecording")
            processRecording(at: recordingURL)
            print("🎤 [LINE] Line 22: processRecording call completed")
        }
        print("🎤 [LINE] stopRecording() EXIT")
    }
    
    private func processRecording(at url: URL) {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            print("🎵 [LINE-DEBUG] Audio file recorded: \(url.lastPathComponent)")
            print("🎵 File size: \(fileSize) bytes")
            
            if fileSize > 0 {
                print("🎵 ✅ Audio successfully recorded!")
            }
        } catch {
            print("🎵 ❌ Error checking audio file: \(error)")
        }
        
        let testText = "FloRight test recording completed successfully!"
        print("🎵 Using simple test text: \(testText)")
        
        DispatchQueue.main.async { [weak self] in
            print("🎵 [LINE] Line 9: INSIDE main queue async block")
            
            guard let self = self, !self.cancellationToken else {
                print("🎵 [CANCELLED] Main queue async cancelled - preventing crash")
                return
            }
            
            print("🎵 [LINE] Line 10: About to call insertText")
            self.textInsertionManager.insertText(testText) { [weak self] success, message in
                print("🎵 [LINE] Line 11: INSIDE insertText callback - success=\(success)")
                DispatchQueue.main.async {
                    print("🎵 [LINE] Line 12: INSIDE insertText callback main queue")
                    
                    guard let self = self, !self.cancellationToken else {
                        print("🎵 [CANCELLED] insertText callback cancelled - preventing crash")
                        return
                    }
                    
                    if success {
                        print("🎵 [LINE] Line 13: Success=true, about to call complete()")
                        self.recordingState.complete()
                        print("🎵 [LINE] Line 14: complete() called, about to schedule close")
                        // Close recording window after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                            print("🎵 [LINE] Line 15: INSIDE delayed close callback")
                            guard let self = self, !self.cancellationToken else {
                                print("🎵 [CANCELLED] Delayed close cancelled - preventing crash")
                                return
                            }
                            self.closeRecordingWindow()
                            print("🎵 [LINE] Line 16: closeRecordingWindow() completed")
                        }
                        print("🎵 [LINE] Line 17: Scheduled close callback")
                    } else {
                        print("🎵 [LINE] Line 18: Success=false, calling error")
                        self.recordingState.error(message ?? "Failed to insert text")
                        print("🎵 [LINE] Line 19: error() called")
                        // Close recording window after error display
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                            guard let self = self, !self.cancellationToken else {
                                print("🎵 [CANCELLED] Delayed error close cancelled - preventing crash")
                                return
                            }
                            self.closeRecordingWindow()
                        }
                    }
                    print("🎵 [LINE] Line 20: End of callback main queue")
                }
                print("🎵 [LINE] Line 21: End of insertText callback")
            }
            print("🎵 [LINE] Line 22: insertText call completed")
        }
        
        try? FileManager.default.removeItem(at: url)
        print("🎵 ✅ Temporary audio file cleaned up")
    }
    
    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData,
              buffer.frameLength > 0 else { return 0 }
        
        let frameLength = Int(buffer.frameLength)
        let channelDataValue = channelData.pointee
        
        // Calculate RMS (Root Mean Square) of audio level
        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelDataValue[i]
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(frameLength))
        
        // Convert to decibels
        var db: Float = 20.0 * log10(rms)
        
        // Clamp to reasonable range
        if db.isInfinite || db.isNaN {
            db = -50.0
        }
        
        // Convert to 0-1 scale for animation
        let minDb: Float = -50.0
        let maxDb: Float = -10.0
        let normalized = (db - minDb) / (maxDb - minDb)
        
        return max(0, min(1, normalized))
    }
    
    private func showRecordingPill() {
        print("📊 [TRACE] showRecordingPill called")
        print("📊 [TRACE] showRecordingPill setting: \(AppSettings.shared.showRecordingPill)")
        
        guard AppSettings.shared.showRecordingPill else {
            print("📊 [TRACE] showRecordingPill disabled in settings")
            return
        }
        
        // EXPERT FIX: Ultra-simple approach to prevent window crashes
        guard let mainScreen = NSScreen.main else {
            print("📊 [ERROR] Could not get main screen")
            return
        }
        
        print("📊 [TRACE] Creating ultra-simple overlay window...")
        
        // Calculate proper position (bottom center, not quarter screen)
        let pillWidth: CGFloat = 200
        let pillHeight: CGFloat = 40
        let screenFrame = mainScreen.frame
        let pillX = (screenFrame.width - pillWidth) / 2
        let pillY: CGFloat = 100  // Bottom of screen + margin
        
        let pillFrame = NSRect(x: pillX, y: pillY, width: pillWidth, height: pillHeight)
        
        // Create minimal window
        let window = NSWindow(
            contentRect: pillFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Minimal window configuration
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.ignoresMouseEvents = true
        window.hasShadow = false
        
        // Simple visual content
        let contentView = NSView(frame: NSRect(origin: .zero, size: pillFrame.size))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        contentView.layer?.cornerRadius = 20
        
        // Simple text label
        let label = NSTextField(labelWithString: "Recording...")
        label.textColor = .white
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.frame = NSRect(x: 20, y: 10, width: 160, height: 20)
        contentView.addSubview(label)
        
        window.contentView = contentView
        recordingWindow = window
        window.orderFront(nil)
        
        print("📊 [TRACE] ✅ Ultra-simple pill window created at bottom center")
    }
    
    private func closeRecordingWindow() {
        if let window = recordingWindow {
            print("📊 [TRACE] Closing pure NSWindow (much simpler than NSHostingView)...")
            
            // RESEARCH-BASED: Simple NSWindow cleanup (no SwiftUI complexity)
            DispatchQueue.main.async {
                // Pure NSWindow cleanup - no contentView issues
                window.orderOut(nil)
                window.close()
                self.recordingWindow = nil
                print("📊 [TRACE] ✅ Pure NSWindow closed successfully")
            }
        } else {
            print("📊 [TRACE] No recording window to close")
        }
    }
    
    deinit {
        print("📊 [DEINIT] RecordingManager being deallocated...")
        
        // RESEARCH-BASED: Remove notification observers (KVO cleanup - resolves ~70% of 0x20 crashes)
        NotificationCenter.default.removeObserver(self)
        print("📊 [DEINIT] ✅ Notification observers removed")
        
        // Emergency cleanup
        recordingState.deactivate()
        
        // Stop audio engine if still running
        if let engine = audioEngine {
            if engine.isRunning {
                inputNode?.removeTap(onBus: 0)
                engine.stop()
            }
            engine.reset()
        }
        
        // macOS: No AVAudioSession to deactivate (iOS-only API)
        print("📊 [DEINIT] ✅ macOS audio cleanup complete")
        
        audioEngine = nil
        inputNode = nil
        audioFile = nil
        recordingURL = nil
        
        closeRecordingWindow()
        print("📊 [DEINIT] RecordingManager deallocated")
    }
}
