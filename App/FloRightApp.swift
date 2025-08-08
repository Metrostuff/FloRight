//
//  FloRightApp.swift
//  FloRight
//
//  Created on January 2025
//  Light as a feather. Writes like a pro.
//

import SwiftUI
import Foundation

// Global exception handler for debugging
func setupGlobalExceptionHandler() {
    NSSetUncaughtExceptionHandler { exception in
        print("🚨 [CRASH] Uncaught exception: \(exception)")
        print("🚨 [CRASH] Name: \(exception.name)")
        print("🚨 [CRASH] Reason: \(exception.reason ?? "Unknown")")
        print("🚨 [CRASH] Stack trace: \(exception.callStackSymbols)")
    }
    
    // Set up signal handlers for EXC_BAD_ACCESS
    var sigSegvAction = sigaction()
    sigSegvAction.__sigaction_u.__sa_sigaction = { signal, info, context in
        print("🚨 [CRASH] SIGSEGV (segmentation fault) caught!")
        print("🚨 [CRASH] Signal: \(signal)")
        if let info = info {
            print("🚨 [CRASH] Address: \(String(format: "0x%lx", Int(bitPattern: info.pointee.si_addr)))")
        }
        print("🚨 [CRASH] This is EXC_BAD_ACCESS")
        
        // Print stack trace
        let symbols = Thread.callStackSymbols
        print("🚨 [CRASH] Stack trace:")
        for (index, symbol) in symbols.enumerated() {
            print("🚨 [CRASH] \(index): \(symbol)")
        }
        
        // Try to continue (dangerous but for debugging)
        exit(1)
    }
    sigSegvAction.sa_flags = SA_SIGINFO
    sigaction(SIGSEGV, &sigSegvAction, nil)
    
    print("🚨 [DEBUG] Signal handlers installed")
}

@main
struct FloRightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        print("🚀 [INIT] FloRightApp initializing...")
        setupGlobalExceptionHandler()
        print("🚀 [INIT] Global exception handler set up")
        
        // Enable zombie objects for debugging
        #if DEBUG
        // TEMPORARILY COMMENTED OUT: Testing memory growth
        // setenv("NSZombieEnabled", "YES", 1)
        // setenv("MallocStackLogging", "YES", 1)
        // print("🧟 [DEBUG] Zombie objects enabled for debugging")
        print("🧟 [DEBUG] Zombie debugging temporarily disabled for memory testing")
        #endif
    }
    
    var body: some Scene {
        // We use AppDelegate for menu bar setup, so no window scene here
        Settings {
            EmptyView()
        }
    }
}
