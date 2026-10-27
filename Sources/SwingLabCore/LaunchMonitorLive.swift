import Foundation

/// Integer pixel rectangle, origin top-left.
public struct PixelRect: Codable, Sendable, Equatable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int
    public init(x: Int, y: Int, width: Int, height: Int) { self.x = x; self.y = y; self.width = width; self.height = height }
}

/// The region the launch tracker reads, in the upright frame: a little behind the ball, most of the
/// frame ahead of it in the target direction, and mostly above it. Shared by the recorded-video and
/// live paths so both measure the same window.
public enum LaunchRegion {
    public static func around(ball: PixelPoint, frameWidth: Int, frameHeight: Int, targetDirection: Double) -> PixelRect? {
        guard frameWidth > 0, frameHeight > 0, ball.x.isFinite, ball.y.isFinite else { return nil }
        let ahead = Int(0.65 * Double(frameWidth)), back = max(40, frameWidth / 25)
        let left = targetDirection > 0 ? Int(ball.x) - back : Int(ball.x) - ahead
        let x0 = max(0, left), y0 = max(0, Int(ball.y) - Int(0.5 * Double(frameHeight)))
        let x1 = min(frameWidth, x0 + back + ahead), y1 = min(frameHeight, y0 + Int(0.5 * Double(frameHeight)) + back)
        guard x1 - x0 > 32, y1 - y0 > 32 else { return nil }
        return PixelRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }

    /// How far from the tapped point the ball centre is searched for.
    public static func searchRadius(frameWidth: Int) -> Int { max(20, frameWidth / 40) }
}

public enum LaunchPipelineFailure: Error, Equatable, Sendable {
    case scaleNotFound
    case missingFrames
    case launch(LaunchFailure)
}

/// Address frames give the scale; frames after impact give the track. Pure, so the recorded-video
/// analyzer and the live monitor run exactly the same measurement.
public enum LaunchPipeline {
    public struct Outcome: Sendable {
        public let measurement: LaunchMeasurement
        public let scale: BallScale
    }

    /// - Parameters:
    ///   - ball: tapped ball centre in the region's coordinates.
    ///   - targetDirection: +1 when the ball flies towards +x.
    public static func measure(address: [GrayImage], flight: [(time: Double, image: GrayImage)], ball: PixelPoint,
                               searchRadius: Int, targetDirection: Double) -> Result<Outcome, LaunchPipelineFailure> {
        guard let reference = address.last, !flight.isEmpty else { return .failure(.missingFrames) }
        guard let scale = BallScaleFitter.fit(frames: address, near: ball, searchRadius: searchRadius) else {
            return .failure(.scaleNotFound)
        }
        let observations: [LaunchObservation]
        switch LaunchTracker.observe(frames: flight, reference: reference, scale: scale, exposure: nil, targetDirection: targetDirection) {
        case let .success(found): observations = found
        case let .failure(reason): return .failure(.launch(reason))
        }
        return LaunchTracker.fit(observations, scale: scale).map { Outcome(measurement: $0, scale: scale) }.mapError { .launch($0) }
    }
}

/// How a camera buffer turns upright. Back-camera buffers arrive in the sensor's landscape
/// orientation; a portrait iPhone needs a quarter turn clockwise (rotation angle 90°).
public enum LumaRotation: Sendable {
    case none
    case clockwise

    public func rotatedSize(width: Int, height: Int) -> (width: Int, height: Int) {
        self == .none ? (width, height) : (height, width)
    }

    /// The source rectangle whose rotation is `rect` (given in rotated coordinates).
    public func sourceRect(for rect: PixelRect, sourceWidth: Int, sourceHeight: Int) -> PixelRect {
        switch self {
        case .none: return rect
        // Rotated (x', y') reads source (y', H − 1 − x').
        case .clockwise: return PixelRect(x: rect.y, y: sourceHeight - rect.x - rect.width, width: rect.height, height: rect.width)
        }
    }
}

