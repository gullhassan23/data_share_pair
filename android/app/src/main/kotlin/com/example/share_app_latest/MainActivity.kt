package com.example.share_app_latest

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.wifi.WifiManager
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pDevice
import android.net.wifi.p2p.WifiP2pInfo
import android.net.wifi.p2p.WifiP2pManager
import android.provider.Settings
import android.content.BroadcastReceiver
import android.content.pm.PackageManager
import android.location.LocationManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterFragmentActivity() {

    private val HOTSPOT_CHANNEL = "com.example.share_app_latest/hotspot"
    private val P2P_CHANNEL = "com.example.share_app_latest/p2p"
    private val P2P_EVENT_CHANNEL = "com.example.share_app_latest/p2p_events"

    private var wifiP2pManager: WifiP2pManager? = null
    private var p2pChannel: WifiP2pManager.Channel? = null
    private var p2pReceiver: BroadcastReceiver? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Hotspot Methods (open system settings)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HOTSPOT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openHotspotSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_WIRELESS_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("HOTSPOT_ERROR", "Failed to open hotspot settings: ${e.message}", null)
                    }
                }
                "openLocationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("HOTSPOT_ERROR", "Failed to open location settings: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // P2P Methods
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, P2P_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startP2P" -> startP2P(result)
                "stopP2P" -> stopP2P(result)
                "connectToPeer" -> {
                    val addr = call.argument<String>("deviceAddress") ?: ""
                    connectToPeer(addr, result)
                }
                "removeGroup" -> removeGroup(result)
                else -> result.notImplemented()
            }
        }

        // P2P Event Channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, P2P_EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    // ------------------- P2P FUNCTIONS -------------------

    private fun startP2P(result: MethodChannel.Result) {
        try {
            // Pre-checks
            if (!packageManager.hasSystemFeature(PackageManager.FEATURE_WIFI_DIRECT)) {
                val msg = "P2P_UNSUPPORTED"
                eventSink?.success(mapOf("type" to "p2pError", "message" to msg, "code" to -1))
                result.error("P2P_ERROR", "Discovery failed: $msg", null)
                return
            }

            val wifiMgr = getSystemService(Context.WIFI_SERVICE) as WifiManager
            if (!wifiMgr.isWifiEnabled) {
                val msg = "WIFI_DISABLED"
                eventSink?.success(mapOf("type" to "p2pError", "message" to msg, "code" to -2))
                result.error("P2P_ERROR", "Discovery failed: $msg", null)
                return
            }

            val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val locationEnabled = try {
                lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) || lm.isProviderEnabled(LocationManager.GPS_PROVIDER)
            } catch (e: Exception) {
                false
            }
            if (!locationEnabled) {
                val msg = "LOCATION_DISABLED"
                eventSink?.success(mapOf("type" to "p2pError", "message" to msg, "code" to -3))
                result.error("P2P_ERROR", "Discovery failed: $msg", null)
                return
            }

            wifiP2pManager = getSystemService(Context.WIFI_P2P_SERVICE) as WifiP2pManager
            p2pChannel = wifiP2pManager?.initialize(this, mainLooper, null)
            if (wifiP2pManager == null || p2pChannel == null) {
                val msg = "P2P_INIT_FAILED"
                eventSink?.success(mapOf("type" to "p2pError", "message" to msg, "code" to -4))
                result.error("P2P_ERROR", "Discovery failed: $msg", null)
                return
            }

            val filter = IntentFilter().apply {
                addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION)
                addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION)
                addAction(WifiP2pManager.WIFI_P2P_THIS_DEVICE_CHANGED_ACTION)
            }

            p2pReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    when (intent?.action) {
                        WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION -> {
                            wifiP2pManager?.requestPeers(p2pChannel) { peers ->
                                for (device in peers.deviceList) {
                                    val map = mapOf(
                                        "type" to "peerFound",
                                        "name" to device.deviceName,
                                        "deviceAddress" to device.deviceAddress
                                    )
                                    eventSink?.success(map)
                                }
                            }
                        }
                        WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION -> {
                            val networkInfo = intent.getParcelableExtra<android.net.NetworkInfo>(WifiP2pManager.EXTRA_NETWORK_INFO)
                            if (networkInfo?.isConnected == true) {
                                wifiP2pManager?.requestConnectionInfo(p2pChannel) { info: WifiP2pInfo ->
                                    val addr = info.groupOwnerAddress?.hostAddress ?: ""
                                    val map = mapOf(
                                        "type" to "connectionInfo",
                                        "groupOwnerIp" to addr,
                                        "isGroupOwner" to info.isGroupOwner
                                    )
                                    eventSink?.success(map)
                                }
                            }
                        }
                        WifiP2pManager.WIFI_P2P_THIS_DEVICE_CHANGED_ACTION -> {
                            // ignore
                        }
                    }
                }
            }

            registerReceiver(p2pReceiver, filter)

            wifiP2pManager?.discoverPeers(p2pChannel, object : WifiP2pManager.ActionListener {
                override fun onSuccess() {
                    result.success(true)
                }
                override fun onFailure(reason: Int) {
                    val msg = when (reason) {
                        WifiP2pManager.BUSY -> "BUSY"
                        WifiP2pManager.P2P_UNSUPPORTED -> "P2P_UNSUPPORTED"
                        WifiP2pManager.ERROR -> "ERROR"
                        else -> "UNKNOWN($reason)"
                    }
                    eventSink?.success(mapOf("type" to "p2pError", "message" to msg, "code" to reason))
                    result.error("P2P_ERROR", "Discovery failed: $msg", null)
                }
            })

        } catch (e: Exception) {
            eventSink?.success(mapOf("type" to "p2pError", "message" to "EXCEPTION: ${e.message}", "code" to -99))
            result.error("P2P_ERROR", "Failed to start P2P: ${e.message}", null)
        }
    }

    private fun stopP2P(result: MethodChannel.Result) {
        try {
            wifiP2pManager?.stopPeerDiscovery(p2pChannel, object : WifiP2pManager.ActionListener {
                override fun onSuccess() {}
                override fun onFailure(reason: Int) {}
            })
            try {
                p2pReceiver?.let { unregisterReceiver(it) }
            } catch (e: Exception) {}
            p2pReceiver = null
            result.success(true)
        } catch (e: Exception) {
            result.error("P2P_ERROR", "Failed to stop P2P: ${e.message}", null)
        }
    }

private fun connectToPeer(addr: String, result: MethodChannel.Result) {
    try {
        val config = WifiP2pConfig().apply {
            deviceAddress = addr
        }

        wifiP2pManager?.connect(
            p2pChannel,
            config,
            object : WifiP2pManager.ActionListener {
                override fun onSuccess() {
                    result.success(true)
                }

                override fun onFailure(reason: Int) {
                    result.error("P2P_ERROR", "Connect failed: $reason", null)
                }
            }
        )
    } catch (e: Exception) {
        result.error("P2P_ERROR", "connectToPeer failed: ${e.message}", null)
    }
}



    private fun removeGroup(result: MethodChannel.Result) {
        try {
            wifiP2pManager?.removeGroup(p2pChannel, object : WifiP2pManager.ActionListener {
                override fun onSuccess() { result.success(true) }
                override fun onFailure(reason: Int) { result.error("P2P_ERROR", "Remove group failed: $reason", null) }
            })
        } catch (e: Exception) {
            result.error("P2P_ERROR", "removeGroup failed: ${e.message}", null)
        }
    }
}
