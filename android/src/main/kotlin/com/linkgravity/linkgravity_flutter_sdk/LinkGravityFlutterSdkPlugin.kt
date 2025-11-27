package com.smartlink.smartlink_flutter_sdk

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * SmartlinkFlutterSdkPlugin
 *
 * Flutter plugin for SmartLink SDK providing native Android functionality
 * including Play Install Referrer API access for deterministic deferred deep linking.
 */
class SmartlinkFlutterSdkPlugin : FlutterPlugin, MethodCallHandler {
    /// The MethodChannel that will handle communication between Flutter and native Android
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var installReferrerHandler: InstallReferrerHandler? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "smartlink_flutter_sdk")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "getInstallReferrer" -> {
                getInstallReferrer(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * Retrieve the install referrer from Play Store using the Install Referrer API
     *
     * Returns a map with:
     * - referrer: The referrer URL string (may contain deferred_link token)
     * - installTimestamp: Timestamp when the app was installed (seconds since epoch)
     * - clickTimestamp: Timestamp when the referrer link was clicked (seconds since epoch)
     *
     * On error, returns a map with:
     * - error: true
     * - errorCode: The error code from Install Referrer API
     * - message: Human-readable error message
     */
    private fun getInstallReferrer(result: Result) {
        installReferrerHandler = InstallReferrerHandler(context)

        installReferrerHandler?.getInstallReferrer(
            onSuccess = { referrer, installTimestamp, clickTimestamp ->
                result.success(
                    mapOf(
                        "referrer" to referrer,
                        "installTimestamp" to installTimestamp,
                        "clickTimestamp" to clickTimestamp
                    )
                )
            },
            onError = { errorCode, message ->
                result.success(
                    mapOf(
                        "error" to true,
                        "errorCode" to errorCode,
                        "message" to message
                    )
                )
            }
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        installReferrerHandler?.endConnection()
        installReferrerHandler = null
    }
}
