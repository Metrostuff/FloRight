import SwiftUI
import AppKit
import AVFoundation
import Foundation

// MARK: - SIMPLE NATIVE PILL (old school approach)
class SimpleNativePillManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var recordingState = RecordingState()
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private let textInsertionManager = TextInsertionManager()
    private let whisperManager = WhisperManager()  // Add Whisper integration
    private let britishSpellingManager = BritishSpellingManager()  // Add British spelling as separate step
    private let audioGainControl = AudioGainControl()  // Add AGC for consistent audio levels
    
    // SIMPLE: Just one window for the pill
    private var pillWindow: NSWindow?
    private var audioLevelTimer: Timer?
    private var recordingStartTime: Date?  // NEW: Track when recording started
    @Published var currentAudioLevel: Float = 0.0
    @Published var isTranscribing = false
    
    // Callback for UI-triggered stop (latch mode)
    var onStopRequested: (() -> Void)?
    
    override init() {
        super.init()
        print("🟡 [SIMPLE-PILL] Initializing simple native pill")
        setupSimplePill()
    }
    
    // MARK: - Simple Pill Setup
    private func setupSimplePill() {
        // Keep window ready but hidden - will create view dynamically
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        
        // Use wider window to accommodate largest pill size (160px when transcribing)
        let windowWidth: CGFloat = 180
        let windowHeight: CGFloat = 60
        let pillX = (screenFrame.width - windowWidth) / 2
        let pillY: CGFloat = 80
        
        pillWindow = NSWindow(
            contentRect: NSRect(x: pillX, y: pillY, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        pillWindow?.level = .floating
        pillWindow?.backgroundColor = .clear
        pillWindow?.isOpaque = false
        pillWindow?.ignoresMouseEvents = true
        pillWindow?.hasShadow = false
        
        // Keep window ready but hidden
        pillWindow?.orderOut(nil)
        
        print("🟡 [SIMPLE-PILL] ✅ Simple pill setup complete")
    }
    
    // MARK: - Old School: Key Press = Show, Key Release = Hide
    
    func startRecording() {
        guard !recordingState.isRecording else { return }
        
        print("🟡 [SIMPLE-PILL] 📝 SETTINGS CHECK: UK Spelling flag at recording start: \(AppSettings.shared.useUKSpelling)")
        print("🟡 [SIMPLE-PILL] Key pressed - starting recording")
        
        // Capture the recording start time
        recordingStartTime = Date()
        
        // MICROPHONE CHECK: Only check microphone upfront (not accessibility)
        if !PermissionManager.shared.isMicrophoneAuthorized() {
            print("🟡 [SIMPLE-PILL] ❌ Cannot record - microphone permission missing")
            
            // SHOW CLEAR ERROR MESSAGE
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Microphone Permission Required"
                alert.informativeText = "FloRight needs microphone access to record audio.\n\nPlease:\n1. Open System Settings\n2. Go to Privacy & Security > Microphone\n3. Enable FloRight\n4. Try recording again"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Cancel")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    // Open System Settings to Privacy & Security > Microphone
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            
            recordingState.error("Microphone permission required")
            return
        }
        
        recordingState.startRecording()
        
        // OLD SCHOOL: Show pill immediately on key press (microphone permission validated)
        showPill()
        
        // Start actual recording (microphone permission already validated)
        startAudioRecording()
    }
    
    func stopRecording() {
        print("🟡 [SIMPLE-PILL] Key released - stopping recording")
        
        // Stop audio level monitoring
        stopAudioLevelMonitoring()
        
        // Stop recording
        audioRecorder?.stop()
        recordingState.stopRecording()
        
        // NEW: Keep pill visible but show transcribing state
        DispatchQueue.main.async {
            self.isTranscribing = true
        }
        print("🟡 [SIMPLE-PILL] ✅ Pill now showing transcribing state")
        
        // THEN do processing in background (don't block UI)
        DispatchQueue.global(qos: .userInitiated).async {
            self.processRecording()
        }
    }
    
    // SIMPLE: Show pill (key press event)
    private func showPill() {
        // Create the pill view with direct manager reference
        let pillView = SimplePillView(manager: self)
        
        pillWindow?.contentView = NSHostingView(rootView: pillView)
        
        // Enable mouse events for latch mode, disable for press-and-hold mode
        pillWindow?.ignoresMouseEvents = !AppSettings.shared.useLatchMode
        
        pillWindow?.orderFront(nil)
        print("🟡 [SIMPLE-PILL] ✅ Pill shown (key press) - mouse events: \(AppSettings.shared.useLatchMode ? "enabled" : "disabled")")
    }
    
    // SIMPLE: Hide pill (key release event)  
    private func hidePill() {
        pillWindow?.orderOut(nil)
        pillWindow?.contentView = nil  // Clear the view
        print("🟡 [SIMPLE-PILL] ✅ Pill hidden (key release)")
    }
    
    // MARK: - Audio Recording (same as before)
    
    private func startAudioRecording() {
        // SIMPLIFIED: Permissions already validated by PermissionManager
        proceedWithRecording()
    }
    
    private func proceedWithRecording() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "floright_simple_\(Date().timeIntervalSince1970).wav"
        recordingURL = tempDir.appendingPathComponent(fileName)
        
        guard let url = recordingURL else {
            recordingState.error("Failed to create recording URL")
            return
        }
        
        // IMPROVED: More robust audio settings for macOS
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self  // Add delegate for better error handling
            audioRecorder?.prepareToRecord()
            audioRecorder?.isMeteringEnabled = true
            
            let success = audioRecorder?.record() ?? false
            
            if success {
                print("🟡 [SIMPLE-PILL] ✅ Audio recording started")
                startAudioLevelMonitoring()
            } else {
                recordingState.error("Failed to start recording")
            }
            
        } catch {
            print("🟡 [SIMPLE-PILL] ❌ Recording error: \(error)")
            recordingState.error("Recording setup failed")
        }
    }
    
    private func processRecording() {
        // START OVERALL TIMING
        let overallStartTime = CFAbsoluteTimeGetCurrent()
        print("🟡 [SIMPLE-PILL] 📝 SETTINGS CHECK: UK Spelling flag at processing start: \(AppSettings.shared.useUKSpelling)")
        print("🟡 [SIMPLE-PILL] ⏱️ Starting overall processing pipeline...")
        
        guard let url = recordingURL else {
            DispatchQueue.main.async {
                self.recordingState.error("No recording URL")
            }
            return
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("🟡 [SIMPLE-PILL] 📊 Recording file size: \(fileSize) bytes")
            
            if fileSize > 0 {
                print("🟡 [SIMPLE-PILL] ⏱️ File processing time: \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - overallStartTime))s")
                
                // Show processing status
                DispatchQueue.main.async {
                    self.recordingState.statusText = "Enhancing audio..."
                }
                
                // AGC PROCESSING: Apply Automatic Gain Control for consistent levels
                var finalURL = url  // Default to original URL
                var enhancedURL: URL? = nil
                
                do {
                    print("🟡 [SIMPLE-PILL] 🎚️ Applying AGC for consistent audio levels...")
                    enhancedURL = try audioGainControl.processAudioFile(url)
                    finalURL = enhancedURL!  // Use enhanced audio for transcription
                    print("🟡 [SIMPLE-PILL] ✅ AGC processing complete")
                } catch {
                    print("🟡 [SIMPLE-PILL] ⚠️ AGC processing failed: \(error.localizedDescription)")
                    print("🟡 [SIMPLE-PILL] 🔄 Falling back to original audio")
                    // Continue with original audio - AGC failure is not fatal
                }
                
                // Update processing status
                DispatchQueue.main.async {
                    self.recordingState.statusText = "Transcribing..."
                }
                
                // WHISPERKIT: Use async transcription for best performance (with enhanced audio)
                Task {
                    print("🟡 [SIMPLE-PILL] 📝 TRACING: Starting transcription with WhisperKit...")
                    let transcribedText = await whisperManager.transcribe(audioURL: finalURL)
                    print("🟡 [SIMPLE-PILL] 📝 TRACING: WhisperKit transcription complete: \"\(transcribedText.prefix(50))...\"")
                    
                    // BRITISH SPELLING: Convert to British spelling as separate step (not replacing tone logic)
                    print("🟡 [SIMPLE-PILL] 📝 SETTINGS CHECK: UK Spelling flag before conversion: \(AppSettings.shared.useUKSpelling)")
                    print("🟡 [SIMPLE-PILL] 📝 TRACING: Starting British spelling conversion step...")
                    let britishText = britishSpellingManager.convertToBritishSpelling(transcribedText)
                    print("🟡 [SIMPLE-PILL] 📝 TRACING: British spelling conversion complete: \"\(britishText.prefix(50))...\"")
                    
                    // Clean up files AFTER transcription is complete
                    try? FileManager.default.removeItem(at: url)
                    
                    // Clean up enhanced audio file if it was created
                    if let enhancedURL = enhancedURL {
                        AudioGainControl.cleanupEnhancedAudio(enhancedURL)
                    }
                    
                    // Update UI on main thread
                    DispatchQueue.main.async {
                        print("🟡 [SIMPLE-PILL] 📝 TRACING: Sending to TextInsertionManager...")
                        self.textInsertionManager.insertText(britishText) { [weak self] success, message in
                            DispatchQueue.main.async {
                                // END OVERALL TIMING
                                let overallEndTime = CFAbsoluteTimeGetCurrent()
                                let totalTime = overallEndTime - overallStartTime
                                
                                print("🟡 [SIMPLE-PILL] ⏱️ ===== TOTAL PIPELINE PERFORMANCE =====")
                                print("🟡 [SIMPLE-PILL] ⏱️ Total time (key release → text ready): \(String(format: "%.3f", totalTime))s")
                                print("🟡 [SIMPLE-PILL] 📝 SETTINGS CHECK: UK Spelling flag at completion: \(AppSettings.shared.useUKSpelling)")
                                print("🟡 [SIMPLE-PILL] ⏱️ =======================================")
                                
                                // Save to history - ALWAYS save successful transcriptions
                                if let startTime = self?.recordingStartTime {
                                    TranscriptionHistory.shared.addEntry(
                                        originalText: transcribedText,
                                        processedText: britishText,
                                        tone: AppSettings.shared.selectedTonePreset,
                                        targetApp: NSWorkspace.shared.frontmostApplication?.localizedName,
                                        startTime: startTime
                                    )
                                } else {
                                    TranscriptionHistory.shared.addEntry(
                                        originalText: transcribedText,
                                        processedText: britishText,
                                        tone: AppSettings.shared.selectedTonePreset,
                                        targetApp: NSWorkspace.shared.frontmostApplication?.localizedName
                                    )
                                }
                                print("🟡 [SIMPLE-PILL] 📝 Saved transcription to history with start time")
                                
                                // Hide pill after transcription completes
                                self?.isTranscribing = false
                                self?.hidePill()
                                self?.recordingStartTime = nil  // Clean up
                                print("🟡 [SIMPLE-PILL] ✅ Transcription complete - pill hidden")
                                
                                if success {
                                    self?.recordingState.complete()
                                } else {
                                    // CHECK: Is this an accessibility permission issue?
                                    if !PermissionManager.shared.isAccessibilityAuthorized() {
                                        // SHOW CLEAR ACCESSIBILITY ERROR MESSAGE
                                        DispatchQueue.main.async {
                                            let alert = NSAlert()
                                            alert.messageText = "Text Copied to Clipboard"
                                            alert.informativeText = "Your transcription is ready in the clipboard!\n\nFor automatic text insertion:\n1. Open System Settings\n2. Go to Privacy & Security > Accessibility\n3. Enable FloRight\n4. Try recording again"
                                            alert.alertStyle = .informational
                                            alert.addButton(withTitle: "Open System Settings")
                                            alert.addButton(withTitle: "OK")
                                            
                                            let response = alert.runModal()
                                            if response == .alertFirstButtonReturn {
                                                // Open System Settings to Privacy & Security > Accessibility
                                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                                    NSWorkspace.shared.open(url)
                                                }
                                            }
                                        }
                                    }
                                    
                                    self?.recordingState.error(message ?? "Text insertion failed")
                                }
                            }
                        }
                    }
                }
                
            } else {
                let overallEndTime = CFAbsoluteTimeGetCurrent()
                let totalTime = overallEndTime - overallStartTime
                
                DispatchQueue.main.async {
                    print("🟡 [SIMPLE-PILL] ⏱️ Empty recording detected after \(String(format: "%.3f", totalTime))s")
                    
                    // Hide pill even for empty recordings
                    self.isTranscribing = false
                    self.hidePill()
                    print("🟡 [SIMPLE-PILL] ✅ Empty recording - pill hidden")
                    
                    self.recordingState.error("Empty recording")
                }
                // Clean up empty file
                try? FileManager.default.removeItem(at: url)
            }
            
        } catch {
            let overallEndTime = CFAbsoluteTimeGetCurrent()
            let totalTime = overallEndTime - overallStartTime
            
            print("🟡 [SIMPLE-PILL] File check error after \(String(format: "%.3f", totalTime))s: \(error)")
            DispatchQueue.main.async {
                // Hide pill on processing errors
                self.isTranscribing = false
                self.hidePill()
                print("🟡 [SIMPLE-PILL] ✅ Processing error - pill hidden")
                
                self.recordingState.error("File processing failed")
            }
            // Clean up original file on error
            try? FileManager.default.removeItem(at: url)
        }
        
        audioRecorder?.delegate = nil  // Clear delegate
        audioRecorder = nil
        recordingURL = nil
        
        print("🟡 [SIMPLE-PILL] ✅ Simple cleanup complete")
    }
    
    // MARK: - Audio Level Monitoring
    
    private func startAudioLevelMonitoring() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self,
                  let recorder = self.audioRecorder else { return }
            
            recorder.updateMeters()
            let averagePower = recorder.averagePower(forChannel: 0)
            let peakPower = recorder.peakPower(forChannel: 0)
            
            // More sensitive conversion: -60dB to 0dB range
            let normalizedLevel = max(0, min(1, (averagePower + 60) / 60))
            
            // DEBUG: Log audio levels every few cycles
            if Int(Date().timeIntervalSince1970 * 20) % 20 == 0 {
                print("🟡 [AUDIO] Raw: \(averagePower)dB, Peak: \(peakPower)dB, Normalized: \(normalizedLevel)")
            }
            
            DispatchQueue.main.async {
                self.currentAudioLevel = normalizedLevel
            }
        }
        print("🟡 [SIMPLE-PILL] ✅ Audio level monitoring started (enhanced sensitivity)")
    }
    
    private func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        
        DispatchQueue.main.async {
            self.currentAudioLevel = 0.0
        }
        
        print("🟡 [SIMPLE-PILL] ✅ Audio level monitoring stopped")
    }
    
    // MARK: - Test Mode for Animation
    private var testModeTimer: Timer?
    
    func enableTestMode() {
        print("🟡 [TEST] Enabling animation test mode")
        
        // Show pill first
        showPill()
        
        // Start test animation that cycles through levels
        testModeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let time = Date().timeIntervalSince1970
            let cycleTime = fmod(time, 3.0) // 3 second cycle
            let testLevel = Float(sin(cycleTime * 2 * .pi) * 0.5 + 0.5) // 0.0 to 1.0
            
            DispatchQueue.main.async {
                self.currentAudioLevel = testLevel
                print("🟡 [TEST] Audio level: \(testLevel)")
            }
        }
    }
    
    func disableTestMode() {
        print("🟡 [TEST] Disabling animation test mode")
        testModeTimer?.invalidate()
        testModeTimer = nil
        hidePill()
    }
    
    deinit {
        print("🟡 [SIMPLE-PILL] Deallocating - simple cleanup")
        
        // Stop recording if active
        audioRecorder?.stop()
        audioRecorder?.delegate = nil  // Clear delegate
        audioRecorder = nil
        
        // Stop monitoring
        stopAudioLevelMonitoring()
        testModeTimer?.invalidate()
        
        // Clean up UI
        pillWindow?.orderOut(nil)
        pillWindow?.close()
        pillWindow = nil
        
        print("🟡 [SIMPLE-PILL] ✅ Simple cleanup finished")
    }
    
    // MARK: - AVAudioRecorderDelegate
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("🟡 [AUDIO-DELEGATE] Recording finished successfully: \(flag)")
        if !flag {
            DispatchQueue.main.async {
                self.recordingState.error("Recording failed")
            }
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("🟡 [AUDIO-DELEGATE] Encoding error: \(error?.localizedDescription ?? "unknown")")
        DispatchQueue.main.async {
            self.recordingState.error("Audio encoding failed")
        }
    }
}

