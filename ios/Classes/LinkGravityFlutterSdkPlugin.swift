import Flutter
import UIKit
import StoreKit
import AppTrackingTransparency
import AdSupport

public class LinkGravityFlutterSdkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "linkgravity_flutter_sdk", binaryMessenger: registrar.messenger())
    let instance = LinkGravityFlutterSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)

    // MARK: - SKAdNetwork Methods

    case "skad_updateConversionValue":
      handleSKAdUpdateConversionValue(call: call, result: result)

    case "skad_updatePostbackConversionValue":
      handleSKAdUpdatePostbackConversionValue(call: call, result: result)

    case "skad_getSKAdNetworkVersion":
      handleGetSKAdNetworkVersion(result: result)

    case "skad_isAvailable":
      handleSKAdIsAvailable(result: result)

    // MARK: - ATT Methods

    case "att_requestAuthorization":
      handleATTRequestAuthorization(result: result)

    case "att_getAuthorizationStatus":
      handleATTGetAuthorizationStatus(result: result)

    case "att_getIDFA":
      handleATTGetIDFA(result: result)

    case "att_isAvailable":
      handleATTIsAvailable(result: result)

    case "att_getTrackingInfo":
      handleATTGetTrackingInfo(result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - SKAdNetwork Handlers

  private func handleSKAdUpdateConversionValue(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 14.0, *) else {
      result(FlutterError(code: "UNAVAILABLE", message: "SKAdNetwork requires iOS 14.0+", details: nil))
      return
    }

    guard let args = call.arguments as? [String: Any],
          let conversionValue = args["conversionValue"] as? Int else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "conversionValue required", details: nil))
      return
    }

    let success = SKAdNetworkService.shared.updateConversionValue(conversionValue)
    result(success)
  }

  private func handleSKAdUpdatePostbackConversionValue(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(FlutterError(code: "UNAVAILABLE", message: "SKAdNetwork postback requires iOS 16.1+", details: nil))
      return
    }

    guard let args = call.arguments as? [String: Any],
          let fineValue = args["fineValue"] as? Int,
          let coarseValueString = args["coarseValue"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "fineValue and coarseValue required", details: nil))
      return
    }

    let lockWindow = args["lockWindow"] as? Bool ?? false
    let coarseValue = SKAdNetwork.CoarseConversionValue.from(string: coarseValueString)

    SKAdNetworkService.shared.updatePostbackConversionValue(
      fineValue,
      coarseValue: coarseValue,
      lockWindow: lockWindow
    ) { error in
      if let error = error {
        result(FlutterError(code: "UPDATE_FAILED", message: error.localizedDescription, details: nil))
      } else {
        result(true)
      }
    }
  }

  private func handleGetSKAdNetworkVersion(result: @escaping FlutterResult) {
    if #available(iOS 14.0, *) {
      result(SKAdNetworkService.shared.getSKAdNetworkVersion())
    } else {
      result("Not supported")
    }
  }

  private func handleSKAdIsAvailable(result: @escaping FlutterResult) {
    if #available(iOS 14.0, *) {
      result(SKAdNetworkService.shared.isAvailable())
    } else {
      result(false)
    }
  }

  // MARK: - ATT Handlers

  private func handleATTRequestAuthorization(result: @escaping FlutterResult) {
    guard #available(iOS 14.0, *) else {
      // Pre-iOS 14 - tracking always authorized
      result(3)
      return
    }

    ATTService.shared.requestTrackingAuthorization { status in
      result(status)
    }
  }

  private func handleATTGetAuthorizationStatus(result: @escaping FlutterResult) {
    if #available(iOS 14.0, *) {
      result(ATTService.shared.getTrackingAuthorizationStatus())
    } else {
      result(3) // .authorized
    }
  }

  private func handleATTGetIDFA(result: @escaping FlutterResult) {
    if let idfa = ATTService.shared.getIDFA() {
      result(idfa)
    } else {
      result(nil)
    }
  }

  private func handleATTIsAvailable(result: @escaping FlutterResult) {
    result(ATTService.shared.isATTAvailable())
  }

  private func handleATTGetTrackingInfo(result: @escaping FlutterResult) {
    result(ATTService.shared.getTrackingInfo())
  }
}
