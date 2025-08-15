//
//  FloatingNotificationManager.swift
//  FloRight
//
//  Manages floating notifications that appear at mouse cursor position
//

import SwiftUI
import AppKit

class FloatingNotificationManager: ObservableObject {
    static let shared = FloatingNotificationManager()
    
    private var notificationWindow: NSWindow?
    private var hideTimer: Timer?
    private var isShowing = false  // NEW: Prevent multiple simultaneous notifications
    
    private init() {}
    
    func showNotification(message: String, at mouseLocation: NSPoint? = nil) {
        // NEW: Prevent multiple notifications at once
        guard !isShowing else {
            print("📋 [NOTIFICATION] Already showing notification, ignoring request")
            return
        }
        
        isShowing = true
        
        // Get current mouse location if not provided
        let location = mouseLocation ?? NSEvent.mouseLocation
        
        // Hide any existing notification first
        hideNotificationImmediate()
        
        // Create notification view
        let notificationView = FloatingNotificationView(message: message)
        
        // Calculate window size (approximate)
        let windowWidth: CGFloat = 160
        let windowHeight: CGFloat = 40
        
        // Position above mouse cursor
        let offsetY: CGFloat = 40  // Distance above cursor
        let windowX = location.x - (windowWidth / 2)
        let windowY = location.y + offsetY
        
        // Ensure window stays on screen
        guard let screenFrame = NSScreen.main?.frame else {
            print("📋 [NOTIFICATION] ❌ No main screen available")
            isShowing = false
            return
        }
        
        let adjustedX = max(screenFrame.minX, min(windowX, screenFrame.maxX - windowWidth))
        let adjustedY = max(screenFrame.minY, min(windowY, screenFrame.maxY - windowHeight))
        
        // Create floating window with error handling
        do {
            notificationWindow = NSWindow(
                contentRect: NSRect(x: adjustedX, y: adjustedY, width: windowWidth, height: windowHeight),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            guard let window = notificationWindow else {
                print("📋 [NOTIFICATION] ❌ Failed to create notification window")
                isShowing = false
                return
            }
            
            window.level = .floating
            window.backgroundColor = .clear
            window.isOpaque = false
            window.ignoresMouseEvents = true
            window.hasShadow = false
            window.contentView = NSHostingView(rootView: notificationView)
            
            // Show the window
            window.orderFront(nil)
            
            // Schedule automatic hiding after 1.5 seconds
            hideTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.hideNotification()
                }
            }
            
            print("📋 [NOTIFICATION] Showing floating notification: '\(message)' at (\(adjustedX), \(adjustedY))")
            
        } catch {
            print("📋 [NOTIFICATION] ❌ Error creating notification: \(error)")
            isShowing = false
        }
    }
    
    private func hideNotification() {
        hideTimer?.invalidate()
        hideTimer = nil
        
        if let window = notificationWindow {
            window.orderOut(nil)
            window.close()
            notificationWindow = nil
        }
        
        isShowing = false
        print("📋 [NOTIFICATION] Floating notification hidden")
    }
    
    // NEW: Immediate hide without delay (for cleanup)
    private func hideNotificationImmediate() {
        hideTimer?.invalidate()
        hideTimer = nil
        
        if let window = notificationWindow {
            window.orderOut(nil)
            window.close()
            notificationWindow = nil
        }
        
        // Don't reset isShowing here - let the new notification set it
    }
    
    deinit {
        hideNotificationImmediate()
        isShowing = false
    }
}

// MARK: - Floating Notification View
struct FloatingNotificationView: View {
    let message: String
    @State private var isVisible = false
    
    var body: some View {
        Text(message)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.yellow)  // Yellow text as requested
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.9))  // Opaque background similar to pill
            )
            .scaleEffect(isVisible ? 1.0 : 0.8)
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(.spring(response: 0.3), value: isVisible)
            .onAppear {
                // Use slight delay to ensure smooth animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isVisible = true
                }
            }
    }
}
