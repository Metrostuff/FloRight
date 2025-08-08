//
//  TextInsertionManager.swift
//  FloRight
//
//  Implements the Never-Lose Text Guarantee with smart three-step fallback
//

import Cocoa

class TextInsertionManager {
    private var clickMonitor: Any?
    private var pendingText: String?
    private var monitorTimer: Timer?
    
    func insertText(_ text: String, completion: @escaping (Bool, String?) -> Void) {
        print("📝 TextInsertionManager.insertText() called with: \(text.prefix(50))...")
        
        // STEP 1: Always copy to clipboard first (Never-lose guarantee)
        NSPasteboard.general.clearContents()
        let clipboardSuccess = NSPasteboard.general.setString(text, forType: .string)
        
        if !clipboardSuccess {
            print("📝 ❌ Failed to copy to clipboard")
            completion(false, "Failed to copy text")
            return
        }
        
        print("📝 ✅ Text copied to clipboard as backup")
        
        // STEP 2: Try direct insertion into focused text field (if enabled)
        if AppSettings.shared.autoInsertText && insertDirectly(text) {
            print("📝 ✅ Direct insertion successful")
            completion(true, "✓ Inserted into text field")
            return
        }
        
        // STEP 3: Try automatic paste via Cmd+V (if enabled)
        if AppSettings.shared.autoInsertText {
            print("📝 Attempting automatic paste with Cmd+V...")
            simulateKeyboardInput()
            
            // Give the paste a moment to work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                completion(true, "📋 Pasted via Cmd+V")
            }
        } else {
            print("📝 Auto-insert disabled - clipboard only")
            completion(true, "📋 Saved to clipboard")
        }
    }
    
    private func insertDirectly(_ text: String) -> Bool {
        print("📝 Attempting direct insertion...")
        
        // Check accessibility permissions
        let accessEnabled = AXIsProcessTrusted()
        if !accessEnabled {
            print("📝 ⚠️ Accessibility permissions not granted - using fallback")
            return false
        }
        
        // Get focused element
        let systemElement = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard result == .success, let element = focusedElement else {
            print("📝 ⚠️ No focused element - using fallback")
            return false
        }
        
        let axElement = element as! AXUIElement
        
        // Check if element is text editable
        if !isTextEditable(element: axElement) {
            print("📝 ⚠️ Focused element not text editable - using fallback")
            return false
        }
        
        // Try to insert text directly
        let setResult = AXUIElementSetAttributeValue(axElement, kAXValueAttribute as CFString, text as CFTypeRef)
        
        if setResult == .success {
            print("📝 ✅ Direct text insertion successful!")
            return true
        }
        
        // Try to append to existing text
        var existingValue: CFTypeRef?
        let getResult = AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &existingValue)
        
        if getResult == .success, let existing = existingValue as? String {
            let newText = existing + text
            let appendResult = AXUIElementSetAttributeValue(axElement, kAXValueAttribute as CFString, newText as CFTypeRef)
            
            if appendResult == .success {
                print("📝 ✅ Text appended successfully!")
                return true
            }
        }
        
        print("📝 ⚠️ Direct insertion failed - using fallback")
        return false
    }
    
    private func isTextEditable(element: AXUIElement) -> Bool {
        var role: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        guard result == .success, let roleString = role as? String else {
            return false
        }
        
        let editableRoles = [
            "AXTextField",
            "AXTextArea", 
            "AXComboBox",
            "AXSearchField",
            "AXSecureTextField"
        ]
        
        let isEditable = editableRoles.contains(roleString)
        print("📝 Element role: \(roleString), editable: \(isEditable)")
        
        return isEditable
    }
    
    private func simulateKeyboardInput() {
        print("📝 Simulating Cmd+V paste...")
        
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else { 
            print("📝 ❌ Failed to create event source")
            return 
        }
        
        // Create Cmd+V key down event
        if let vKeyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: 0x09, keyDown: true) {
            vKeyDown.flags = .maskCommand
            vKeyDown.post(tap: .cghidEventTap)
            
            // Create Cmd+V key up event after small delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if let vKeyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: 0x09, keyDown: false) {
                    vKeyUp.flags = .maskCommand
                    vKeyUp.post(tap: .cghidEventTap)
                    print("📝 ✅ Cmd+V sent successfully")
                }
            }
        }
    }
    
    // Helper to request accessibility permissions
    func requestAccessibilityPermissions() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if accessEnabled {
            print("📝 ✅ Accessibility permissions granted")
        } else {
            print("📝 ⚠️ Accessibility permissions needed for direct text insertion")
            print("📝 💡 Grant permissions in System Settings > Privacy & Security > Accessibility")
        }
        
        return accessEnabled
    }
    
    private func getCurrentAppName() -> String {
        return NSWorkspace.shared.frontmostApplication?.localizedName ?? "app"
    }
    
    deinit {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
        }
        monitorTimer?.invalidate()
    }
}

// MARK: - Accessibility Setup
/*
To enable direct text insertion, FloRight needs accessibility permissions:

1. Add to Info.plist:
   <key>NSAppleEventsUsageDescription</key>
   <string>FloRight inserts transcribed text directly into applications.</string>

2. Request permissions on first launch:
   textInsertionManager.requestAccessibilityPermissions()

3. User grants permission in: System Settings > Privacy & Security > Accessibility > FloRight
*/
