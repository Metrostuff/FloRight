//
//  RecordingState.swift
//  FloRight
//
//  Recording state management for UI updates
//

import Foundation
import SwiftUI

class RecordingState: ObservableObject {
    @Published var isVisible = false
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var audioLevel: Float = 0.0
    @Published var lastError: String?
    @Published var lastResult: String?
    @Published var statusText: String = "Ready"
    
    private var isDeactivated = false
    
    func startRecording() {
        guard !isDeactivated else { return }
        isVisible = true
        isRecording = true
        isProcessing = false
        lastError = nil
        lastResult = nil
        statusText = "Recording..."
        print("📱 [STATE] Recording started")
    }
    
    func stopRecording() {
        guard !isDeactivated else { return }
        isRecording = false
        isProcessing = true
        statusText = "Processing..."
        print("📱 [STATE] Recording stopped, processing...")
    }
    
    func complete(result: String = "Recording completed") {
        guard !isDeactivated else { return }
        isRecording = false
        isProcessing = false
        lastResult = result
        lastError = nil
        statusText = result
        
        // Hide pill after completion
        withAnimation {
            self.isVisible = false
        }
        
        print("📱 [STATE] Recording completed: \(result)")
    }
    
    func error(_ message: String) {
        guard !isDeactivated else { return }
        isRecording = false
        isProcessing = false
        lastError = message
        lastResult = nil
        statusText = "Error: \(message)"
        
        // Hide pill after error
        withAnimation {
            self.isVisible = false
        }
        
        print("📱 [STATE] Recording error: \(message)")
    }
    
    func deactivate() {
        print("📱 [STATE] Deactivating RecordingState")
        isDeactivated = true
        
        // Reset all state immediately
        isVisible = false
        isRecording = false
        isProcessing = false
        audioLevel = 0.0
        statusText = "Ready"
        lastError = nil
        lastResult = nil
        
        print("📱 [STATE] RecordingState deactivated")
    }
    
    var status: String {
        return statusText
    }
}
