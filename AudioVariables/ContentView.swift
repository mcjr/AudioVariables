//
//  ContentView.swift
//  AudioVariables
//

import SwiftUI
import AVKit
import AVFoundation
import Accelerate

let engine = AVAudioEngine()
let audioPlayer = AVAudioPlayerNode()
let speedControl = AVAudioUnitVarispeed()
let pitchControl = AVAudioUnitTimePitch()

// Audio-Analyse Variablen
var fftSetup: FFTSetup?
var frequencyBuffer: [Float] = Array(repeating: 0.0, count: 1024)
var magnitudes: [Float] = Array(repeating: 0.0, count: 512)

func prepareEngine(_ url: URL, startTime: Double = 0, endTime: Double? = nil) -> AVAudioFile? {
    // Stop previous playback und räume auf
    audioPlayer.stop()
    
    // Entferne alte Tap-Verbindung falls vorhanden
    engine.mainMixerNode.removeTap(onBus: 0)
    
    // Stoppe Engine falls läuft
    if engine.isRunning {
        engine.stop()
    }
    
    // Entferne alle Nodes
    engine.detach(audioPlayer)
    engine.detach(pitchControl)
    engine.detach(speedControl)
    
    // Füge Nodes wieder hinzu
    engine.attach(audioPlayer)
    engine.attach(pitchControl)
    engine.attach(speedControl)
    
    // Verbindungen neu erstellen
    engine.connect(audioPlayer, to: speedControl, format: nil)
    engine.connect(speedControl, to: pitchControl, format: nil)
    engine.connect(pitchControl, to: engine.mainMixerNode, format: nil)
    
    // FFT Setup für Spektrum-Analyse
    if fftSetup == nil {
        fftSetup = vDSP_create_fftsetup(10, FFTRadix(kFFTRadix2)) // 2^10 = 1024 samples
    }
    
    do {
        let file = try AVAudioFile(forReading: url)
        
        // Audio-Tap für Spektrum-Analyse hinzufügen
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: format) { (buffer, time) in
            processAudioBuffer(buffer)
        }
        
        // Berechne Frame-Positionen
        let sampleRate = file.fileFormat.sampleRate
        let startFrame = AVAudioFramePosition(startTime * sampleRate)
        let totalFrames = file.length
        
        var frameCount: AVAudioFrameCount
        if let endTime = endTime {
            let endFrame = AVAudioFramePosition(endTime * sampleRate)
            frameCount = AVAudioFrameCount(min(endFrame - startFrame, totalFrames - startFrame))
        } else {
            frameCount = AVAudioFrameCount(totalFrames - startFrame)
        }
        
        // Plane das Segment
        audioPlayer.scheduleSegment(file, startingFrame: startFrame, frameCount: frameCount, at: nil)
        
        // Starte Engine
        try engine.start()
        return file
    } catch {
        print("Playing \(url) failed! Error: \(error)")
        return nil
    }
}

func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
    guard let channelData = buffer.floatChannelData?[0] else { return }
    
    let frameCount = Int(buffer.frameLength)
    
    // Vereinfachte Spektrum-Analyse
    let sampleCount = min(frameCount, 1024)
    
    // Berechne RMS für verschiedene Frequenzbänder
    let bandsCount = 64
    let samplesPerBand = max(1, sampleCount / bandsCount)
    
    var newFrequencyData: [Float] = []
    
    for band in 0..<bandsCount {
        let startIndex = band * samplesPerBand
        let endIndex = min(startIndex + samplesPerBand, sampleCount)
        
        var sum: Float = 0.0
        for i in startIndex..<endIndex {
            let sample = channelData[i]
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(endIndex - startIndex))
        let normalizedValue = max(0, rms * 100) // Stelle sicher, dass Werte nicht negativ sind
        newFrequencyData.append(normalizedValue)
    }
    
    // Update auf Main-Thread für macOS
    DispatchQueue.main.async {
        // Die Daten werden über eine globale Variable oder Notification aktualisiert
        // Da wir in einer globalen Funktion sind, verwenden wir NotificationCenter
        NotificationCenter.default.post(
            name: NSNotification.Name("UpdateSpectrum"),
            object: newFrequencyData
        )
    }
}

