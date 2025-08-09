//
//  RecordingPill.swift
//  FloRight
//
//  Modern Task-based animation system (no more race conditions!)
//

import SwiftUI
import Combine

struct RecordingPill: View {
    @ObservedObject var recordingState: RecordingState
    @State private var barScales: [CGFloat] = [0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8]
    @State private var animationTask: Task<Void, Never>? // Modern async task
    
    // Memory debugging
    private let instanceId = UUID().uuidString.prefix(8)
    
    init(recordingState: RecordingState) {
        self.recordingState = recordingState
        print("🎨 [PILL-\(instanceId)] RecordingPill created")
    }
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            
            // Recording pill
            VStack {
                Spacer()
                
                HStack(spacing: 16) {
                    // Animated bars (16 thinner bars instead of 8 dots)
                    HStack(spacing: 2) {
                        ForEach(0..<16) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.white)
                                .frame(width: 2, height: 12)
                                .scaleEffect(x: 1, y: barScales[index])
                        }
                    }
                    
                    // Status text
                    Text(recordingState.statusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                    
                    // Current tone
                    if recordingState.isRecording {
                        Text(AppSettings.shared.selectedTonePreset.rawValue)
                            .font(.system(size: 9, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.9))
                )
                .scaleEffect(recordingState.isRecording ? 1.0 : 0.95)
                .opacity(recordingState.isVisible ? 1.0 : 0.0)
                .animation(.spring(response: 0.3), value: recordingState.isRecording)
                .animation(.easeInOut(duration: 0.2), value: recordingState.isVisible)
                
                Spacer()
                    .frame(height: 80)
            }
        }
        .onAppear {
            print("🎨 [PILL-\(instanceId)] onAppear called")
            startModernAnimation()
        }
        .onDisappear {
            print("🎨 [PILL-\(instanceId)] onDisappear called")
            stopModernAnimation()
        }
    }
    
    // MODERN: Task-based animation (like JavaScript async/await)
    private func startModernAnimation() {
        print("🎨 [PILL-\(instanceId)] Starting modern Task-based animation")
        
        // Cancel any existing animation task
        stopModernAnimation()
        
        // Create new animation task (equivalent to JavaScript Promise)
        animationTask = Task { @MainActor in
            print("🎨 [PILL-\(instanceId)] Animation task started")
            // This runs like a JavaScript promise with cancellation support
            while !Task.isCancelled {
                // Check if we should still be animating
                guard recordingState.isVisible else {
                    print("🎨 [PILL-\(instanceId)] Animation stopping - pill not visible")
                    break
                }
                
                if recordingState.isRecording {
                    // Animate dots based on audio level
                    await animateDotsWithAudioLevel()
                } else {
                    // Reset dots to normal size
                    await resetDotsToNormal()
                }
                
                // Wait for next frame (equivalent to setTimeout in JS)
                try? await Task.sleep(nanoseconds: 80_000_000) // 0.08 seconds
                
                // Check cancellation after sleep
                if Task.isCancelled {
                    print("🎨 [PILL-\(instanceId)] Animation task cancelled")
                    break
                }
            }
            
            print("🎨 [PILL-\(instanceId)] Animation task completed")
        }
    }
    
    // Clean cancellation (like promise.cancel())
    private func stopModernAnimation() {
        if animationTask != nil {
            print("🎨 [PILL-\(instanceId)] Stopping animation task")
            animationTask?.cancel()
            animationTask = nil
            print("🎨 [PILL-\(instanceId)] Animation task stopped")
        }
    }
    
    // MODERN: Async animation functions
    @MainActor
    private func animateDotsWithAudioLevel() async {
        let level = CGFloat(recordingState.audioLevel)
        
        // Animate each bar with wave effect
        for i in 0..<16 {
            guard !Task.isCancelled else { break }
            
            withAnimation(.easeInOut(duration: 0.15)) {
                let baseScale: CGFloat = 0.8
                let maxScale: CGFloat = 2.0
                
                // Create wave effect with actual audio level
                let wavePhase = Double(i) * 0.4 + Date().timeIntervalSince1970 * 4
                let waveMultiplier = (sin(wavePhase) + 1) / 2 // 0 to 1
                
                // Combine audio level with wave animation
                let combinedLevel = level * 0.7 + CGFloat(waveMultiplier) * 0.3
                self.barScales[i] = baseScale + (maxScale - baseScale) * combinedLevel
            }
            
            // Small delay between bars (no DispatchQueue needed!)
            try? await Task.sleep(nanoseconds: 15_000_000) // 0.015 seconds
        }
    }
    
    @MainActor
    private func resetDotsToNormal() async {
        withAnimation(.easeInOut(duration: 0.2)) {
            barScales = [0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8]
        }
    }
}



// Preview
struct RecordingPill_Previews: PreviewProvider {
    static var previews: some View {
        RecordingPill(recordingState: RecordingState())
            .frame(width: 300, height: 200)
    }
}
