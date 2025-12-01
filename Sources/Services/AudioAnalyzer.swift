import Foundation
import AVFoundation
import Accelerate
import ScreenCaptureKit
import OSLog

@MainActor
class AudioAnalyzer: NSObject, ObservableObject {
    static let shared = AudioAnalyzer()
    
    @Published var levels: [Float] = Array(repeating: 0.1, count: 15)
    @Published var isRunning = false
    @Published var hasPermission = false
    
    private var stream: SCStream?
    private let audioQueue = DispatchQueue(label: "com.rovena.audio", qos: .userInteractive)
    
    override init() {
        super.init()
        checkPermission()
    }
    
    private func checkPermission() {
        // Basic check - real permission triggers when we try to record
        // For macOS 14+, we can just try to start or rely on system prompt
        // Since we aren't sandboxed, we can assume we might need to prompt user via UI
        self.hasPermission = true // We assume true or prompt will happen
    }
    
    func start() {
        guard !isRunning else { return }
        
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                
                // Get the main display
                guard let display = content.displays.first else {
                    print("No display found")
                    return
                }
                
                // Create filter for the display
                // We want to capture audio from everything on this display
                let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
                
                // Configuration: Audio Only (minimal video)
                let config = SCStreamConfiguration()
                config.capturesAudio = true
                config.sampleRate = 44100
                config.channelCount = 2
                config.excludesCurrentProcessAudio = false // Capture our own audio too if we want, or true to avoid feedback loop if we were playing audio
                
                // minimal video config to save resources since we only care about audio
                config.width = 100
                config.height = 100
                config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // 1 fps
                
                let stream = SCStream(filter: filter, configuration: config, delegate: nil)
                
                try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
                
                try await stream.startCapture()
                
                self.stream = stream
                
                await MainActor.run {
                    self.isRunning = true
                }
                
                print("System Audio Capture Started")
                
            } catch {
                print("Failed to start audio capture: \(error)")
                await MainActor.run {
                    self.hasPermission = false // Likely denied if failed immediately
                }
            }
        }
    }
    
    func stop() {
        guard isRunning else { return }
        
        Task {
            try? await stream?.stopCapture()
            stream = nil
            
            await MainActor.run {
                self.isRunning = false
                self.levels = Array(repeating: 0.1, count: 15)
            }
        }
    }
    
    private func processAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        // Extract audio samples
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        
        var lengthAtOffset: Int = 0
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        
        let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset, totalLengthOut: &totalLength, dataPointerOut: &dataPointer)
        
        if status == kCMBlockBufferNoErr, let dataPointer = dataPointer {
            // Assuming Float32 (standard for SCStream audio usually, but can vary)
            // SCStream typically outputs non-interleaved float or interleaved.
            // We can treat it as a raw buffer of samples for simple RMS.
            
            // Let's cast to Float pointer
            let floatCount = totalLength / MemoryLayout<Float>.size
            let floatPointer = dataPointer.withMemoryRebound(to: Float.self, capacity: floatCount) { $0 }
            
            // Calculate RMS
            var rms: Float = 0.0
            vDSP_rmsqv(floatPointer, 1, &rms, vDSP_Length(floatCount))
            
            // Normalize (System audio might be quieter or louder, adjust gain)
            let gain: Float = 5.0
            let normalizedRMS = min(max(rms * gain, 0), 1)
            
            Task { @MainActor in
                // Update visualizer levels
                var newLevels: [Float] = []
                for _ in 0..<15 {
                    let baseHeight = normalizedRMS
                    let jitter = Float.random(in: 0.0...0.2) * normalizedRMS
                    newLevels.append(min(baseHeight + jitter, 1.0))
                }
                self.levels = newLevels
            }
        }
    }
}

extension AudioAnalyzer: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        Task { @MainActor in
            processAudioBuffer(sampleBuffer)
        }
    }
}
