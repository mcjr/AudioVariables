//
//  AudioSpectrumView.swift
//  AudioVariables
//

import SwiftUI

struct AudioSpectrumView: View {
    let frequencyData: [Float]
    
    var body: some View {
        VStack {
            Text("Audio Spectrum")
                .font(.headline)
            
            ZStack(alignment: .bottom) {
                // Transparent container for the size
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 100)
                
                // Spectrum bars with own, minimal larger background
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
                
                // Gray baseline only above the bars
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
    }
}
