package com.verdi.verdi

import android.Manifest
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity(), EventChannel.StreamHandler, LocationListener {
    private var sink: EventChannel.EventSink? = null
    private val manager: LocationManager get() = getSystemService(LOCATION_SERVICE) as LocationManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "verdi/phone_location").setStreamHandler(this)
    }
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION), 410)
        } else startLocations()
    }
    private fun startLocations() {
        if (sink == null) return
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            sink?.error("permission", "Precise location permission is required for trip distances. Enable it in Settings, then retry.", null)
            return
        }
        if (!manager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            sink?.error("disabled", "Turn on Location services, then retry tracking.", null)
            return
        }
        try {
            manager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 5000L, 0f, this, Looper.getMainLooper())
        } catch (_: SecurityException) {
            sink?.error("permission", "Location permission was revoked.", null)
        } catch (_: IllegalArgumentException) {
            sink?.error("unavailable", "This device has no GPS location provider.", null)
        }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 410) startLocations()
    }
    override fun onLocationChanged(location: Location) {
        if (!location.hasAccuracy()) return
        sink?.success(mapOf("latitude" to location.latitude, "longitude" to location.longitude,
            "accuracy" to location.accuracy.toDouble(), "timestamp" to location.time))
    }
    override fun onProviderDisabled(provider: String) {
        if (provider == LocationManager.GPS_PROVIDER) {
            manager.removeUpdates(this)
            sink?.error("disabled", "Location services were disabled. Tracking stopped.", null)
        }
    }
    override fun onProviderEnabled(provider: String) {}
    @Deprecated("Legacy Android callback")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
    override fun onCancel(arguments: Any?) { manager.removeUpdates(this); sink = null }
    override fun onStop() {
        manager.removeUpdates(this)
        sink?.error("paused", "App left the foreground. Re-enable tracking when you return.", null)
        super.onStop()
    }
    override fun onDestroy() { manager.removeUpdates(this); sink = null; super.onDestroy() }
}
