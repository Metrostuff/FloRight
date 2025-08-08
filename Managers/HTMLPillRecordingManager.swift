//
//  HTMLPillRecordingManager.swift  
//  FloRight - Self-contained HTML5 pill approach
//

import Foundation
import AVFoundation
import AppKit
import WebKit

class HTMLPillRecordingManager: NSObject, ObservableObject {
    @Published var recordingState = RecordingState()
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private let textInsertionManager = TextInsertionManager()
    
    // SELF-CONTAINED HTML5 PILL - No direct NSWindow management
    private var pillWebView: WKWebView?
    private var pillWindow: NSWindow?
    private var audioLevelTimer: Timer?
    
    override init() {
        super.init()
        print("🌐 [HTML-PILL] Initializing self-contained HTML5 pill approach")
        setupHTMLPill()
        requestPermissions()
    }
    
    private func requestPermissions() {
        AVAudioApplication.requestRecordPermission { granted in
            print("🌐 [HTML-PILL] Microphone permission: \(granted)")
        }
    }
    
    // MARK: - Self-Contained HTML5 Pill
    
    private func setupHTMLPill() {
        guard AppSettings.shared.showRecordingPill else {
            print("🌐 [HTML-PILL] Pill disabled in settings")
            return
        }
        
        // Create WKWebView configuration
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "pillController")
        
        // Create small webview for the pill
        let pillFrame = NSRect(x: 0, y: 0, width: 200, height: 40)
        pillWebView = WKWebView(frame: pillFrame, configuration: config)
        
        // Load self-contained HTML pill
        loadPillHTML()
        
