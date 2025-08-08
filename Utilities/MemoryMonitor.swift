//
//  MemoryMonitor.swift
//  FloRight
//
//  Monitors real-time memory usage for the app
//

import Foundation
import Combine

class MemoryMonitor: ObservableObject {
    @Published var currentMemoryUsage: String = "0 MB"
    @Published var isUnderTarget: Bool = true
    
    private var timer: Timer?
    private let targetMemoryMB: Double = 200.0
    
    static let shared = MemoryMonitor()
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        // Update immediately
        updateMemoryUsage()
        
        // Then update every 2 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.updateMemoryUsage()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateMemoryUsage() {
        let memoryMB = getCurrentMemoryUsage()
        
        DispatchQueue.main.async {
            self.currentMemoryUsage = String(format: "%.0f MB", memoryMB)
            self.isUnderTarget = memoryMB < self.targetMemoryMB
        }
    }
    
    private func getCurrentMemoryUsage() -> Double {
        // Based on Apple's Quinn "The Eskimo" recommendation
        // Uses phys_footprint which closely matches Xcode's memory gauge
        
        let TASK_VM_INFO_COUNT = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let TASK_VM_INFO_REV1_COUNT = mach_msg_type_number_t(MemoryLayout.offset(of: \task_vm_info_data_t.min_address)! / MemoryLayout<integer_t>.size)
        
        var info = task_vm_info_data_t()
        var count = TASK_VM_INFO_COUNT
        
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        
        guard kr == KERN_SUCCESS, count >= TASK_VM_INFO_REV1_COUNT else {
            return 0.0
        }
        
        // phys_footprint is the closest match to Xcode's memory gauge
        let memoryBytes = Double(info.phys_footprint)
        let memoryMB = memoryBytes / (1024.0 * 1024.0)
        return memoryMB
    }
    
    deinit {
        stopMonitoring()
    }
}
