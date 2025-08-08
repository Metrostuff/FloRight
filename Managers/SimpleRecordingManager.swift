//
//  SimpleRecordingManager.swift
//  FloRight - CRASH-FREE VERSION (No AVAudioEngine)
//

import Foundation
import AVFoundation
import AppKit
import SwiftUI

class SimpleRecordingManager: NSObject, ObservableObject {
    @Published var recordingState = RecordingState()
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private let textInsertionManager = TextInsertionManager()
    
    // VISUAL FEEDBACK: Simple recording pill
    private var recordingWindow: NSWindow?
    private var audioLevelTimer: Timer?
    private var pillLabel: NSTextField?
    private var audioDots: [NSView] = []  // Store dot references directly
    
    override init() {
        super.init()
        print("🟢 [CRASH-FREE] Initializing simple recording (NO AVAudioEngine)")
        requestPermissions()
    }
    
    private func requestPermissions() {
        AVAudioApplication.requestRecordPermission { granted in
            print("🟢 [CRASH-FREE] Microphone permission: \(granted)")
        }
    }
    
    func startRecording() {
        guard !recordingState.isRecording else { return }
        
        print("🟢 [CRASH-FREE] Starting simple recording")
        recordingState.startRecording()
        
        // Create recording URL
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "floright_simple_\(Date().timeIntervalSince1970).wav"
        recordingURL = tempDir.appendingPathComponent(fileName)
        
        guard let url = recordingURL else {
            recordingState.error("Failed to create recording URL")
            return
        }
        
        // Ultra-simple settings (no complex format handling)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            // NO AVAUDIOENGINE = NO CRASHES!
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.isMeteringEnabled = true  // Enable audio level monitoring
            
            let success = audioRecorder?.record() ?? false
            
            if success {
                print("🟢 [CRASH-FREE] ✅ Recording started successfully - NO AVAUDIOENGINE!")
                
                // Show recording pill with visual feedback
                showRecordingPill()
                startAudioLevelMonitoring()
                
            } else {
                recordingState.error("Failed to start recording")
            }
            
        } catch {
            print("🟢 [CRASH-FREE] ❌ Recording error: \(error)")
            recordingState.error("Recording setup failed")
        }
    }
    
    func stopRecording() {
        print("🟢 [CRASH-FREE] Stopping simple recording")
        
        // Stop visual feedback first
        stopAudioLevelMonitoring()
        hideRecordingPill()
        
        audioRecorder?.stop()
        recordingState.stopRecording()
        
        processSimpleRecording()
    }
    
    private func processSimpleRecording() {
        guard let url = recordingURL else {
            recordingState.error("No recording URL")
            return
        }
        
        // Check file was created
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("🟢 [CRASH-FREE] Recording file size: \(fileSize) bytes")
            
            if fileSize > 0 {
                // Success! Insert test text
                let testText = "CRASH-FREE recording completed! No AVAudioEngine!"
                
                textInsertionManager.insertText(testText) { [weak self] success, message in
                    DispatchQueue.main.async {
                        if success {
                            self?.recordingState.complete()
                        } else {
                            self?.recordingState.error(message ?? "Text insertion failed")
                        }
                    }
                }
            } else {
                recordingState.error("Empty recording")
            }
            
            // Clean up
            try? FileManager.default.removeItem(at: url)
            
        } catch {
            print("🟢 [CRASH-FREE] File check error: \(error)")
            recordingState.error("File processing failed")
        }
        
        // Simple cleanup - no complex AVAudioEngine teardown
        audioRecorder = nil
        recordingURL = nil
        print("🟢 [CRASH-FREE] ✅ Simple cleanup complete")
    }
    
    deinit {
        print("🟢 [CRASH-FREE] SimpleRecordingManager deallocated - no complex cleanup needed")
        stopAudioLevelMonitoring()
        hideRecordingPill()
        audioDots.removeAll()  // Clear dot references
        audioRecorder?.stop()
        audioRecorder = nil
    }
    
    // MARK: - Visual Feedback (Recording Pill)
    
    private func showRecordingPill() {
        guard AppSettings.shared.showRecordingPill else {
            print("📊 [PILL] Recording pill disabled in settings")
            return
        }
        
        guard let mainScreen = NSScreen.main else {
            print("📊 [PILL] Could not get main screen")
            return
        }
        
        print("📊 [PILL] Creating simple recording pill at bottom center...")
        
        // Calculate position (bottom center as expected)
        let pillWidth: CGFloat = 180
        let pillHeight: CGFloat = 32
        let screenFrame = mainScreen.frame
        let pillX = (screenFrame.width - pillWidth) / 2
        let pillY: CGFloat = 80  // Bottom of screen + margin
        
        let pillFrame = NSRect(x: pillX, y: pillY, width: pillWidth, height: pillHeight)
        
        // Create minimal window
        let window = NSWindow(
            contentRect: pillFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Simple window configuration
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.ignoresMouseEvents = true
        window.hasShadow = false
        
        // Create pill content
        let contentView = NSView(frame: NSRect(origin: .zero, size: pillFrame.size))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        contentView.layer?.cornerRadius = 16
        
        // Small text label as requested
        let label = NSTextField(labelWithString: "Recording...")
        label.textColor = .white
        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)  // Small font
        label.frame = NSRect(x: 50, y: 8, width: 80, height: 16)
        contentView.addSubview(label)
        
        // Audio level dots (small as requested)
        let dotSize: CGFloat = 3
        let dotSpacing: CGFloat = 5
        let startX: CGFloat = 12
        
        // Clear any existing dots
        audioDots.removeAll()
        
        for i in 0..<5 {
            let dot = NSView(frame: NSRect(
                x: startX + CGFloat(i) * (dotSize + dotSpacing),
                y: (pillHeight - dotSize) / 2,
                width: dotSize,
                height: dotSize
            ))
            dot.wantsLayer = true
            dot.layer?.backgroundColor = NSColor.green.cgColor
            dot.layer?.cornerRadius = dotSize / 2
            
            contentView.addSubview(dot)
            audioDots.append(dot)  // Store reference instead of using tag
        }
        
        window.contentView = contentView
        recordingWindow = window
        pillLabel = label
        window.orderFront(nil)
        
        print("📊 [PILL] ✅ Simple recording pill created at bottom center")
    }
    
    private func hideRecordingPill() {
        if let window = recordingWindow {
            print("📊 [PILL] Hiding recording pill...")
            
            DispatchQueue.main.async {
                window.orderOut(nil)
                window.close()
                self.recordingWindow = nil
                self.pillLabel = nil
                self.audioDots.removeAll()  // Clear dot references
                print("📊 [PILL] ✅ Recording pill hidden")
            }
        }
    }
    
    private func startAudioLevelMonitoring() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateAudioLevelDisplay()
        }
        print("📊 [PILL] ✅ Audio level monitoring started")
    }
    
    private func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        print("📊 [PILL] ✅ Audio level monitoring stopped")
    }
    
    private func updateAudioLevelDisplay() {
        guard let recorder = audioRecorder,
              !audioDots.isEmpty else { return }  // Use audioDots array instead of window lookup
        
        // Update metering
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        
        // Convert to 0-1 scale (averagePower is typically -160 to 0)
        let normalizedLevel = max(0, min(1, (averagePower + 50) / 50))
        
        // Animate dots based on audio level
        DispatchQueue.main.async {
            for (i, dot) in self.audioDots.enumerated() {
                let shouldGlow = normalizedLevel > (Float(i) * 0.2)
                
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.1
                    dot.animator().alphaValue = shouldGlow ? 1.0 : 0.3
                    
                    // Add subtle scale animation for active dots
                    if shouldGlow {
                        dot.animator().layer?.transform = CATransform3DMakeScale(1.2, 1.2, 1.0)
                    } else {
                        dot.animator().layer?.transform = CATransform3DIdentity
                    }
                }
            }
        }
    }
}
