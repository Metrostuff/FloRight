//
//  MainWindow.swift
//  FloRight
//
//  The main dock-accessible window showing history and settings
//

import SwiftUI

// Color extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct MainWindow: View {
    @StateObject private var history = TranscriptionHistory.shared
    @EnvironmentObject var settings: AppSettings
    @State private var selectedSection = "recent"
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                // Logo header
                HStack {
                    Image(systemName: "text.bubble.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                    Text("FloRight")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                Divider()
                    .padding(.bottom, 20)
                
                // Navigation items
                VStack(alignment: .leading, spacing: 4) {
                    SidebarItem(
                        icon: "clock",
                        title: "Recent",
                        isSelected: selectedSection == "recent"
                    ) {
                        selectedSection = "recent"
                    }
                    
                    SidebarItem(
                        icon: "text.bubble",
                        title: "Tone Presets",
                        isSelected: selectedSection == "tones"
                    ) {
                        selectedSection = "tones"
                    }
                    
                    SidebarItem(
                        icon: "gearshape",
                        title: "Settings",
                        isSelected: selectedSection == "settings"
                    ) {
                        selectedSection = "settings"
                    }
                    
                    SidebarItem(
                        icon: "questionmark.circle",
                        title: "Help",
                        isSelected: selectedSection == "help"
                    ) {
                        selectedSection = "help"
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .frame(width: 200)
            .background(Color(hex: "#D9E3F8"))
            
            Divider()
            
            // Main content
            VStack(alignment: .leading, spacing: 0) {
                switch selectedSection {
                case "recent":
                    RecentView()
                case "tones":
                    TonePresetsView()
                case "settings":
                    SettingsView()
                case "help":
                    HelpView()
                default:
                    RecentView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 700, minHeight: 500)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            // Invisible buttons for global keyboard shortcuts
            VStack {
                ForEach(TonePreset.allCases) { tone in
                    Button(action: {
                        settings.selectedTonePreset = tone
                    }) {
                        EmptyView()
                    }
                    .keyboardShortcut(KeyEquivalent(Character(tone.keyboardShortcut)), modifiers: .command)
                    .opacity(0)
                    .frame(width: 0, height: 0)
                }
            }
        )
    }
}

struct SidebarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 16)
                    .foregroundColor(.black)
                
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.white.opacity(0.7) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecentView: View {
    @StateObject private var history = TranscriptionHistory.shared
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome Back")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Your dictation history and settings")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            
            // Current tone display
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CURRENT TONE")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    Text(settings.selectedTonePreset.rawValue)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                    
                    Text(settings.selectedTonePreset.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .padding(.horizontal, 30)
            
            // History section
            VStack(alignment: .leading, spacing: 15) {
                Text("Recent Transcriptions")
                    .font(.headline)
                    .padding(.horizontal, 30)
                
                if history.entries.isEmpty {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text("No transcriptions yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Use your hotkey to start dictating")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(history.entries) { entry in
                                HistoryRow(entry: entry)
                                
                                if entry.id != history.entries.last?.id {
                                    Divider()
                                        .padding(.leading, 30)
                                }
                            }
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    .padding(.horizontal, 30)
                }
            }
            
            // Dynamic hotkey hint based on toggle setting and actual hotkey
            HStack {
                let hotkeyDisplay = {
                    switch settings.recordingHotkey.lowercased() {
                    case "rightshift": return "Right Shift"
                    case "leftshift": return "Left Shift"
                    case "f13": return "F13"
                    case "f14": return "F14"
                    case "f15": return "F15"
                    case "uparrow": return "Up Arrow"
                    case "downarrow": return "Down Arrow"
                    case "leftarrow": return "Left Arrow"
                    case "rightarrow": return "Right Arrow"
                    case "space": return "Space" // Legacy support
                    default: return settings.recordingHotkey.capitalized
                    }
                }()
                
                Text(settings.useLatchMode ? 
                     "**Tip:** Press **\(hotkeyDisplay)** once to start recording, press again to stop. FloRight runs in your menu bar, ready when you need it." :
                     "**Tip:** Press and hold **\(hotkeyDisplay)** anywhere to start dictating. FloRight runs in your menu bar, ready when you need it."
                )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(12)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
            
            Spacer()
        }
    }
}

struct HistoryRow: View {
    let entry: TranscriptionEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.timeString)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(entry.processedText)
                .font(.body)
            
            HStack(spacing: 12) {
                Text(entry.tone)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
                
                if let app = entry.targetApp {
                    Text(app)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .contentShape(Rectangle())
        .onTapGesture {
            // Copy to clipboard on tap
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(entry.processedText, forType: .string)
        }
    }
}

