//
//  Settings.swift
//  AudioVariables
//

import Foundation

struct Settings: Codable {
    var filename: String = "<audiofile>"
    var countInPhase: Double = 0.0
    var startTime: Double = 0.0
    var endTime: Double = 60.0
    var isLooping: Bool = false
    var pauseBetweenLoops: Double = 0.0
    var speed: Float = 1.0
    var pitch: Float = 1.0
}
