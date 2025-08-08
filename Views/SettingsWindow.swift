//
//  SettingsWindow.swift
//  FloRight
//
//  The main settings interface for FloRight
//

import SwiftUI

struct SettingsWindow: View {
    @EnvironmentObject var settings: AppSettings
    @State private var selectedTab = "general"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag("general")
            
            ToneSettingsView()
                .tabItem {
                    Label("Tone Presets", systemImage: "text.bubble")
                }
                .tag("tones")
            
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag("about")
        }
        .frame(width: 600, height: 400)
        .background(
            // Invisible buttons for keyboard shortcuts in modal
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

struct GeneralSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
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
                
                Text(settings.useLatchMode ? "(Click to start/stop recording)" : "(Press and hold to record)")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .padding(.top, 2)
                
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
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct ToneSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Default Tone Preset")
                .font(.headline)
                .padding(.top, 8)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(TonePreset.allCases) { tone in
                    TonePresetRow(tone: tone, isSelected: settings.selectedTonePreset == tone)
                        .onTapGesture {
                            settings.selectedTonePreset = tone
                        }
                }
            }
            
            Spacer()
            
            Text("Tip: Use ⌘1-5 to quickly switch between presets")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct TonePresetRow: View {
    let tone: TonePreset
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(tone.rawValue)
                        .font(.system(.body, weight: isSelected ? .semibold : .regular))
                    
                    Text("⌘\(tone.keyboardShortcut)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Text(tone.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

struct AboutView: View {
    @StateObject private var memoryMonitor = MemoryMonitor.shared
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 50))
                .foregroundColor(.accentColor)
            
            Text("FloRight")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Light as a feather. Writes like a pro.")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                InfoRow(label: "Version", value: "\(AppSettings.appVersion) (\(AppSettings.buildNumber))")
                InfoRow(label: "Whisper Model", value: AppSettings.whisperModel)
                InfoRow(label: "Model Size", value: AppSettings.modelSize)
                InfoRow(
                    label: "Memory Usage", 
                    value: memoryMonitor.currentMemoryUsage,
                    valueColor: memoryMonitor.isUnderTarget ? .primary : .orange
                )
            }
            .padding(12)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
            
            Link("Visit Website", destination: URL(string: "https://floright.app")!)
                .buttonStyle(.link)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    let valueColor: Color
    
    init(label: String, value: String, valueColor: Color = .primary) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }
    
    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }
}

// Preview
struct SettingsWindow_Previews: PreviewProvider {
    static var previews: some View {
        SettingsWindow()
            .environmentObject(AppSettings.shared)
    }
}
