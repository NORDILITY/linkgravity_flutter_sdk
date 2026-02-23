import Foundation
import StoreKit

/// Native iOS service for SKAdNetwork 4.0+ integration
/// Handles conversion value updates and postback registration
@available(iOS 14.0, *)
class SKAdNetworkService {

    // MARK: - Singleton

    static let shared = SKAdNetworkService()

    private init() {}

    // MARK: - Public Methods

    /// Register app installation for SKAdNetwork attribution
    /// Should be called on first app launch
    func registerAppForAdNetworkAttribution() {
        #if DEBUG
        print("[LinkGravity] SKAdNetwork: Registering app for attribution")
        #endif

        // SKAdNetwork automatically handles registration
        // No explicit registration needed in iOS 14+
    }

    /// Update conversion value (iOS 14.0+)
    /// - Parameter conversionValue: 6-bit value (0-63)
    /// - Returns: Success status
    @available(iOS 14.0, *)
    func updateConversionValue(_ conversionValue: Int) -> Bool {
        guard conversionValue >= 0 && conversionValue <= 63 else {
            #if DEBUG
            print("[LinkGravity] SKAdNetwork: Invalid conversion value \(conversionValue). Must be 0-63")
            #endif
            return false
        }

        #if DEBUG
        print("[LinkGravity] SKAdNetwork: Updating conversion value to \(conversionValue)")
        #endif

        SKAdNetwork.updateConversionValue(conversionValue)
        return true
    }

    /// Update postback conversion value with completion handler (iOS 15.4+)
    /// - Parameters:
    ///   - fineValue: 6-bit fine-grained conversion value (0-63)
    ///   - coarseValue: Coarse conversion value (.low, .medium, .high)
    ///   - lockWindow: Whether to lock the conversion window
    ///   - completion: Completion handler with optional error
    @available(iOS 16.1, *)
    func updatePostbackConversionValue(
        _ fineValue: Int,
        coarseValue: SKAdNetwork.CoarseConversionValue,
        lockWindow: Bool,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard fineValue >= 0 && fineValue <= 63 else {
            #if DEBUG
            print("[LinkGravity] SKAdNetwork: Invalid fine value \(fineValue). Must be 0-63")
            #endif
            let error = NSError(
                domain: "com.linkgravity.skadnetwork",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid conversion value"]
            )
            completion?(error)
            return
        }

        #if DEBUG
        print("[LinkGravity] SKAdNetwork: Updating postback (fine: \(fineValue), coarse: \(coarseValue), lock: \(lockWindow))")
        #endif

        if #available(iOS 16.1, *) {
            // iOS 16.1+ - Use async/await version
            Task {
                do {
                    try await SKAdNetwork.updatePostbackConversionValue(
                        fineValue,
                        coarseValue: coarseValue,
                        lockWindow: lockWindow
                    )
                    #if DEBUG
                    print("[LinkGravity] SKAdNetwork: Postback update successful")
                    #endif
                    completion?(nil)
                } catch {
                    #if DEBUG
                    print("[LinkGravity] SKAdNetwork: Postback update failed - \(error)")
                    #endif
                    completion?(error)
                }
            }
        } else {
            // iOS 15.4 - 16.0 - Use completion handler version
            SKAdNetwork.updatePostbackConversionValue(
                fineValue,
                coarseValue: coarseValue,
                lockWindow: lockWindow
            ) { error in
                if let error = error {
                    #if DEBUG
                    print("[LinkGravity] SKAdNetwork: Postback update failed - \(error)")
                    #endif
                    completion?(error)
                } else {
                    #if DEBUG
                    print("[LinkGravity] SKAdNetwork: Postback update successful")
                    #endif
                    completion?(nil)
                }
            }
        }
    }

    /// Get current iOS version for SKAdNetwork capabilities
    func getSKAdNetworkVersion() -> String {
        if #available(iOS 16.1, *) {
            return "4.0"
        } else if #available(iOS 15.4, *) {
            return "3.0"
        } else if #available(iOS 14.6, *) {
            return "2.2"
        } else if #available(iOS 14.0, *) {
            return "2.0"
        } else {
            return "Not supported"
        }
    }

    /// Check if SKAdNetwork is available on this device
    func isAvailable() -> Bool {
        if #available(iOS 14.0, *) {
            return true
        }
        return false
    }
}

// MARK: - Coarse Conversion Value Extension

@available(iOS 16.1, *)
extension SKAdNetwork.CoarseConversionValue {
    /// Create from string representation
    static func from(string: String) -> SKAdNetwork.CoarseConversionValue {
        switch string.lowercased() {
        case "low":
            return .low
        case "medium":
            return .medium
        case "high":
            return .high
        default:
            return .medium
        }
    }

    /// Convert to string representation
    func toString() -> String {
        switch self {
        case .low:
            return "low"
        case .medium:
            return "medium"
        case .high:
            return "high"
        default:
            return "medium"
        }
    }
}
