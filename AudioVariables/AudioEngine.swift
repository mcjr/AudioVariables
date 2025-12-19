//
//  AudioEngine.swift
//  AudioVariables
//

import AVFoundation

class AudioEngine: ObservableObject {
    let engine = AVAudioEngine()
    let audioPlayer = AVAudioPlayerNode()
    let speedControl = AVAudioUnitVarispeed()
    let pitchControl = AVAudioUnitTimePitch()

    // Play state
    @Published var isPlaying = false
    @Published var currentPlayTime: Double = 0.0

    // play time tracking updates
    private var playTimeTrackingTimer: Timer?

    // Loop settings
    private var loopingEnabled = false
    private var pauseBetweenLoops: Double = 0.0
    
    // Count-in pause settings
    private var countInPhase: Double = 0.0
    private var countInTimer: Timer?
    
    // Audio segment settings
    private var currentFileURL: URL?
    private var currentFileSampleRate: Double = 44100.0
    private var startTime: Double = 0.0
    private var endTime: Double = 60.0
    
    init() {
        // Add nodes
        engine.attach(audioPlayer)
        engine.attach(speedControl)
        engine.attach(pitchControl)
        
        // Create connections
        engine.connect(audioPlayer, to: speedControl, format: nil)
        engine.connect(speedControl, to: pitchControl, format: nil)
        engine.connect(pitchControl, to: engine.mainMixerNode, format: nil)
    }
    
    func playSegment(_ url: URL,
                               startTime: Double = 0,
                               endTime: Double? = nil,
                               shouldLoop: Bool = false,
                               pauseBetweenLoops: Double = 0.0,
                               countInPhase: Double = 0.0,
                               resumeFromPosition: Double = 0.0) {
        // Store current settings
        self.currentFileURL = url
        self.startTime = startTime
        self.endTime = endTime ?? 60.0
        self.loopingEnabled = shouldLoop
        self.pauseBetweenLoops = pauseBetweenLoops
        self.countInPhase = countInPhase
        
        // Determine actual start time (considering resume position)
        let actualStartTime = max(startTime, resumeFromPosition)
        
        let startPlayback = {
            do {
                try self.loadAudioFile(url: url, startTime: actualStartTime, endTime: endTime)
                self.play()
            } catch {
                print("Preparing engine failed: \(error)")
            }
        }
        
        // If count-in pause is set and we're not resuming, start countdown
        if countInPhase > 0 && resumeFromPosition == 0.0 {
            startCountIn(completion: startPlayback)
        } else {
            startPlayback()
        }
    }
    
    private func loadAudioFile(url: URL, startTime: Double = 0, endTime: Double? = nil) throws {
        // Stop previous playback and clean up
        stop()
        
        // Remove old tap connection if present
        engine.mainMixerNode.removeTap(onBus: 0)
        
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
            currentFileSampleRate = sampleRate // Store for position calculations
            let startFrame = AVAudioFramePosition(startTime * sampleRate)
            let totalFrames = file.length
            
            var frameCount: AVAudioFrameCount
            if let endTime = endTime {
                let endFrame = AVAudioFramePosition(endTime * sampleRate)
                frameCount = AVAudioFrameCount(min(endFrame - startFrame, totalFrames - startFrame))
            } else {
                frameCount = AVAudioFrameCount(totalFrames - startFrame)
            }
            
            // Schedule the segment with completion handler
            audioPlayer.scheduleSegment(file, startingFrame: startFrame, frameCount: frameCount, at: nil) {
                // This completion handler is called when the audio segment finishes playing
                DispatchQueue.main.async {
                    if self.loopingEnabled && self.isPlaying {
                        self.handleLoopRestart()
                    } else {
                        self.stop()
                    }
                }
            }
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
        isPlaying = true
        if !engine.isRunning {
            try? engine.start()
        }        
        audioPlayer.play()
        startPlayTimeTracking()
    }
    
    func pause() {
        isPlaying = false
        audioPlayer.pause()
        if engine.isRunning {
            engine.pause()
        }
    }
    
    func stop() {
        isPlaying = false // Set this first to prevent loop restart
        
        // Stop count-in timer if running
        countInTimer?.invalidate()
        countInTimer = nil
        
        audioPlayer.stop()
        if engine.isRunning {
            engine.stop()
        }
        // Remove tap on stop
        engine.mainMixerNode.removeTap(onBus: 0)
        
        currentPlayTime = 0.0
        stopPlayTimeTracking()
    }
    
    func setLoopingEnabled(enabled: Bool, pauseBetween: Double = 0.0) {
        loopingEnabled = enabled
        pauseBetweenLoops = pauseBetween
    }
    
    func setSegmentRange(start: Double, end: Double) {
        startTime = start
        endTime = end
    }
    
