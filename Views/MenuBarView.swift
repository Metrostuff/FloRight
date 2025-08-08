//
//  MenuBarView.swift
//  FloRight
//
//  Additional menu bar UI components
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var settings: AppSettings
    @ObservedObject var recordingState: RecordingState
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.bubble.fill")
                .foregroundColor(recordingState.isRecording ? .red : .primary)
            
            if recordingState.isRecording {
                Text("Recording...")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Text("FloRight")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Status Item View (Alternative Implementation)
/*
 For a more custom menu bar appearance, you could use NSHostingView:
 
 ```swift
 class StatusItemView: NSView {
     private var hostingView: NSHostingView<MenuBarView>?
     
     override init(frame frameRect: NSRect) {
         super.init(frame: frameRect)
         setup()
     }
     
     private func setup() {
         let menuBarView = MenuBarView()
             .environmentObject(AppSettings.shared)
         
         hostingView = NSHostingView(rootView: menuBarView)
         hostingView?.frame = bounds
         
         if let hostingView = hostingView {
             addSubview(hostingView)
         }
     }
 }
 ```
 
 This allows for more dynamic menu bar content.
 */

// Preview
struct MenuBarView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarView(recordingState: RecordingState())
            .environmentObject(AppSettings.shared)
            .frame(width: 120, height: 30)
    }
}
