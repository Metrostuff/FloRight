//
//  UltraSimpleRecordingManager.swift
//  FloRight - ABSOLUTELY NO UI, JUST RECORDING
//

import Foundation
import AVFoundation
import AppKit

class UltraSimpleRecordingManager: NSObject, ObservableObject {
    @Published var recordingState = RecordingState()
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private let textInsertionManager = TextInsertionManager()
    
    // NO UI COMPONENTS AT ALL - ZERO COMPLEXITY
    
    override init() {
        super.init()
        print("🔥 [ULTRA-SIMPLE] Initializing ZERO-COMPLEXITY recording")
        requestPermissions()
    }
    
    private func requestPermissions() {
        AVAudioApplication.requestRecordPermission { granted in
            print("🔥 [ULTRA-SIMPLE] Microphone permission: \(granted)")
        }
    }
    
    func startRecording() {
        guard !recordingState.isRecording else { return }
        
        print("🔥 [ULTRA-SIMPLE] Starting recording - NO UI, NO COMPLEXITY")
        recordingState.startRecording()
        
        // Create recording URL
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "floright_ultra_simple_\(Date().timeIntervalSince1970).wav"
        recordingURL = tempDir.appendingPathComponent(fileName)
        
        guard let url = recordingURL else {
            recordingState.error("Failed to create recording URL")
            return
        }
        
        // Ultra-simple settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            // JUST RECORD - NO UI, NO TIMERS, NO WINDOWS
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.prepareToRecord()
            
            let success = audioRecorder?.record() ?? false
            
            if success {
                print("🔥 [ULTRA-SIMPLE] ✅ Recording started - ZERO UI COMPLEXITY!")
            } else {
                recordingState.error("Failed to start recording")
            }
            
        } catch {
            print("🔥 [ULTRA-SIMPLE] ❌ Recording error: \(error)")
            recordingState.error("Recording setup failed")
        }
    }
    
    func stopRecording() {
        print("🔥 [ULTRA-SIMPLE] Stopping recording - NO UI TO CLEANUP")
        
        // JUST STOP - NO UI CLEANUP NEEDED
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
            print("🔥 [ULTRA-SIMPLE] Recording file size: \(fileSize) bytes")
            
            if fileSize > 0 {
                // Success! Insert test text
                let testText = "ULTRA-SIMPLE recording completed! Zero UI complexity!"
                
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
            print("🔥 [ULTRA-SIMPLE] File check error: \(error)")
            recordingState.error("File processing failed")
        }
        
        // Ultra-simple cleanup
        audioRecorder = nil
        recordingURL = nil
        print("🔥 [ULTRA-SIMPLE] ✅ Zero-complexity cleanup complete")
    }
    
    deinit {
        print("🔥 [ULTRA-SIMPLE] Deallocated - no complex cleanup needed")
        audioRecorder?.stop()
        audioRecorder = nil
    }
}
