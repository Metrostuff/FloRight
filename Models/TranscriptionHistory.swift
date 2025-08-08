//
//  TranscriptionHistory.swift
//  FloRight
//
//  JSON-based transcription history storage - lightweight and simple
//

import Foundation

struct TranscriptionEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let originalText: String
    let processedText: String
    let tone: String
    let targetApp: String?
    
    init(timestamp: Date, originalText: String, processedText: String, tone: String, targetApp: String?) {
        self.id = UUID()
        self.timestamp = timestamp
        self.originalText = originalText
        self.processedText = processedText
        self.tone = tone
        self.targetApp = targetApp
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(timestamp) {
            formatter.dateFormat = "h:mm a"
            return "Today at \(formatter.string(from: timestamp))"
        } else if calendar.isDateInYesterday(timestamp) {
            formatter.dateFormat = "h:mm a"
            return "Yesterday at \(formatter.string(from: timestamp))"
        } else {
            formatter.dateFormat = "MMM d at h:mm a"
            return formatter.string(from: timestamp)
        }
    }
}

@MainActor
class TranscriptionHistory: ObservableObject {
    static let shared = TranscriptionHistory()
    
    @Published var entries: [TranscriptionEntry] = []
    
    private let maxEntries = 1000 // Keep last 1000 transcriptions
    private let fileURL: URL
    
    private init() {
        // Create file URL in app support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                in: .userDomainMask).first!
        let floRightFolder = appSupport.appendingPathComponent("FloRight")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: floRightFolder, 
                                               withIntermediateDirectories: true)
        
        fileURL = floRightFolder.appendingPathComponent("transcriptions.json")
        
        loadHistory()
    }
    
    func addEntry(originalText: String, processedText: String, tone: TonePreset, targetApp: String? = nil, startTime: Date? = nil) {
        let entry = TranscriptionEntry(
            timestamp: startTime ?? Date(),
            originalText: originalText,
            processedText: processedText,
            tone: tone.rawValue,
            targetApp: targetApp
        )
        
        entries.insert(entry, at: 0) // Add to beginning (most recent first)
        
        // Keep only last maxEntries
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        
        saveHistory()
        print("📝 [HISTORY] Added entry: \(processedText.prefix(50))...")
    }
    
    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("📝 [HISTORY] No existing history file - starting fresh")
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            entries = try JSONDecoder().decode([TranscriptionEntry].self, from: data)
            print("📝 [HISTORY] Loaded \(entries.count) entries")
        } catch {
            print("📝 [HISTORY] Error loading history: \(error)")
            // Don't crash - just start with empty history
            entries = []
        }
    }
    
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL)
            print("📝 [HISTORY] Saved \(entries.count) entries")
        } catch {
            print("📝 [HISTORY] Error saving history: \(error)")
        }
    }
    
    // For settings/maintenance
    func clearHistory() {
        entries.removeAll()
        saveHistory()
        print("📝 [HISTORY] History cleared")
    }
    
    func exportHistory() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        var output = "FloRight Transcription History\n"
        output += "Exported on \(formatter.string(from: Date()))\n\n"
        
        for entry in entries {
            output += "[\(formatter.string(from: entry.timestamp))] \(entry.tone)\n"
            output += "\(entry.processedText)\n\n"
        }
        
        return output
    }
}