// MARK: - Simple SwiftUI Pill View
struct SimplePillView: View {
    @ObservedObject var manager: SimpleNativePillManager
    @State private var activeIndex: Int = 0
    @State private var waveTimer: Timer?
    
    // Computed property for red square visibility
    private var shouldShowRedSquare: Bool {
        AppSettings.shared.useLatchMode && 
        manager.recordingState.isRecording && 
        !manager.isTranscribing
    }
    
    var body: some View {
        // Center the pill content within the window
        HStack {
            Spacer()
            
            HStack(spacing: 6) {
                if manager.isTranscribing {
                    // Show transcribing state with Option 3: Text + 5 animated lines
                    HStack(spacing: 8) {
                        Text("Transcribing")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        
                        // 8 animated vertical lines - Simple traveling wave
                        HStack(spacing: 2) {
                            ForEach(0..<8) { i in
                                // Simple height calculation based on distance from activeIndex
                                let distance = abs(i - activeIndex)
                                let scale: CGFloat = {
                                    switch distance {
                                    case 0: return 2.0  // Active bar (tallest)
                                    case 1: return 1.5  // Adjacent bars (medium)
                                    default: return 0.5 // Far bars (shortest)
                                    }
                                }()
                                
                                Capsule()
                                    .fill(Color(red: 1.0, green: 1.0, blue: 0.0)) // Bright yellow
                                    .frame(width: 2, height: 4)
                                    .scaleEffect(y: scale)
                                    .animation(.easeInOut(duration: 0.2), value: activeIndex)
                            }
                        }
                        .onAppear {
                            print("🔴 [WAVE] SimplePillView onAppear, isTranscribing: \(manager.isTranscribing)")
                            if manager.isTranscribing {
                                startWaveAnimation()
                            }
                        }
                        .onDisappear {
                            print("🔴 [WAVE] SimplePillView onDisappear")
                            stopWaveAnimation()
                        }
                        .onChange(of: manager.isTranscribing) { _, isTranscribing in
                            print("🔴 [WAVE] isTranscribing changed to: \(isTranscribing)")
                            if isTranscribing {
                                startWaveAnimation()
                            } else {
                                stopWaveAnimation()
                            }
                        }
                    }
                } else {
                    // Show recording audio levels
                    HStack(spacing: 2) {
                        ForEach(0..<16) { i in
                        let dotThreshold = Float(i) * 0.05 // More sensitive for 16 bars: 0.0, 0.05, 0.1, 0.15...
                        let isActive = manager.currentAudioLevel > dotThreshold
                        
                        // Much more dramatic expansion
                        let baseHeight: CGFloat = 4
                        let maxHeight: CGFloat = 20
                        let expansion = isActive ? (baseHeight + CGFloat(manager.currentAudioLevel) * (maxHeight - baseHeight)) : baseHeight
                        
                        Capsule()
                            .fill(isActive ? Color(red: 1.0, green: 1.0, blue: 0.0) : Color.white.opacity(0.6))
                            .frame(width: 2, height: expansion)
                            .animation(.easeOut(duration: 0.1), value: manager.currentAudioLevel)
                        }
                    }
                }
                
                // Red square indicator for latch mode (stop button)
                if shouldShowRedSquare {
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.8))
            )
            .frame(width: manager.isTranscribing ? 160 : 120, height: 40)
            .animation(.easeInOut(duration: 0.3), value: manager.isTranscribing)
            .onTapGesture {
                // Only handle taps in latch mode when recording (not transcribing)
                if shouldShowRedSquare {
                    print("🔴 [PILL-CLICK] Latch mode pill clicked - stopping recording")
                    manager.onStopRequested?()
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Simple Timer-Based Wave Animation
    private func startWaveAnimation() {
        // Stop any existing timer first
        stopWaveAnimation()
        
        // Reset to start position
        activeIndex = 0
        
        // Create timer that cycles activeIndex: 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 0 → 1...
        waveTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            DispatchQueue.main.async {
                self.activeIndex = (self.activeIndex + 1) % 8  // Cycle 0,1,2,3,4,5,6,7,0,1,2...
                print("🔴 [WAVE] activeIndex: \(self.activeIndex)")
            }
        }
        print("🔴 [WAVE] Started wave animation timer")
    }
    
    private func stopWaveAnimation() {
        waveTimer?.invalidate()
        waveTimer = nil
        activeIndex = 0
        print("🔴 [WAVE] Stopped wave animation timer")
    }
}
