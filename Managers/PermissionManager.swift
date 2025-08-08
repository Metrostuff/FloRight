//
//  PermissionManager.swift
//  FloRight
//
//  Centralized permission handling for microphone and accessibility
//

import Foundation
import AVFoundation
import ApplicationServices

class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    // MARK: - Permission Status
    
    struct PermissionStatus {
        let microphone: Bool
        let accessibility: Bool
        
        var allGranted: Bool {
            return microphone && accessibility
        }
    }
    
    private init() {
        print("🔐 [PERMISSIONS] PermissionManager initialized")
    }
    
    // MARK: - Current Status Checks
    
    func isMicrophoneAuthorized() -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        print("🔐 [PERMISSIONS] [DEBUG] Microphone authorizationStatus: \(status.rawValue) (\(status))")
        let result = status == .authorized
        print("🔐 [PERMISSIONS] [DEBUG] Microphone authorized: \(result)")
        return result
    }
    
    func isAccessibilityAuthorized() -> Bool {
        print("🔐 [PERMISSIONS] [DEBUG] Calling AXIsProcessTrusted()...")
        
        // Get bundle identifier for comparison
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
        print("🔐 [PERMISSIONS] [DEBUG] App bundle ID: \(bundleId)")
        
        // Call the API safely
        let result = AXIsProcessTrusted()
        print("🔐 [PERMISSIONS] [DEBUG] AXIsProcessTrusted() returned: \(result)")
        
        return result
    }
    
    func getCurrentStatus() -> PermissionStatus {
        let micStatus = isMicrophoneAuthorized()
        let accStatus = isAccessibilityAuthorized()
        
        print("🔐 [PERMISSIONS] Current status - Microphone: \(micStatus), Accessibility: \(accStatus)")
        
        return PermissionStatus(
            microphone: micStatus,
            accessibility: accStatus
        )
    }
    
    // MARK: - App Launch Permission Check (Silent)
    
    func checkPermissionsOnLaunch(completion: @escaping (PermissionStatus) -> Void) {
        print("🔐 [PERMISSIONS] Checking permissions silently on launch...")
        
        let currentStatus = getCurrentStatus()
        
        // Only request if truly not determined - never prompt if already granted/denied
        var needsMicrophoneRequest = false
        var needsAccessibilityPrompt = false
        
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if micStatus == .notDetermined {
            needsMicrophoneRequest = true
        }
        
        // For accessibility, only show dialog if not determined AND not already granted
        if !currentStatus.accessibility && !hasAskedForAccessibilityBefore() {
            needsAccessibilityPrompt = true
        }
        
        if needsMicrophoneRequest {
            print("🔐 [PERMISSIONS] 🎤 Requesting microphone (first time)...")
            requestMicrophonePermissionIfNeeded { [weak self] micGranted in
                guard let self = self else { return }
                
                if needsAccessibilityPrompt {
                    self.requestAccessibilityPermissionIfNeeded { accGranted in
                        let finalStatus = PermissionStatus(
                            microphone: micGranted,
                            accessibility: accGranted
                        )
                        completion(finalStatus)
                    }
                } else {
                    let finalStatus = PermissionStatus(
                        microphone: micGranted,
                        accessibility: currentStatus.accessibility
                    )
                    completion(finalStatus)
                }
            }
        } else if needsAccessibilityPrompt {
            print("🔐 [PERMISSIONS] 🔐 Requesting accessibility (first time)...")
            requestAccessibilityPermissionIfNeeded { accGranted in
                let finalStatus = PermissionStatus(
                    microphone: currentStatus.microphone,
                    accessibility: accGranted
                )
                completion(finalStatus)
            }
        } else {
            print("🔐 [PERMISSIONS] ✅ All permissions already determined - no prompting needed")
            completion(currentStatus)
        }
    }
    
    // MARK: - Silent Permission Re-checking (applicationDidBecomeActive)
    
    func recheckPermissions() {
        print("🔐 [PERMISSIONS] 🔄 Re-checking permissions silently...")
        
        let currentStatus = getCurrentStatus()
        
        // Just log the current state - never prompt on re-check
        if currentStatus.allGranted {
            print("🔐 [PERMISSIONS] ✅ All permissions now granted - FloRight fully functional!")
            
            // Notify that permissions are now ready
            NotificationCenter.default.post(
                name: NSNotification.Name("PermissionsChanged"),
                object: nil,
                userInfo: ["status": currentStatus]
            )
        } else {
            print("🔐 [PERMISSIONS] ⚠️ Still missing permissions:")
            print("🔐 [PERMISSIONS] - Microphone: \(currentStatus.microphone ? "✅" : "❌")")
            print("🔐 [PERMISSIONS] - Accessibility: \(currentStatus.accessibility ? "✅" : "❌")")
        }
    }
    
    private func hasAskedForAccessibilityBefore() -> Bool {
        // Simple check - if it's denied, we've asked before
        // If it's granted, we don't need to ask
        // Only ask if we've never asked (first launch)
        return UserDefaults.standard.bool(forKey: "HasRequestedAccessibilityPermission")
    }
    
    private func markAccessibilityAsked() {
        UserDefaults.standard.set(true, forKey: "HasRequestedAccessibilityPermission")
    }
    
    private func requestMicrophonePermissionIfNeeded(completion: @escaping (Bool) -> Void) {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch currentStatus {
        case .authorized:
            print("🔐 [PERMISSIONS] ✅ Microphone already authorized")
            completion(true)
            
        case .notDetermined:
            print("🔐 [PERMISSIONS] 🎤 Requesting microphone permission...")
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    print("🔐 [PERMISSIONS] 🎤 Microphone permission result: \(granted)")
                    completion(granted)
                }
            }
            
        case .denied, .restricted:
            print("🔐 [PERMISSIONS] ❌ Microphone permission denied/restricted")
            completion(false)
            
        @unknown default:
            print("🔐 [PERMISSIONS] ⚠️ Unknown microphone permission status")
            completion(false)
        }
    }
    
    private func requestAccessibilityPermissionIfNeeded(completion: @escaping (Bool) -> Void) {
        let currentStatus = AXIsProcessTrusted()
        
        if currentStatus {
            print("🔐 [PERMISSIONS] ✅ Accessibility already authorized")
            completion(true)
        } else {
            print("🔐 [PERMISSIONS] 🔐 Requesting accessibility permission...")
            
            // Mark that we've asked before
            markAccessibilityAsked()
            
            // FIXED: Only use AXIsProcessTrustedWithOptions to SHOW the dialog
            // This will show System Settings dialog
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            let _ = AXIsProcessTrustedWithOptions(options)
            
            // CRITICAL: Don't rely on the return value of AXIsProcessTrustedWithOptions
            // It shows the dialog, but permission isn't granted immediately
            // The user needs to manually enable it in System Settings
            print("🔐 [PERMISSIONS] 💡 Dialog shown - user must enable in System Settings manually")
            
            // Return false since permission isn't granted yet (user needs to act)
            completion(false)
        }
    }
    
    // MARK: - Recording Flow Validation
    
    func validatePermissionsForRecording() -> (canRecord: Bool, missingPermissions: [String]) {
        let status = getCurrentStatus()
        var missing: [String] = []
        
        // FIXED: Only microphone required for recording
        // Accessibility only affects text insertion, not recording capability
        if !status.microphone {
            missing.append("Microphone")
        }
        
        // NOTE: Accessibility not required for recording - only for text insertion
        // Recording works fine, text just goes to clipboard if accessibility missing
        
        let canRecord = missing.isEmpty
        
        if !canRecord {
            print("🔐 [PERMISSIONS] ❌ Cannot record - missing: \(missing.joined(separator: ", "))")
        } else {
            print("🔐 [PERMISSIONS] ✅ Recording permissions valid")
            if !status.accessibility {
                print("🔐 [PERMISSIONS] ⚠️ Note: Text will go to clipboard (accessibility not granted)")
            }
        }
        
        return (canRecord: canRecord, missingPermissions: missing)
    }
    
    // MARK: - Error Messages
    
    func getPermissionErrorMessage(missingPermissions: [String]) -> String {
        if missingPermissions.contains("Microphone") && missingPermissions.contains("Accessibility") {
            return "FloRight needs microphone and accessibility permissions to work. Please grant both in System Settings."
        } else if missingPermissions.contains("Microphone") {
            return "FloRight needs microphone access to record audio. Please grant permission in System Settings."
        } else if missingPermissions.contains("Accessibility") {
            return "FloRight needs accessibility access to insert text. Please grant permission in System Settings."
        } else {
            return "FloRight needs additional permissions to work properly."
        }
    }
}
