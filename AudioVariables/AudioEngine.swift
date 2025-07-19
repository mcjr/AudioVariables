//
//  AudioEngine.swift
//  AudioVariables
//

import AVFoundation
import Accelerate

class AudioEngine: ObservableObject {
    let engine = AVAudioEngine()
    let audioPlayer = AVAudioPlayerNode()
    let speedControl = AVAudioUnitVarispeed()
    let pitchControl = AVAudioUnitTimePitch()
    
    // Audio analysis variables
    private var fftSetup: FFTSetup?
    private var frequencyBuffer: [Float] = Array(repeating: 0.0, count: 1024)
    private var magnitudes: [Float] = Array(repeating: 0.0, count: 512)
    
    init() {
        setupEngine()
    }
    
    private func setupEngine() {
        // Add nodes
        engine.attach(audioPlayer)
        engine.attach(speedControl)
        engine.attach(pitchControl)
        
        // Create connections
        engine.connect(audioPlayer, to: speedControl, format: nil)
        engine.connect(speedControl, to: pitchControl, format: nil)
        engine.connect(pitchControl, to: engine.mainMixerNode, format: nil)
        
        // FFT setup for spectrum analysis
        if fftSetup == nil {
            fftSetup = vDSP_create_fftsetup(10, FFTRadix(kFFTRadix2)) // 2^10 = 1024 samples
        }
    }
    
    func prepareEngine(_ url: URL, startTime: Double = 0, endTime: Double? = nil) -> AVAudioFile? {
        do {
            try loadAudioFile(url: url, startTime: startTime, endTime: endTime)
            return try AVAudioFile(forReading: url)
        } catch {
            print("Preparing engine failed: \(error)")
            return nil
        }
    }
    
    func loadAudioFile(url: URL, startTime: Double = 0, endTime: Double? = nil) throws {
        // Stop previous playback and clean up
        stop()
        
        // Remove old tap connection if present
        engine.mainMixerNode.removeTap(onBus: 0)
        
        // Stop engine if running
        
                // Stop engine if running
        if engine.isRunning {
            engine.stop()
        }
        
        // Remove all nodes
        engine.detach(audioPlayer)
        engine.detach(speedControl)
        engine.detach(pitchControl)
        
        // Add nodes again
        engine.attach(audioPlayer)
        engine.attach(pitchControl)
        engine.attach(speedControl)
        
        // Recreate connections
        engine.connect(audioPlayer, to: speedControl, format: nil)
        engine.connect(speedControl, to: pitchControl, format: nil)
        engine.connect(pitchControl, to: engine.mainMixerNode, format: nil)
        
        do {
            let file = try AVAudioFile(forReading: url)
            
            // Add audio tap for spectrum analysis
            let format = engine.mainMixerNode.outputFormat(forBus: 0)
            engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: format) { (buffer, time) in
                self.processAudioBuffer(buffer)
            }
            
            // Calculate frame positions
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
            
            // Schedule the segment
            audioPlayer.scheduleSegment(file, startingFrame: startFrame, frameCount: frameCount, at: nil)
            
            // Start engine
            try engine.start()
        } catch {
            print("Playing \(url) failed! Error: \(error)")
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameCount = Int(buffer.frameLength)
        
        // Simplified spectrum analysis
        let sampleCount = min(frameCount, 1024)
        
        // Calculate RMS for different frequency bands
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
            let normalizedValue = max(0, rms * 100) // Ensure values are not negative
            newFrequencyData.append(normalizedValue)
        }
        
        // Update on main thread for macOS
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("UpdateSpectrum"),
                object: newFrequencyData
            )
        }
    }
    
    func play() {
        audioPlayer.play()
    }
    
    func pause() {
        audioPlayer.pause()
    }
    
    func stop() {
        audioPlayer.stop()
        if engine.isRunning {
            engine.stop()
        }
        // Remove tap on stop
        engine.mainMixerNode.removeTap(onBus: 0)
    }
    
    var isPlaying: Bool {
        return audioPlayer.isPlaying
    }
    
    func setSpeed(_ speed: Float) {
        speedControl.rate = speed
    }
    
    func setPitch(_ pitch: Float) {
        pitchControl.rate = pitch
    }
}
