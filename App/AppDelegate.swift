//
//  AppDelegate.swift
//  FloRight
//
//  Handles menu bar setup and app lifecycle
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var mainWindow: NSWindow?  // NEW: Main dock-accessible window
    private var recordingManager: SimpleNativePillManager?  // CHANGED: Simple native pill
    private var hotkeyManager: HotkeyManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 [APP] AppDelegate launching...")
        
        // Request all permissions if needed (first launch only)
        requestPermissionsIfNeeded()
        
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true
            button.action = #selector(toggleMenu)
            button.target = self
        }
        
        // Initialize SIMPLE NATIVE PILL managers
        print("🚀 [APP] Creating simple native pill recording manager...")
        recordingManager = SimpleNativePillManager()  // CHANGED: Simple native approach
        print("🚀 [APP] Creating HotkeyManager...")
        hotkeyManager = HotkeyManager()
        hotkeyManager?.setRecordingManager(recordingManager!)
        
        // Connect UI stop callback for latch mode
        recordingManager?.onStopRequested = { [weak hotkeyManager] in
            hotkeyManager?.stopRecordingFromUI()
        }
        
        print("🚀 [APP] ✅ Simple native pill managers initialized")
        
        // Set up menu
        setupMenu()
        
        // Enable dock icon (changed from .accessory to .regular)
        NSApp.setActivationPolicy(.regular)
        
        print("🚀 [APP] AppDelegate launch complete")
    }
    
    private func requestPermissionsIfNeeded() {
        PermissionManager.shared.checkPermissionsOnLaunch { status in
            if status.allGranted {
                print("🚀 [APP] ✅ All permissions granted - FloRight ready!")
            } else {
                print("🚀 [APP] ⚠️ Some permissions missing:")
                print("🚀 [APP] - Microphone: \(status.microphone ? "✅" : "❌")")
                print("🚀 [APP] - Accessibility: \(status.accessibility ? "✅" : "❌")")
                print("🚀 [APP] 💡 Grant missing permissions in System Settings for full functionality")
                
                // SHOW CLEAR STARTUP MESSAGE IF CRITICAL PERMISSIONS MISSING
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if !status.microphone {
                        let alert = NSAlert()
                        alert.messageText = "FloRight Setup Required"
                        alert.informativeText = "FloRight needs microphone permission to work.\n\nWithout this permission, recording will not function.\n\nWould you like to open System Settings now?"
                        alert.alertStyle = .informational
                        alert.addButton(withTitle: "Open System Settings")
                        alert.addButton(withTitle: "Later")
                        
                        let response = alert.runModal()
                        if response == .alertFirstButtonReturn {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    } else if !status.accessibility {
                        let alert = NSAlert()
                        alert.messageText = "FloRight Ready (with Clipboard)"
                        alert.informativeText = "FloRight will copy transcriptions to your clipboard.\n\nFor automatic text insertion, grant Accessibility permission in System Settings.\n\nWould you like to set this up now?"
                        alert.alertStyle = .informational
                        alert.addButton(withTitle: "Open System Settings")
                        alert.addButton(withTitle: "Use Clipboard Only")
                        
                        let response = alert.runModal()
                        if response == .alertFirstButtonReturn {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Permission Re-checking (Best Practice)
    
    func applicationDidBecomeActive(_ notification: Notification) {
        print("🚀 [APP] App became active - re-checking permissions...")
        PermissionManager.shared.recheckPermissions()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Handle dock icon click
        if !flag {
            openMainWindow()
        }
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("🚀 [APP] Application terminating - cleaning up...")
        
        // CRITICAL: Clean up all managers before termination
        print("🚀 [APP] Cleaning up HotkeyManager...")
        hotkeyManager?.cleanup()
        hotkeyManager = nil
        print("🚀 [APP] ✅ HotkeyManager cleaned up")
        
        print("🚀 [APP] Cleaning up simple native pill recording manager...")
        recordingManager = nil
        print("🚀 [APP] ✅ Simple native pill recording manager cleaned up")
        
        // Clear status item
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
        
        // Close windows
        settingsWindow?.close()
        settingsWindow = nil
        mainWindow?.close()
        mainWindow = nil
        
        print("🚀 [APP] Application cleanup complete")
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Open FloRight", action: #selector(openMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        
        // Add test mode for development
        menu.addItem(NSMenuItem(title: "🧪 Test Mode (Stay on Top)", action: #selector(enableTestMode), keyEquivalent: "t"))
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "About FloRight", action: #selector(openAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Check for Updates", action: #selector(checkForUpdates), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc private func toggleMenu() {
        guard let button = statusItem.button else { return }
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(statusItem.menu!, with: event, for: button)
        }
    }
    
    @objc private func openMainWindow() {
        if mainWindow == nil {
            let mainView = MainWindow()
                .environmentObject(AppSettings.shared)
            
            mainWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            
            mainWindow?.center()
            mainWindow?.setFrameAutosaveName("MainWindow")
            mainWindow?.contentView = NSHostingView(rootView: mainView)
            mainWindow?.title = "FloRight"
            mainWindow?.isReleasedWhenClosed = false
            mainWindow?.minSize = NSSize(width: 700, height: 500)
        }
        
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsWindow()
                .environmentObject(AppSettings.shared)
            
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            
            settingsWindow?.center()
            settingsWindow?.setFrameAutosaveName("Settings")
            settingsWindow?.contentView = NSHostingView(rootView: settingsView)
            settingsWindow?.title = "FloRight Settings"
            settingsWindow?.isReleasedWhenClosed = false
            
            // Keep window on top for testing
            settingsWindow?.level = .floating
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func enableTestMode() {
        // Don't open settings - just show instructions
        let alert = NSAlert()
        alert.messageText = "FloRight Simple Native Pill Test 🟡"
        alert.informativeText = "✅ SIMPLE NATIVE PILL\n\n✨ Old school approach: Key press = show pill, key release = hide pill ✨\n\n1. Press and hold RIGHT SHIFT from anywhere\n2. Simple native pill appears at bottom center\n3. Speak while holding\n4. Release when done\n5. Pill disappears, text appears\n\nTesting: Simple SwiftUI pill with direct key press/release events!"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Test Recording")
        alert.addButton(withTitle: "Test Animation Only")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // Log current status for recording test
            print("🟡 SIMPLE NATIVE PILL Mode: Old school approach")
            print("🟡 Expected: Hold RIGHT SHIFT → Native pill shows → Release → Pill hides")
            print("🟡 Testing: Direct key press/release events with native SwiftUI")
        } else if response == .alertSecondButtonReturn {
            // Test animation without recording
            print("🟡 TESTING: Animation test mode enabled - should see pill with cycling animation")
            recordingManager?.enableTestMode()
            
            // Show another alert to stop test
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let stopAlert = NSAlert()
                stopAlert.messageText = "Animation Test Running"
                stopAlert.informativeText = "You should see the pill with dots animating in a cycle. Click OK to stop the test."
                stopAlert.addButton(withTitle: "Stop Test")
                stopAlert.runModal()
                
                self.recordingManager?.disableTestMode()
                print("🟡 TESTING: Animation test mode disabled")
            }
        }
    }
    
    @objc private func openAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    
    @objc private func checkForUpdates() {
        // TODO: Implement update check
        let alert = NSAlert()
        alert.messageText = "You're up to date!"
        alert.informativeText = "FloRight 1.0 is the latest version."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
