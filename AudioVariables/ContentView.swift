//
//  ContentView.swift
//  AudioVariables
//

import SwiftUI
import AVKit
import AVFoundation

let engine = AVAudioEngine()
let audioPlayer = AVAudioPlayerNode()
let speedControl = AVAudioUnitVarispeed()
let pitchControl = AVAudioUnitTimePitch()

func prepareEngine(_ url: URL) {
    engine.attach(audioPlayer)
    engine.attach(pitchControl)
    engine.attach(speedControl)
    
    engine.connect(audioPlayer, to: speedControl, format: nil)
    engine.connect(speedControl, to: pitchControl, format: nil)
    engine.connect(pitchControl, to: engine.mainMixerNode, format: nil)
    
    do {
        let file = try AVAudioFile(forReading: url)
        audioPlayer.scheduleFile(file, at: nil)
        try engine.start()
    } catch {
        print("Playing \(url) failed!")
    }
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
                        self.filename = panel.url?.path ?? FileManager.default.homeDirectoryForCurrentUser.path
                    }
                }
                Text(filename)
            }.frame(maxWidth: .infinity)
            
            HStack {
                Button("Play") {
                    if (!engine.isRunning) {
                        let fileURL = URL(fileURLWithPath: filename)
                        prepareEngine(fileURL)
                    }
                    audioPlayer.play()
                }
                Button("Pause") {
                    audioPlayer.pause()
                }
                Button("Stop") {
                    audioPlayer.stop()
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
        }.padding(20)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