        print("🌐 [HTML-PILL] ✅ Self-contained HTML5 pill setup complete")
    }
    
    private func loadPillHTML() {
        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                
                body {
                    width: 200px;
                    height: 40px;
                    background: transparent;
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    overflow: hidden;
                }
                
                .pill {
                    width: 180px;
                    height: 32px;
                    background: rgba(0, 0, 0, 0.85);
                    border-radius: 16px;
                    display: flex;
                    align-items: center;
                    padding: 0 12px;
                    margin: 4px 10px;
                    opacity: 0;
                    transform: translateY(10px);
                    transition: all 0.3s ease;
                }
                
                .pill.visible {
                    opacity: 1;
                    transform: translateY(0);
                }
                
                .dots {
                    display: flex;
                    gap: 4px;
                    margin-right: 8px;
                }
                
                .dot {
                    width: 3px;
                    height: 3px;
                    background: #00ff00;
                    border-radius: 50%;
                    opacity: 0.3;
                    transition: all 0.1s ease;
                }
                
                .dot.active {
                    opacity: 1;
                    transform: scale(1.2);
                }
                
                .text {
                    color: white;
                    font-size: 11px;
                    font-weight: 500;
                }
            </style>
        </head>
        <body>
            <div class="pill" id="pill">
                <div class="dots">
                    <div class="dot" id="dot0"></div>
                    <div class="dot" id="dot1"></div>
                    <div class="dot" id="dot2"></div>
                    <div class="dot" id="dot3"></div>
                    <div class="dot" id="dot4"></div>
                </div>
                <div class="text" id="text">Recording...</div>
            </div>
            
            <script>
                let audioLevel = 0;
                
                function showPill() {
                    const pill = document.getElementById('pill');
                    pill.classList.add('visible');
                    console.log('HTML5 pill shown');
                }
                
                function hidePill() {
                    const pill = document.getElementById('pill');
                    pill.classList.remove('visible');
                    console.log('HTML5 pill hidden');
                }
                
                function updateAudioLevel(level) {
                    audioLevel = Math.max(0, Math.min(1, level));
                    
                    for (let i = 0; i < 5; i++) {
                        const dot = document.getElementById('dot' + i);
                        const threshold = i * 0.2;
                        
                        if (audioLevel > threshold) {
                            dot.classList.add('active');
                        } else {
                            dot.classList.remove('active');
                        }
                    }
                }
                
                function setText(text) {
                    document.getElementById('text').textContent = text;
                }
                
                // Expose functions to Swift
                window.pillAPI = {
                    show: showPill,
                    hide: hidePill,
                    updateLevel: updateAudioLevel,
                    setText: setText
                };
                
                console.log('HTML5 pill loaded and ready');
            </script>
        </body>
        </html>
        """
        
        pillWebView?.loadHTMLString(htmlContent, baseURL: nil)
    }
    
    private func showHTMLPill() {
        guard let webView = pillWebView else { return }
        
        // Create window for the pill
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.frame
        let pillX = (screenFrame.width - 200) / 2
        let pillY: CGFloat = 80
        
        let windowFrame = NSRect(x: pillX, y: pillY, width: 200, height: 40)
        
        pillWindow = NSWindow(
            contentRect: windowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        pillWindow?.level = .floating
        pillWindow?.backgroundColor = .clear
        pillWindow?.isOpaque = false
        pillWindow?.ignoresMouseEvents = true
        pillWindow?.hasShadow = false
        
        pillWindow?.contentView = webView
        pillWindow?.orderFront(nil)
        
        // Show the pill via JavaScript
        webView.evaluateJavaScript("window.pillAPI.show()") { _, error in
            if let error = error {
                print("🌐 [HTML-PILL] Show error: \(error)")
            } else {
                print("🌐 [HTML-PILL] ✅ HTML5 pill shown at bottom center")
            }
        }
    }
    
    private func hideHTMLPill() {
        guard let webView = pillWebView else { return }
        
        print("🌐 [HTML-PILL] Hiding HTML5 pill immediately (no delays)")
        
        // Hide via JavaScript (no callback waiting)
        webView.evaluateJavaScript("window.pillAPI.hide()")
        
        // CRITICAL: Clean up window IMMEDIATELY (no delays)
        pillWindow?.orderOut(nil)
        pillWindow?.close()
        pillWindow = nil
        
        print("🌐 [HTML-PILL] ✅ HTML5 pill hidden immediately - no async delays")
    }
    
    private func updatePillAudioLevel(_ level: Float) {
        guard let webView = pillWebView else { return }
        
        webView.evaluateJavaScript("window.pillAPI.updateLevel(\(level))") { _, error in
            if let error = error {
                print("🌐 [HTML-PILL] Audio level update error: \(error)")
            }
        }
    }
    
    // MARK: - Recording Logic (Same as before)
    
    func startRecording() {
        guard !recordingState.isRecording else { return }
        
        print("🌐 [HTML-PILL] Starting recording with HTML5 pill")
        recordingState.startRecording()
        
        // Create recording URL
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "floright_html_pill_\(Date().timeIntervalSince1970).wav"
        recordingURL = tempDir.appendingPathComponent(fileName)
        
        guard let url = recordingURL else {
            recordingState.error("Failed to create recording URL")
            return
        }
        
        // Simple recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.isMeteringEnabled = true
            
            let success = audioRecorder?.record() ?? false
            
            if success {
                print("🌐 [HTML-PILL] ✅ Recording started with HTML5 visual feedback")
                
                // Show HTML5 pill
                showHTMLPill()
                startAudioLevelMonitoring()
                
            } else {
                recordingState.error("Failed to start recording")
            }
            
        } catch {
            print("🌐 [HTML-PILL] ❌ Recording error: \(error)")
            recordingState.error("Recording setup failed")
        }
    }
    
    func stopRecording() {
        print("🌐 [HTML-PILL] Stopping recording")
        
        // Stop monitoring and hide pill
        stopAudioLevelMonitoring()
        hideHTMLPill()
        
        audioRecorder?.stop()
        recordingState.stopRecording()
        
        processRecording()
    }
    
    private func processRecording() {
        guard let url = recordingURL else {
            recordingState.error("No recording URL")
            return
        }
        
        // Check file was created
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("🌐 [HTML-PILL] Recording file size: \(fileSize) bytes")
            
            if fileSize > 0 {
                let testText = "HTML5 pill recording completed! Self-contained animations!"
                
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
            print("🌐 [HTML-PILL] File check error: \(error)")
            recordingState.error("File processing failed")
        }
        
        // Simple cleanup
        audioRecorder = nil
        recordingURL = nil
        print("🌐 [HTML-PILL] ✅ Recording cleanup complete")
    }
    
    private func startAudioLevelMonitoring() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self,
                  let recorder = self.audioRecorder else { return }
            
            recorder.updateMeters()
            let averagePower = recorder.averagePower(forChannel: 0)
            let normalizedLevel = max(0, min(1, (averagePower + 50) / 50))
            
            // Update both HTML pill and recordingState
            self.recordingState.audioLevel = normalizedLevel
            self.updatePillAudioLevel(normalizedLevel)
        }
        print("🌐 [HTML-PILL] ✅ Audio level monitoring started")
    }
    
    private func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        print("🌐 [HTML-PILL] ✅ Audio level monitoring stopped")
    }
    
    deinit {
        print("🌐 [HTML-PILL] Deallocating - self-contained cleanup")
        
        // Deactivate recording state to prevent crashes
        recordingState.deactivate()
        
        stopAudioLevelMonitoring()
        hideHTMLPill()
        audioRecorder?.stop()
        audioRecorder = nil
        
        print("🌐 [HTML-PILL] ✅ Complete cleanup finished")
    }
}

// MARK: - WebView Message Handler
extension HTMLPillRecordingManager: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Handle any messages from the HTML pill if needed
        print("🌐 [HTML-PILL] Message from pill: \(message.body)")
    }
}