// Separate Komponenten für bessere Compiler-Performance
struct RangeSliderMarker: View {
    let text: String
    let color: Color
    let position: CGFloat
    let onDrag: (DragGesture.Value) -> Void
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 22, height: 22)
                .shadow(radius: 2)
            Circle()
                .fill(color)
                .frame(width: 18, height: 18)
            Text(text)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .offset(x: position)
        .gesture(
            DragGesture()
                .onChanged(onDrag)
        )
    }
}

struct PlaybackPositionMarker: View {
    let position: CGFloat
    let onDrag: (DragGesture.Value) -> Void
    
    var body: some View {
        Rectangle()
            .fill(Color.yellow)
            .frame(width: 3, height: 22)
            .offset(x: position - 1.5)
            .gesture(
                DragGesture()
                    .onChanged(onDrag)
            )
    }
}

struct RangeSliderLabels: View {
    let startTime: Double
    let endTime: Double
    let currentPlayTime: Double
    let fileDurationInSeconds: Double
    let isPlaying: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("0s")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("Start")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack {
                Text("Selection: \(String(format: "%.1f", endTime - startTime))s")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                HStack {
                    Text("Start: \(String(format: "%.1f", startTime))s")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("End: \(String(format: "%.1f", endTime))s")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
                if isPlaying || currentPlayTime > 0 {
                    Text("Playing: \(String(format: "%.1f", startTime + currentPlayTime))s")
                        .font(.caption2)
                        .foregroundColor(isPlaying ? .yellow : .orange)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(String(format: "%.0f", fileDurationInSeconds))s")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("End")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct AudioRangeSlider: View {
    @Binding var startTime: Double
    @Binding var endTime: Double
    let currentPlayTime: Double
    let fileDurationInSeconds: Double
    let isPlaying: Bool
    
    var body: some View {
        VStack {
            Text("Audio Selection Range")
                .font(.headline)
            
            ZStack(alignment: .center) {
                // Hintergrund-Track
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 22)
                    .cornerRadius(11)
                
                // GeometryReader für interaktive Elemente
                GeometryReader { geometry in
                    let totalWidth = geometry.size.width
                    let startPercent = startTime / max(fileDurationInSeconds, 1.0)
                    let endPercent = endTime / max(fileDurationInSeconds, 1.0)
                    let startX = totalWidth * startPercent
                    let endX = totalWidth * endPercent
                    let rangeWidth = endX - startX
                    
                    ZStack(alignment: .leading) {
                        // Blauer Auswahlbereich - korrekt positioniert
                        Rectangle()
                            .fill(Color.blue.opacity(0.6))
                            .frame(width: max(0, rangeWidth), height: 22)
                            .cornerRadius(11)
                            .offset(x: startX)
                            .gesture(
                                DragGesture()
                                    .onChanged { gesture in
                                        let dragDistance = gesture.translation.width
                                        let timeDistance = (dragDistance / totalWidth) * fileDurationInSeconds
                                        let currentDuration = endTime - startTime
                                        
                                        let newStartTime = max(0, min(fileDurationInSeconds - currentDuration, startTime + timeDistance))
                                        let newEndTime = newStartTime + currentDuration
                                        
                                        if newEndTime <= fileDurationInSeconds {
                                            startTime = newStartTime
                                            endTime = newEndTime
                                        }
                                    }
                            )
                        
                        // Start-Marker - positioniert am Anfang des blauen Balkens
                        RangeSliderMarker(
                            text: "S",
                            color: .green,
                            position: startX - 11
                        ) { value in
                            updateStartTime(value: value, totalWidth: totalWidth)
                        }
                        
                        // End-Marker - positioniert am Ende des blauen Balkens
                        RangeSliderMarker(
                            text: "E",
                            color: .red,
                            position: startX + rangeWidth - 11
                        ) { value in
                            updateEndTime(value: value, totalWidth: totalWidth)
                        }
                        
                        // Playback Position Marker
                        if isPlaying || currentPlayTime > 0 {
                            let currentPercent = (startTime + currentPlayTime) / max(fileDurationInSeconds, 1.0)
                            let currentX = totalWidth * currentPercent
                            PlaybackPositionMarker(position: currentX) { value in
                                updatePlaybackPosition(value: value, totalWidth: totalWidth)
                            }
                        }
                    }
                }
                .frame(height: 22)
            }
            .frame(height: 22)
            
            // Zeit-Labels
            RangeSliderLabels(
                startTime: startTime,
                endTime: endTime,
                currentPlayTime: currentPlayTime,
                fileDurationInSeconds: fileDurationInSeconds,
                isPlaying: isPlaying
            )
            .padding(.top, 5)
        }
    }
    
    private func updateStartTime(value: DragGesture.Value, totalWidth: CGFloat) {
        let newStartPercent = max(0, min(1, (value.location.x) / totalWidth))
        let newStartTime = newStartPercent * fileDurationInSeconds
        startTime = max(0, min(endTime - 0.1, newStartTime))
    }
    
    private func updateEndTime(value: DragGesture.Value, totalWidth: CGFloat) {
        let newEndPercent = max(0, min(1, (value.location.x) / totalWidth))
        let newEndTime = newEndPercent * fileDurationInSeconds
        endTime = max(startTime + 0.1, min(fileDurationInSeconds, newEndTime))
    }
    
    private func updatePlaybackPosition(value: DragGesture.Value, totalWidth: CGFloat) {
        let newPercent = max(0, min(1, (value.location.x) / totalWidth))
        let newAbsoluteTime = newPercent * fileDurationInSeconds
        
        // Stelle sicher, dass die neue Position innerhalb des ausgewählten Bereichs liegt
        if newAbsoluteTime >= startTime && newAbsoluteTime <= endTime {
            // Berechne die neue relative Position innerhalb des Segments
            let newRelativeTime = newAbsoluteTime - startTime
            
            // Aktualisiere die aktuelle Abspielzeit über eine Binding-ähnliche Funktion
            // Da wir hier nur eine lokale Funktion haben, müssen wir das über NotificationCenter machen
            NotificationCenter.default.post(
                name: NSNotification.Name("UpdatePlaybackPosition"),
                object: newRelativeTime
            )
        }
    }
}

struct ContentView: View {
    @State private var filename         = "/Users/michael/Music/iTunes/iTunes Music/Music/B.B. King/Live At The BBC/14 The Thrill Is Gone (Live At The BBC _ 1989).m4a" // "<audiofile>"
    @State private var showFileChooser  = false
    @State private var pitchEditing     = false
    @State private var pitchValue:Float = 1.0
    @State private var speedEditing     = false
    @State private var speedValue:Float = 1.0
    @State private var startTime:Double = 0.0
    @State private var endTime:Double = 60.0
    @State private var audioFile: AVAudioFile?
    @State private var isLooping = false
    @State private var loopTimer: Timer?
    @State private var pauseBetweenLoops:Double = 0.0
    @State private var fileDurationInSeconds:Double = 300.0
    @State private var frequencyData: [Float] = Array(repeating: 0.0, count: 64)
    @State private var displayTimer: Timer?
    @State private var currentPlayTime: Double = 0.0
    @State private var playbackTimer: Timer?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
            HStack {
                Button("Select File") {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    if panel.runModal() == .OK {
                        filename = panel.url?.path ?? FileManager.default.homeDirectoryForCurrentUser.path
                        loadFileDuration()
                    }
                }
                TextField("Enter file path", text: $filename)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: filename) { newValue in
                        loadFileDuration()
                    }
            }.frame(maxWidth: .infinity)
            
            HStack {
                Button("Play") {
                    if audioPlayer.isPlaying {
                        return // Bereits am Spielen
                    }
                    
                    let fileURL = URL(fileURLWithPath: filename)
                    
                    // Wenn wir pausiert haben, spiele von der aktuellen Position weiter
                    if currentPlayTime > 0 {
                        let resumeStartTime = startTime + currentPlayTime
                        audioFile = prepareEngine(fileURL, startTime: resumeStartTime, endTime: endTime)
                    } else {
                        // Neues Segment von Anfang starten
                        audioFile = prepareEngine(fileURL, startTime: startTime, endTime: endTime)
                    }
                    
                    if let _ = audioFile {
                        audioPlayer.play()
                        startPlaybackTracking()
                        
                        if isLooping {
                            startLooping()
                        }
                    }
                }
                Button("Pause") {
                    audioPlayer.pause()
                    // Stoppe nur den Loop-Timer, aber behalte die aktuelle Position
                    stopLooping()
                }
                Button("Stop") {
                    audioPlayer.stop()
                    if engine.isRunning {
                        engine.stop()
                    }
                    // Entferne Tap beim Stop
                    engine.mainMixerNode.removeTap(onBus: 0)
                    stopPlaybackTracking()
                    stopLooping()
                }
                
                Button(isLooping ? "Loop: ON" : "Loop: OFF") {
                    isLooping.toggle()
                    if !isLooping {
                        stopLooping()
                    } else if audioPlayer.isPlaying {
                        startLooping()
                    }
                }
                .foregroundColor(isLooping ? .green : .gray)
                
                // Loop-Pause Slider direkt nach dem Loop-Button
                VStack {
                    Text("Loop-Pause")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    HStack {
                        Text("0s")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Slider(
                            value: $pauseBetweenLoops,
                            in: 0...10,
                            step: 1.0
                        )
                        .frame(width: 80)
                        Text("10s")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    Text("\(String(format: "%.0f", pauseBetweenLoops))s")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                .frame(width: 120)
                //.fontWeight(isLooping ? .bold : .regular)
            }
            
            // Spektrum-Anzeige
            VStack {
                Text("Audio Spectrum")
                    .font(.headline)
                
                ZStack(alignment: .bottom) {
                    // Transparenter Container für die Größe
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 100)
                    
                    // Spektrum-Balken mit eigenem, minimal größerem Hintergrund
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(0..<frequencyData.count, id: \.self) { index in
                            Rectangle()
                                .fill(Color.blue.opacity(0.7))
                                .frame(
                                    width: 4, 
                                    height: max(1, min(96, CGFloat(frequencyData[index]) * 2))
                                )
                                .animation(.easeInOut(duration: 0.1), value: frequencyData[index])
                        }
                    }
                    .frame(height: 100, alignment: .bottom)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                    
                    // Graue Basislinie nur über den Balken
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(0..<frequencyData.count, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 4, height: 1)
                        }
                    }
                    .background(
                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(height: 1)
                    )
                    .frame(height: 100, alignment: .bottom)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                }
            }
            
            // Range-Slider für Start und End Time
            AudioRangeSlider(
                startTime: $startTime,
                endTime: $endTime,
                currentPlayTime: currentPlayTime,
                fileDurationInSeconds: fileDurationInSeconds,
                isPlaying: audioPlayer.isPlaying
            )
            
            VStack {
                Slider(
                    value: $speedValue,
                    in: 0.1...2.0
                ) {
                    Text("Speed")
                } minimumValueLabel: {
                    Text("10%")
                } maximumValueLabel: {
                    Text("200%")
                } onEditingChanged: { editing in
                    speedEditing = editing
                    speedControl.rate = speedValue
                }
                Text("\(String(format: "%.0f", speedValue * 100))%")
                    .foregroundColor(speedEditing ? .red : .blue)
            }
            
            VStack {
                Slider(
                    value: $pitchValue,
                    in: 0.1...2.0
                ) {
                    Text("Pitch")
                } minimumValueLabel: {
                    Text("10%")
                } maximumValueLabel: {
                    Text("200%")
                } onEditingChanged: { editing in
                    pitchEditing = editing
                    pitchControl.rate = pitchValue
                }
                Text("\(String(format: "%.0f", pitchValue * 100))%")
                    .foregroundColor(pitchEditing ? .red : .blue)
            }
        }.padding(20)
        }
        .onAppear {
            loadFileDuration()
            startDisplayTimer()
            
            // NotificationCenter Observer für Spektrum-Updates
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("UpdateSpectrum"),
                object: nil,
                queue: .main
            ) { notification in
                if let newData = notification.object as? [Float] {
                    frequencyData = newData
                }
            }
            
            // NotificationCenter Observer für Playback-Position Updates
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("UpdatePlaybackPosition"),
                object: nil,
                queue: .main
            ) { notification in
                if let newRelativeTime = notification.object as? Double {
                    currentPlayTime = newRelativeTime
                    
                    // Wenn Audio spielt, springe zur neuen Position
                    if audioPlayer.isPlaying {
                        let fileURL = URL(fileURLWithPath: filename)
                        let newStartTime = startTime + newRelativeTime
                        audioFile = prepareEngine(fileURL, startTime: newStartTime, endTime: endTime)
                        audioPlayer.play()
                        startPlaybackTracking()
                    }
                }
            }
        }
        .onDisappear {
            stopDisplayTimer()
            stopPlaybackTracking()
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("UpdateSpectrum"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("UpdatePlaybackPosition"), object: nil)
        }
    }
    
    func startLooping() {
        stopLooping() // Stoppe vorherigen Timer
        
        let segmentDuration = endTime - startTime
        let totalLoopDuration = segmentDuration + pauseBetweenLoops
        
        loopTimer = Timer.scheduledTimer(withTimeInterval: totalLoopDuration, repeats: true) { _ in
            if isLooping { // Prüfe ob Loop noch aktiv ist
                // Reset current time for new loop
                currentPlayTime = 0.0
                // Neues Segment planen und abspielen
                let fileURL = URL(fileURLWithPath: filename)
                audioFile = prepareEngine(fileURL, startTime: startTime, endTime: endTime)
                audioPlayer.play()
                startPlaybackTracking() // Restart position tracking
                
                print("Loop restarted - Segment: \(String(format: "%.1f", segmentDuration))s, Pause: \(String(format: "%.1f", pauseBetweenLoops))s")
            } else {
                stopLooping()
            }
        }
    }
    
    func stopLooping() {
        loopTimer?.invalidate()
        loopTimer = nil
    }
    
    func startPlaybackTracking() {
        // Stoppe nur den Timer, aber behalte currentPlayTime bei Resume
        playbackTimer?.invalidate()
        playbackTimer = nil
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if audioPlayer.isPlaying {
                // Berücksichtige Speed-Änderungen
                let increment = 0.05 * Double(speedControl.rate)
                currentPlayTime += increment
                
                // Prüfe ob wir das Ende des Segments erreicht haben
                if currentPlayTime >= (endTime - startTime) {
                    if isLooping {
                        currentPlayTime = 0.0 // Reset für Loop
                        // Starte neuen Loop
                        let fileURL = URL(fileURLWithPath: filename)
                        audioFile = prepareEngine(fileURL, startTime: startTime, endTime: endTime)
                        audioPlayer.play()
                    } else {
                        stopPlaybackTracking()
                    }
                }
            } else {
                // Player ist pausiert, aber behalte die Zeit
                playbackTimer?.invalidate()
                playbackTimer = nil
            }
        }
    }
    
    func stopPlaybackTracking() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        currentPlayTime = 0.0
    }
    
    func loadFileDuration() {
        let fileURL = URL(fileURLWithPath: filename)
        do {
            let file = try AVAudioFile(forReading: fileURL)
            let sampleRate = file.fileFormat.sampleRate
            let totalFrames = file.length
            fileDurationInSeconds = Double(totalFrames) / sampleRate
            
            // Passe endTime an, falls es größer als die Dateilänge ist
            if endTime > fileDurationInSeconds {
                endTime = fileDurationInSeconds
            }
            
            print("File duration: \(String(format: "%.1f", fileDurationInSeconds))s")
        } catch {
            print("Could not load file duration: \(error)")
            fileDurationInSeconds = 300.0 // Fallback
        }
    }
    
    func startDisplayTimer() {
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            // Simuliere Spektrum-Daten wenn Audio spielt
            if audioPlayer.isPlaying {
                updateFrequencyData()
            } else {
                // Dämpfe die Anzeige wenn nichts spielt
                for i in 0..<frequencyData.count {
                    frequencyData[i] *= 0.95
                }
            }
        }
    }
    
    func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }
    
    func updateFrequencyData() {
        // Simulierte Spektrum-Daten nur wenn keine echten Daten kommen
        // Die echten Daten kommen jetzt über NotificationCenter
        for i in 0..<frequencyData.count {
            let randomValue = Float.random(in: 0...20) // Reduziert für weniger Rauschen
            frequencyData[i] = max(0, frequencyData[i] * 0.9 + randomValue * 0.1) // Mehr Smoothing, mindestens 0
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
