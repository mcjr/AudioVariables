//
//  FileSelectorView.swift
//  AudioVariables
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct FileSelectorView: View {
    @Binding var filename: String
    let onFileChanged: () -> Void
    
    var body: some View {
        HStack {
            Button("Select File") {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.allowedContentTypes = [.audio] // Only audio files
                
                if panel.runModal() == .OK {
                    filename = panel.url?.path ?? FileManager.default.homeDirectoryForCurrentUser.path
                    onFileChanged()
                }
            }
            
            TextField("Enter file path", text: $filename)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: filename) { _ in
                    onFileChanged()
                }
        }
        .frame(maxWidth: .infinity)
    }
}