/// One 8-bit luminance crop as delivered by the camera, before it is turned upright.
public struct LumaFrame: Sendable {
    public let time: Double
    public let width: Int
    public let height: Int
    /// Row-major, top row first.
    public let bytes: [UInt8]

    public init(time: Double, width: Int, height: Int, bytes: [UInt8]) {
        precondition(bytes.count == width * height, "LumaFrame size mismatch")
        self.time = time; self.width = width; self.height = height; self.bytes = bytes
    }

    public func rotated(_ rotation: LumaRotation) -> LumaFrame {
        guard rotation == .clockwise else { return self }
        var out = [UInt8](repeating: 0, count: bytes.count)
        let rotatedWidth = height
        for y in 0..<height {
            let row = y * width, column = height - 1 - y
            for x in 0..<width { out[x * rotatedWidth + column] = bytes[row + x] }
        }
        return LumaFrame(time: time, width: height, height: width, bytes: out)
    }

    /// Upright luminance in 0...1.
    public func gray(_ rotation: LumaRotation) -> GrayImage {
        let upright = rotated(rotation)
        return GrayImage(width: upright.width, height: upright.height, pixels: upright.bytes.map { Float($0) / 255 })
    }
}

/// The newest frames, oldest first. Fixed capacity so memory stays bounded at 240 fps.
public struct FrameRing: Sendable {
    public let capacity: Int
    private var storage: [LumaFrame] = []
    private var next = 0

    public init(capacity: Int) { self.capacity = max(1, capacity) }

    public var count: Int { storage.count }
    public var latestTime: Double? { storage.isEmpty ? nil : storage[(next - 1 + storage.count) % storage.count].time }
    public var ordered: [LumaFrame] { storage.count < capacity ? storage : Array(storage[next...] + storage[..<next]) }

    /// Frames must arrive in time order; a frame that does not advance time is dropped.
    public mutating func append(_ frame: LumaFrame) {
        if let latestTime, frame.time <= latestTime { return }
        if storage.count < capacity { storage.append(frame); next = storage.count % capacity }
        else { storage[next] = frame; next = (next + 1) % capacity }
    }

    public mutating func removeAll() { storage.removeAll(keepingCapacity: true); next = 0 }
}

/// Finds the impact sound while audio streams in. A cheap per-chunk check (a first-difference peak
/// 12 dB over the recent floor) proposes a candidate; once 60 ms of sound after it has arrived, the
/// full `ImpactOnsetDetector` confirms and times it on the last second of history.
public struct StreamingImpactTrigger: Sendable {
    public static let historySeconds = 1.0
    public static let settleSeconds = 0.06
    public static let refractorySeconds = 1.5
    public let sampleRate: Double
    private var history: [Float] = []
    private var historyStart = 0.0
    private var chunkPeaks: [Float] = []
    private var pending: (start: Double, end: Double)?
    private var quietUntil = -Double.infinity

    public init(sampleRate: Double) { self.sampleRate = sampleRate }