struct TonePresetsView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Tone Presets")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal, 30)
                .padding(.top, 30)
            
            Text("Choose how FloRight transforms your speech")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 30)
            
            LazyVStack(spacing: 12) {
                ForEach(TonePreset.allCases) { tone in
                    TonePresetCard(
                        tone: tone,
                        isSelected: settings.selectedTonePreset == tone
                    ) {
                        settings.selectedTonePreset = tone
                    }
                }
            }
            .padding(.horizontal, 30)
            
            Spacer()
        }
    }
}

struct TonePresetCard: View {
    let tone: TonePreset
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(tone.rawValue)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("⌘\(tone.keyboardShortcut)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                        
                        Spacer()
                    }
                    
                    Text(tone.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding(16)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal, 30)
                .padding(.top, 30)
            
            Form {
                Section("Recording") {
                    Picker("Recording Hotkey", selection: $settings.recordingHotkey) {
                        Text("Right Shift").tag("rightshift")
                        Text("Left Shift").tag("leftshift")
                        Text("F13").tag("f13")
                        Text("F14").tag("f14")
                        Text("F15").tag("f15")
                        Text("Up Arrow").tag("uparrow")
                        Text("Down Arrow").tag("downarrow")
                        Text("Left Arrow").tag("leftarrow")
                        Text("Right Arrow").tag("rightarrow")
                    }
                    
                    HStack {
                        Text(settings.useLatchMode ? "(Click to start/stop recording)" : "(Press and hold to record)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    Toggle("Use click-to-toggle recording", isOn: $settings.useLatchMode)
                        .toggleStyle(.switch)
                        .controlSize(.regular)
                    
                    Toggle("Show recording pill overlay", isOn: $settings.showRecordingPill)
                        .toggleStyle(.switch)
                        .controlSize(.regular)
                    
                    Toggle("Play feedback sounds", isOn: $settings.playFeedbackSounds)
                        .toggleStyle(.switch)
                        .controlSize(.regular)
                }
                
                Section("Text Processing") {
                    Toggle("Use UK spelling", isOn: $settings.useUKSpelling)
                        .toggleStyle(.switch)
                        .controlSize(.regular)
                    
                    Toggle("Auto-insert processed text", isOn: $settings.autoInsertText)
                        .toggleStyle(.switch)
                        .controlSize(.regular)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 30)
            
            Spacer()
        }
    }
}

struct HelpView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Help & Support")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal, 30)
                .padding(.top, 30)
            
            VStack(alignment: .leading, spacing: 16) {
                HelpSection(
                    title: "Getting Started",
                    content: getGettingStartedText()
                )
                
                HelpSection(
                    title: "Tone Presets",
                    content: "FloRight's unique tone presets transform your speech:\n• Professional: Formal business language\n• Friendly: Warm, conversational tone\n• Concise: Removes filler, tightens prose\n• Empathetic: Adds emotional intelligence\n• Neutral: Clean transcription"
                )
                
                HelpSection(
                    title: "Keyboard Shortcuts",
                    content: "⌘1-5: Switch between tone presets\n\(getHotkeyDisplay()): Your recording hotkey"
                )
            }
            .padding(.horizontal, 30)
            
            Spacer()
        }
    }
    
    private func getHotkeyDisplay() -> String {
        switch settings.recordingHotkey.lowercased() {
        case "rightshift": return "Right Shift"
        case "leftshift": return "Left Shift"
        case "f13": return "F13"
        case "f14": return "F14"
        case "f15": return "F15"
        case "uparrow": return "Up Arrow"
        case "downarrow": return "Down Arrow"
        case "leftarrow": return "Left Arrow"
        case "rightarrow": return "Right Arrow"
        case "space": return "Space"
        default: return settings.recordingHotkey.capitalized
        }
    }
    
    private func getGettingStartedText() -> String {
        let hotkeyName = getHotkeyDisplay()
        
        if settings.useLatchMode {
            return "Press \(hotkeyName) once to start recording, then press it again to stop. Speak clearly between presses. FloRight will process your speech and insert the text automatically."
        } else {
            return "Press and hold \(hotkeyName) anywhere to start recording. Speak clearly while holding the key, then release to process and insert your text. FloRight works in any application."
        }
    }
}

struct HelpSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// Preview
struct MainWindow_Previews: PreviewProvider {
    static var previews: some View {
        MainWindow()
            .environmentObject(AppSettings.shared)
    }
}