    func seekToPosition(_ relativePosition: Double) {
        // Update current position immediately for UI responsiveness
        currentPlayTime = relativePosition
        
        // Notify UI about position change
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("UpdatePlaybackPosition"),
                object: relativePosition
            )
        }
        
        // If playing, restart from new position for precise seeking
        if isPlaying, let url = currentFileURL {
            let absoluteStartTime = startTime + relativePosition
            playSegment(url, startTime: startTime, endTime: endTime, shouldLoop: loopingEnabled, pauseBetweenLoops: pauseBetweenLoops, countInPhase: countInPhase, resumeFromPosition: absoluteStartTime)
        }
    }
    
    // MARK: - Count-in Management
    
    private func startCountIn(completion: @escaping () -> Void) {
        isPlaying = true  // Set playing state during countdown
        var remainingSeconds = Int(countInPhase)
        
        // Play first beep immediately
        playBeep()
        
        // Schedule timer for countdown
        countInTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            remainingSeconds -= 1
            
            if remainingSeconds > 0 {
                // Play beep for each remaining second
                self.playBeep()
            } else {
                // Countdown finished, stop timer and start playback
                timer.invalidate()
                self.countInTimer = nil
                completion()
            }
        }
    }
    
    private func playBeep() {
        // Generate a short beep sound using AVAudioPlayerNode
        let sampleRate = 44100.0
        let duration = 0.1  // 100ms beep
        let frequency = 880.0  // A5 note
        
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!, frameCapacity: frameCount) else { return }
        
        buffer.frameLength = frameCount
        
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        // Generate sine wave
        for frame in 0..<Int(frameCount) {
            let value = sin(2.0 * .pi * frequency * Double(frame) / sampleRate)
            // Apply envelope to avoid clicks
            let envelope = sin(.pi * Double(frame) / Double(frameCount))
            channelData[frame] = Float(value * envelope * 0.3) // 0.3 = volume
        }
        
        // Create a temporary player for the beep
        let beepPlayer = AVAudioPlayerNode()
        engine.attach(beepPlayer)
        engine.connect(beepPlayer, to: engine.mainMixerNode, format: buffer.format)
        
        beepPlayer.scheduleBuffer(buffer) {
            // Clean up after beep finishes
            DispatchQueue.main.async {
                beepPlayer.stop()
                self.engine.detach(beepPlayer)
            }
        }
        
        if !engine.isRunning {
            try? engine.start()
        }
        beepPlayer.play()
    }
    
    // MARK: - Loop Management

    private func handleLoopRestart() {
        guard loopingEnabled, let url = currentFileURL else { return }
        
        if pauseBetweenLoops > 0 {
            // Add pause between loops using DispatchQueue delay
            DispatchQueue.main.asyncAfter(deadline: .now() + pauseBetweenLoops) {
                self.restartLoop(url: url)
            }
        } else {
            // Immediate loop restart
            restartLoop(url: url)
        }
    }
    
    private func restartLoop(url: URL) {
        guard loopingEnabled else { return }
        
        // Schedule and play new segment (no count-in for loop restarts)
        do {
            try loadAudioFile(url: url, startTime: startTime, endTime: endTime)
            play()
            
            let segmentDuration = endTime - startTime
            print("Loop restarted - Segment: \(String(format: "%.1f", segmentDuration))s, Pause: \(String(format: "%.1f", pauseBetweenLoops))s")
        } catch {
            print("Loop restart failed: \(error)")
        }
    }
    
    // MARK: - PlayTime Tracking
    private func startPlayTimeTracking() {
        stopPlayTimeTracking()
        
        // Lightweight timer for play time tracking - actual position comes from playerTime
        playTimeTrackingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            if self.isPlaying {
                // Get precise position from audio hardware
                let precisePosition = self.getCurrentPosition()
                self.currentPlayTime = precisePosition
                
                // Check if we have reached the end of the segment
                if precisePosition >= (self.endTime - self.startTime) {
                    if self.loopingEnabled {
                        // Event-based loop will be handled by completion handler
                        return
                    } else {
                        self.stop()
                    }
                }
            } else {
                // Player is paused, stop tracking but keep time
                self.stopPlayTimeTracking()
            }
        }
    }
    
    private func stopPlayTimeTracking() {
        playTimeTrackingTimer?.invalidate()
        playTimeTrackingTimer = nil
    }
    
    private func getCurrentPosition() -> Double {
        // Get precise hardware position from audio player
        guard let nodeTime = audioPlayer.lastRenderTime,
              let playerTime = audioPlayer.playerTime(forNodeTime: nodeTime) else {
            return currentPlayTime // Fallback to last known position
        }
        // Convert sample time to seconds
        return Double(playerTime.sampleTime) / currentFileSampleRate
    }
    
    func setSpeed(_ speed: Float) {
        speedControl.rate = speed
    }
    
    func setPitch(_ pitch: Float) {
        pitchControl.pitch = pitch
        pitchControl.rate = 1.0
    }
    
    deinit {
        stop()
    }
}
