//
//  ContentView.swift
//  AudioVariables
//

import SwiftUI
import AVKit
import AVFoundation

let engine = AVAudioEngine()
let speedControl = AVAudioUnitVarispeed()
let pitchControl = AVAudioUnitTimePitch()

func play(_ url: URL) throws {
    // 1: load the file
    let file = try AVAudioFile(forReading: url)
    
    // 2: create the audio player
    let audioPlayer = AVAudioPlayerNode()
    
    // 3: connect the components to our playback engine
    engine.attach(audioPlayer)
    engine.attach(pitchControl)
    engine.attach(speedControl)
    
    // 4: arrange the parts so that output from one is input to another
    engine.connect(audioPlayer, to: speedControl, format: nil)
    engine.connect(speedControl, to: pitchControl, format: nil)
    engine.connect(pitchControl, to: engine.mainMixerNode, format: nil)
    
    // 5: prepare the player to play its file from the beginning
    audioPlayer.scheduleFile(file, at: nil)
    
    // 6: start the engine and player
    try engine.start()
    audioPlayer.play()
}

struct ContentView: View {
    @State private var filename         = "<audiofile>"
    @State private var showFileChooser  = false
    @State private var pitchEditing     = false
    @State private var pitchValue:Float = 1.0
    @State private var speedEditing     = false
    @State private var speedValue:Float = 1.0
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button("Select File") {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    if panel.runModal() == .OK {
                        self.filename = panel.url?.path ??                       FileManager.default.homeDirectoryForCurrentUser.path
                    }
                }
                Text(filename)
            }.frame(maxWidth: .infinity)
            
            HStack {
                Button("Play") {
                    do {
                        let fileURL = URL(fileURLWithPath: filename)
                        try play(fileURL)
                    } catch {
                        print("error")
                    }
                }
                Button("Stop") {
                    engine.stop()
                }
            }
            
            VStack {
                Slider(
                    value: $speedValue,
                    in: 0.1...2.0,
                    step: 0.1
                ) {
                    Text("Speed")
                } minimumValueLabel: {
                    Text("0.1")
                } maximumValueLabel: {
                    Text("2")
                } onEditingChanged: { editing in
                    speedEditing = editing
                    speedControl.rate = speedValue
                }
                Text("\(speedControl.rate)")
                    .foregroundColor(speedEditing ? .red : .blue)
            }
            
            VStack {
                Slider(
                    value: $pitchValue,
                    in: 0.1...2.0,
                    step: 0.1
                ) {
                    Text("Pitch")
                } minimumValueLabel: {
                    Text("0.1")
                } maximumValueLabel: {
                    Text("2")
                } onEditingChanged: { editing in
                    pitchEditing = editing
                    pitchControl.rate = pitchValue
                }
                Text("\(pitchControl.rate)")
                    .foregroundColor(pitchEditing ? .red : .blue)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
