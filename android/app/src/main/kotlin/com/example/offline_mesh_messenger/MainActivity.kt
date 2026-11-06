package com.example.offline_mesh_messenger

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingServiceResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "offline_mesh/service").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> requestPermissionsAndStart(result)
                "stop" -> {
                    stopService(Intent(this, MeshForegroundService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestPermissionsAndStart(result: MethodChannel.Result) {
        if (pendingServiceResult != null) {
            result.error("permission_request_active", "A permission request is already in progress.", null)
            return
        }
        val needed = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            needed += Manifest.permission.POST_NOTIFICATIONS
        }
        if (Build.VERSION.SDK_INT >= 31 && checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
            needed += Manifest.permission.BLUETOOTH_CONNECT
        }
        if (needed.isEmpty()) {
            startMeshService(result)
        } else {
            pendingServiceResult = result
            ActivityCompat.requestPermissions(this, needed.toTypedArray(), SERVICE_PERMISSION_REQUEST)
        }
    }

    private fun startMeshService(result: MethodChannel.Result) {
        try {
            val intent = Intent(this, MeshForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
            result.success(null)
        } catch (error: Exception) {
            result.error("service_start_failed", error.localizedMessage, null)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != SERVICE_PERMISSION_REQUEST) return
        val result = pendingServiceResult ?: return
        pendingServiceResult = null
        if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
            startMeshService(result)
        } else {
            result.error("permission_denied", "Notification and nearby-device permissions are required to start this service.", null)
        }
    }

    private companion object { const val SERVICE_PERMISSION_REQUEST = 1002 }
}
