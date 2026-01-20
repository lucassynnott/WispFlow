import Foundation

/// US-013: Device capability assessment for model recommendations
/// Analyzes device RAM and chip type to recommend optimal Whisper model
@MainActor
final class DeviceCapabilityManager: ObservableObject {

    // MARK: - Types

    /// Apple Silicon chip tier for capability assessment
    enum ChipTier: Comparable {
        case unknown
        case m1Base        // M1, M1 Pro, M1 Max, M1 Ultra
        case m2Base        // M2, M2 Pro, M2 Max, M2 Ultra
        case m3Base        // M3, M3 Pro, M3 Max, M3 Ultra
        case m4Base        // M4, M4 Pro, M4 Max (future)
        case intel         // Intel Macs (limited support)

        /// Whether this is a Pro/Max/Ultra variant (detected separately)
        var isAppleSilicon: Bool {
            switch self {
            case .intel, .unknown:
                return false
            default:
                return true
            }
        }
    }

    /// Device capability assessment result
    struct DeviceCapability {
        let ramGB: Int
        let chipTier: ChipTier
        let isProMaxUltra: Bool  // Pro, Max, or Ultra variant
        let processorName: String

        /// Overall capability score for model selection (0-100)
        var capabilityScore: Int {
            var score = 0

            // RAM contribution (up to 40 points)
            switch ramGB {
            case 0..<8: score += 10
            case 8..<16: score += 20
            case 16..<32: score += 30
            case 32..<64: score += 35
            default: score += 40  // 64GB+
            }

            // Chip tier contribution (up to 40 points)
            switch chipTier {
            case .unknown, .intel: score += 10
            case .m1Base: score += 25
            case .m2Base: score += 30
            case .m3Base: score += 35
            case .m4Base: score += 40
            }

            // Pro/Max/Ultra bonus (up to 20 points)
            if isProMaxUltra {
                score += 20
            }

            return min(score, 100)
        }
    }

    // MARK: - Singleton

    static let shared = DeviceCapabilityManager()

    // MARK: - Published Properties

    /// Current device capability assessment
    @Published private(set) var deviceCapability: DeviceCapability

    /// Recommended model for this device
    @Published private(set) var recommendedModel: WhisperManager.ModelSize

    // MARK: - Initialization

    private init() {
        // Assess device capability on init
        let capability = DeviceCapabilityManager.assessDeviceCapability()
        self.deviceCapability = capability
        self.recommendedModel = DeviceCapabilityManager.computeRecommendedModel(for: capability)
    }

    // MARK: - Device Assessment

    /// Assess current device capabilities
    private static func assessDeviceCapability() -> DeviceCapability {
        // Get RAM
        let memoryBytes = ProcessInfo.processInfo.physicalMemory
        let ramGB = Int(Double(memoryBytes) / (1024 * 1024 * 1024))

        // Get processor info
        var processorInfo = "Unknown"
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        if size > 0 {
            var brand = [CChar](repeating: 0, count: size)
            sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
            processorInfo = String(cString: brand)
        }

        // Parse chip tier and variant
        let (chipTier, isProMaxUltra) = parseChipInfo(from: processorInfo)

        return DeviceCapability(
            ramGB: ramGB,
            chipTier: chipTier,
            isProMaxUltra: isProMaxUltra,
            processorName: processorInfo
        )
    }

    /// Parse chip tier and variant from processor string
    private static func parseChipInfo(from processorInfo: String) -> (ChipTier, Bool) {
        let lowercased = processorInfo.lowercased()

        // Check for Intel
        if lowercased.contains("intel") {
            return (.intel, false)
        }

        // Check for Apple Silicon
        let isProMaxUltra = lowercased.contains("pro") ||
                           lowercased.contains("max") ||
                           lowercased.contains("ultra")

        // Detect chip generation
        if lowercased.contains("m4") {
            return (.m4Base, isProMaxUltra)
        } else if lowercased.contains("m3") {
            return (.m3Base, isProMaxUltra)
        } else if lowercased.contains("m2") {
            return (.m2Base, isProMaxUltra)
        } else if lowercased.contains("m1") {
            return (.m1Base, isProMaxUltra)
        }

        // Unknown chip (could be newer or ARM-based but not identified)
        return (.unknown, false)
    }

    // MARK: - Model Recommendation

    /// Compute recommended model based on device capability
    /// Balances speed and accuracy for optimal user experience
    private static func computeRecommendedModel(for capability: DeviceCapability) -> WhisperManager.ModelSize {
        let score = capability.capabilityScore
        let ramGB = capability.ramGB

        // Recommendation logic based on capability score and RAM
        // Prioritizes a balance of speed and accuracy

        // High-end devices (64+ score, 16GB+ RAM): Recommend Medium
        // Medium is sweet spot - great accuracy without Large's slowness
        if score >= 64 && ramGB >= 16 {
            return .medium
        }

        // Mid-range devices (45-63 score, 8GB+ RAM): Recommend Small
        // Small provides good accuracy with reasonable speed
        if score >= 45 && ramGB >= 8 {
            return .small
        }

        // Entry-level Apple Silicon (25-44 score, 8GB RAM): Recommend Base
        // Base is fast with decent accuracy
        if score >= 25 && ramGB >= 8 {
            return .base
        }

        // Low-end or Intel devices: Recommend Tiny
        // Tiny ensures usable performance on constrained hardware
        return .tiny
    }

    /// Check if a specific model is recommended for this device
    func isModelRecommended(_ model: WhisperManager.ModelSize) -> Bool {
        return model == recommendedModel
    }

    /// Get recommendation reason text for UI display
    func recommendationReason() -> String {
        let cap = deviceCapability

        switch recommendedModel {
        case .tiny:
            return "Best for your device's performance"
        case .base:
            return "Good balance for \(cap.ramGB)GB RAM"
        case .small:
            return "Optimal for your \(cap.processorName.contains("Apple") ? "Apple Silicon" : "device")"
        case .medium:
            return "Best accuracy for your hardware"
        case .large:
            return "Maximum accuracy for high-end devices"
        }
    }
}
