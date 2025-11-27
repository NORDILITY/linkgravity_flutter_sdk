package com.smartlink.smartlink_flutter_sdk

import android.content.Context
import android.os.RemoteException
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import com.android.installreferrer.api.ReferrerDetails

/**
 * Handler for Android Play Install Referrer API
 *
 * This class retrieves the install referrer from Play Store,
 * which contains the deferred deep link token for deterministic matching.
 *
 * The Play Install Referrer API provides 100% accurate attribution for
 * Android installs that originate from SmartLinks.
 */
class InstallReferrerHandler(private val context: Context) {
    private var referrerClient: InstallReferrerClient? = null
    private var isConnecting = false

    /**
     * Retrieve install referrer from Play Store
     *
     * @param onSuccess Callback with referrer string, install timestamp, and click timestamp
     * @param onError Callback with error code and message
     */
    fun getInstallReferrer(
        onSuccess: (referrer: String?, installTimestamp: Long, clickTimestamp: Long) -> Unit,
        onError: (errorCode: Int, message: String) -> Unit
    ) {
        if (isConnecting) {
            onError(-3, "Already connecting to Install Referrer service")
            return
        }

        isConnecting = true
        referrerClient = InstallReferrerClient.newBuilder(context).build()

        referrerClient?.startConnection(object : InstallReferrerStateListener {
            override fun onInstallReferrerSetupFinished(responseCode: Int) {
                isConnecting = false

                when (responseCode) {
                    InstallReferrerClient.InstallReferrerResponse.OK -> {
                        try {
                            val response: ReferrerDetails? = referrerClient?.installReferrer
                            val referrer = response?.installReferrer
                            val installTimestamp = response?.installBeginTimestampSeconds ?: 0L
                            val clickTimestamp = response?.referrerClickTimestampSeconds ?: 0L

                            onSuccess(referrer, installTimestamp, clickTimestamp)
                        } catch (e: RemoteException) {
                            onError(-1, "RemoteException: ${e.message}")
                        } catch (e: Exception) {
                            onError(-1, "Failed to get referrer details: ${e.message}")
                        } finally {
                            endConnection()
                        }
                    }
                    InstallReferrerClient.InstallReferrerResponse.FEATURE_NOT_SUPPORTED -> {
                        onError(responseCode, "Install Referrer API not supported on this device")
                        endConnection()
                    }
                    InstallReferrerClient.InstallReferrerResponse.SERVICE_UNAVAILABLE -> {
                        onError(responseCode, "Play Store service unavailable")
                        endConnection()
                    }
                    InstallReferrerClient.InstallReferrerResponse.DEVELOPER_ERROR -> {
                        onError(responseCode, "Developer error - check API usage")
                        endConnection()
                    }
                    InstallReferrerClient.InstallReferrerResponse.SERVICE_DISCONNECTED -> {
                        onError(responseCode, "Service was disconnected")
                        endConnection()
                    }
                    else -> {
                        onError(responseCode, "Unknown error code: $responseCode")
                        endConnection()
                    }
                }
            }

            override fun onInstallReferrerServiceDisconnected() {
                isConnecting = false
                // Connection to the service was lost
                // This can happen if the Play Store service is not available
                // We don't call onError here as the connection might be retried
            }
        })
    }

    /**
     * Close the connection to the Install Referrer service
     */
    fun endConnection() {
        try {
            referrerClient?.endConnection()
        } catch (e: Exception) {
            // Ignore exceptions when ending connection
        }
        referrerClient = null
        isConnecting = false
    }
}
