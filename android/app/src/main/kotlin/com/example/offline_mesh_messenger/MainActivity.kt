package com.example.offline_mesh_messenger

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingServiceResult: MethodChannel.Result? = null
    private var hotspotReservation: WifiManager.LocalOnlyHotspotReservation? = null
    private var pendingHotspotResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "offline_mesh/service").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> requestPermissionsAndStart(result)
                "stop" -> { stopService(Intent(this, MeshForegroundService::class.java)); result.success(null) }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "offline_mesh/share").setMethodCallHandler { call, result ->
            when (call.method) {
                "startHotspot" -> startLocalHotspot(result)
                "stopHotspot" -> { hotspotReservation?.close(); hotspotReservation = null; result.success(null) }
                "getApkPath" -> result.success(applicationInfo.sourceDir)
                else -> result.notImplemented()
            }
        }
    }

    private fun startLocalHotspot(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.error("unsupported", "Local-only hotspot requires Android 8.0 or newer.", null); return
        }
        if (hotspotReservation != null) {
            result.success(hotspotInfo(hotspotReservation!!)); return
        }
        if (pendingHotspotResult != null) {
            result.error("busy", "A hotspot request is already in progress.", null); return
        }
        pendingHotspotResult = result
        try {
            val wifiManager = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
            wifiManager.startLocalOnlyHotspot(object : WifiManager.LocalOnlyHotspotCallback() {
                override fun onStarted(reservation: WifiManager.LocalOnlyHotspotReservation) {
                    hotspotReservation = reservation
                    val callback = pendingHotspotResult
                    pendingHotspotResult = null
                    callback?.success(hotspotInfo(reservation))
                }
                override fun onStopped() {
                    hotspotReservation = null
                }
                override fun onFailed(reason: Int) {
                    val callback = pendingHotspotResult
                    pendingHotspotResult = null
                    callback?.error("hotspot_failed", "Android could not start a local hotspot (reason $reason).", null)
                }
            }, null)
        } catch (error: SecurityException) {
            pendingHotspotResult = null
            result.error("permission_denied", "Grant the nearby Wi-Fi/location permission required by this Android version.", error.localizedMessage)
        } catch (error: Exception) {
            pendingHotspotResult = null
            result.error("hotspot_failed", error.localizedMessage, null)
        }
    }

    private fun hotspotInfo(reservation: WifiManager.LocalOnlyHotspotReservation): Map<String, String> {
        val config = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) reservation.softApConfiguration else null
        @Suppress("DEPRECATION")
        val legacy = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) reservation.wifiConfiguration else null
        val ssid = config?.ssid ?: legacy?.SSID?.trim('"') ?: "Local hotspot"
        val passphrase = config?.passphrase ?: legacy?.preSharedKey?.trim('"') ?: ""
        return mapOf("ssid" to ssid, "passphrase" to passphrase)
    }

    private fun requestPermissionsAndStart(result: MethodChannel.Result) {
        if (pendingServiceResult != null) { result.error("permission_request_active", "A permission request is already in progress.", null); return }
        val needed = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) needed += Manifest.permission.POST_NOTIFICATIONS
        if (needed.isEmpty()) startMeshService(result) else {
            pendingServiceResult = result
            ActivityCompat.requestPermissions(this, needed.toTypedArray(), SERVICE_PERMISSION_REQUEST)
        }
    }

    private fun startMeshService(result: MethodChannel.Result) {
        try {
            val intent = Intent(this, MeshForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
            result.success(null)
        } catch (error: Exception) { result.error("service_start_failed", error.localizedMessage, null) }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != SERVICE_PERMISSION_REQUEST) return
        val result = pendingServiceResult ?: return
        pendingServiceResult = null
        if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) startMeshService(result)
        else result.error("permission_denied", "Notification permission is required to show the foreground service.", null)
    }

    override fun onDestroy() {
        hotspotReservation?.close()
        hotspotReservation = null
        super.onDestroy()
    }

    private companion object { const val SERVICE_PERMISSION_REQUEST = 1002 }
}
