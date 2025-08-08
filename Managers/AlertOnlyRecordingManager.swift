import SwiftUI
import AppKit
import AVFoundation

// MARK: - ULTRA-SIMPLE ALERT-ONLY RecordingManager (no window manipulation)
class AlertOnlyRecordingManager: NSObject, ObservableObject {
    @Published var recordingState = RecordingState()
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private let textInsertionManager = TextInsertionManager()
    
    override init() {
        super.init()
        print("🚨 [ALERT-ONLY] Initializing ULTRA-SIMPLE recording manager")
        requestPermissions()
    }
    
    private func requestPermissions() {
        AVAudioApplication.requestRecordPermission { granted in
            print("🚨 [ALERT-ONLY] Microphone permission: \(granted)")
        }
    }
    
    func startRecording() {
        guard !recordingState.isRecording else { return }
        
        print("🚨 [ALERT-ONLY] Starting recording - NO UI")
        recordingState.startRecording()
        
        // NO ALERTS AT ALL - just console logging
        print("🚨 [ALERT-ONLY] 🎤 RECORDING STARTED - No visual feedback")
        
        // Create recording URL
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "floright_alert_test_\(Date().timeIntervalSince1970).wav"
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
            
            let success = audioRecorder?.record() ?? false
            
            if success {
                print("🚨 [ALERT-ONLY] ✅ Recording started successfully")
            } else {
                recordingState.error("Failed to start recording")
            }
            
        } catch {
            print("🚨 [ALERT-ONLY] ❌ Recording error: \(error)")
            recordingState.error("Recording setup failed")
        }
    }
    
    func stopRecording() {
        print("🚨 [ALERT-ONLY] Stopping recording - NO UI")
        
        // NO ALERTS AT ALL - just immediate stop
        audioRecorder?.stop()
        recordingState.stopRecording()
        
        print("🚨 [ALERT-ONLY] ⏹️ RECORDING STOPPED - Processing...")
        
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
            print("🚨 [ALERT-ONLY] Recording file size: \(fileSize) bytes")
            
            if fileSize > 0 {
                let testText = "ULTRA-SIMPLE test recording completed! No UI, no crashes!"
                
                textInsertionManager.insertText(testText) { [weak self] success, message in
                    DispatchQueue.main.async {
                        if success {
                            self?.recordingState.complete()
                            print("🚨 [ALERT-ONLY] ✅ Text inserted successfully")
                        } else {
                            self?.recordingState.error(message ?? "Text insertion failed")
                            print("🚨 [ALERT-ONLY] ❌ Text insertion failed")
                        }
                    }
                }
            } else {
                recordingState.error("Empty recording")
            }
            
            // Clean up
            try? FileManager.default.removeItem(at: url)
            
        } catch {
            print("🚨 [ALERT-ONLY] File check error: \(error)")
            recordingState.error("File processing failed")
        }
        
        // Simple cleanup
        audioRecorder = nil
        recordingURL = nil
        print("🚨 [ALERT-ONLY] ✅ Simple cleanup complete")
    }
    
    deinit {
        print("🚨 [ALERT-ONLY] Deallocating - minimal cleanup")
        audioRecorder?.stop()
        audioRecorder = nil
        print("🚨 [ALERT-ONLY] ✅ Minimal cleanup finished")
    }
}