    public mutating func append(_ samples: [Float], startTime: Double) -> AudioImpactEstimate? {
        guard sampleRate >= 8_000, !samples.isEmpty, startTime.isFinite else { return nil }
        let chunkEnd = startTime + Double(samples.count) / sampleRate
        // A gap or overlap of more than 5 ms means the stream restarted: start over.
        if history.isEmpty || abs(startTime - (historyStart + Double(history.count) / sampleRate)) > 0.005 {
            history = []; historyStart = startTime; chunkPeaks = []; pending = nil
        }
        var previous = history.last ?? samples[0], peak: Float = 0
        for sample in samples { peak = max(peak, abs(sample - previous)); previous = sample }
        history.append(contentsOf: samples)
        let overflow = history.count - Int(Self.historySeconds * sampleRate)
        if overflow > 0 { history.removeFirst(overflow); historyStart += Double(overflow) / sampleRate }

        let floor = chunkPeaks.sorted()[safe: chunkPeaks.count / 2] ?? 0
        chunkPeaks.append(peak)
        if chunkPeaks.count > 64 { chunkPeaks.removeFirst(chunkPeaks.count - 64) }
        if pending == nil, startTime >= quietUntil, chunkPeaks.count > 8, floor > 0,
           peak > floor * Float(pow(10, ImpactOnsetDetector.candidateThresholdDB / 20)),
           startTime - historyStart >= 0.25 {
            pending = (startTime, chunkEnd)
        }
        guard let candidate = pending, chunkEnd >= candidate.end + Self.settleSeconds else { return nil }
        pending = nil
        let window = (candidate.start - 0.02)...(candidate.end + 0.03)
        guard case let .success(estimate) = ImpactOnsetDetector.detect(samples: history, sampleRate: sampleRate,
                                                                      startTime: historyStart, window: window, poseImpact: nil),
              estimate.provenance == .audioDerived else { return nil }
        quietUntil = estimate.time + Self.refractorySeconds
        return estimate
    }
}

/// Real-time launch window. Video crops and sound are appended as they are captured; once the audio
/// impact and six frames after it are in, the session hands back the frames for `LaunchPipeline`.
public struct LiveLaunchSession: Sendable {
    public struct Capture: Sendable {
        public let impactTime: Double
        public let address: [LumaFrame]
        public let flight: [LumaFrame]
    }

    public enum Event: Sendable {
        case impact(AudioImpactEstimate)
        case capture(Capture)
        /// The impact was heard but the frames around it were not all in the buffer.
        case missedWindow(impactTime: Double)
    }

    /// Same window as the recorded-video path: four still frames, then six frames after impact.
    public static let addressLeads = [0.25, 0.20, 0.15, 0.10]
    public static let flightFrameCount = 6
    public let frameRate: Double
    private var ring: FrameRing
    private var trigger: StreamingImpactTrigger
    private var pendingImpact: Double?

    public init(frameRate: Double, sampleRate: Double) {
        self.frameRate = frameRate
        // The oldest address frame, plus the time the sound needs to be confirmed and delivered.
        let span = (Self.addressLeads.max() ?? 0.25) + StreamingImpactTrigger.settleSeconds + 0.2
        ring = FrameRing(capacity: Int((span * frameRate).rounded(.up)) + 16)
        trigger = StreamingImpactTrigger(sampleRate: sampleRate)
    }

    public mutating func appendVideo(_ frame: LumaFrame) -> [Event] {
        ring.append(frame)
        return resolve().map { [$0] } ?? []
    }

    public mutating func appendAudio(_ samples: [Float], startTime: Double) -> [Event] {
        var events: [Event] = []
        if let estimate = trigger.append(samples, startTime: startTime) {
            pendingImpact = estimate.time
            events.append(.impact(estimate))
        }
        if let event = resolve() { events.append(event) }
        return events
    }

    private mutating func resolve() -> Event? {
        guard let impact = pendingImpact, let latest = ring.latestTime else { return nil }
        let frames = ring.ordered
        let after = frames.filter { $0.time > impact }
        guard after.count >= Self.flightFrameCount else {
            guard latest > impact + 0.2 else { return nil }
            pendingImpact = nil
            return .missedWindow(impactTime: impact)
        }
        pendingImpact = nil
        let tolerance = 1.5 / frameRate
        var address: [LumaFrame] = []
        for lead in Self.addressLeads {
            let target = impact - lead
            guard let nearest = frames.min(by: { abs($0.time - target) < abs($1.time - target) }),
                  abs(nearest.time - target) <= tolerance else { return .missedWindow(impactTime: impact) }
            address.append(nearest)
        }
        return .capture(Capture(impactTime: impact, address: address, flight: Array(after.prefix(Self.flightFrameCount))))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
