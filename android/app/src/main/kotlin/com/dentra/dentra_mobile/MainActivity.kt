package com.dentra.dentra_mobile

import android.Manifest
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PatternMatcher
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address

class MainActivity : FlutterActivity() {
    private val handler = Handler(Looper.getMainLooper())
    private val connectivity by lazy { getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager }
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var joinResult: MethodChannel.Result? = null
    private var pendingKey: String? = null
    private var discovery: NsdManager.DiscoveryListener? = null
    private var discoveryResult: MethodChannel.Result? = null
    private var joinTimeout: Runnable? = null
    private var discoveryTimeout: Runnable? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.dentra/wifi_setup")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "join" -> {
                        if (joinResult != null) {
                            result.error("busy", "A connection is already pending", null)
                        } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                            // On older Android the user joins in Settings.
                            // Bind that local-only network too, since cellular
                            // can remain the system's default internet route.
                            val local = connectivity.allNetworks.firstOrNull { network ->
                                connectivity.getNetworkCapabilities(network)
                                    ?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true &&
                                connectivity.getLinkProperties(network)?.routes?.any {
                                    it.gateway?.hostAddress == "192.168.4.1"
                                } == true
                            }
                            if (local != null && connectivity.bindProcessToNetwork(local)) result.success(null)
                            else result.error("unsupported", "Use Wi-Fi settings on Android 9 and earlier", null)
                        } else {
                            val key = call.argument<String>("password") ?: ""
                            if (!key.matches(Regex("[A-Za-z0-9]{16}"))) {
                                result.error("key", "Invalid setup key", null)
                            } else {
                                releaseNetwork()
                                joinResult = result
                                pendingKey = key
                                val permission = if (Build.VERSION.SDK_INT >= 33)
                                    Manifest.permission.NEARBY_WIFI_DEVICES else Manifest.permission.ACCESS_FINE_LOCATION
                                if (checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED) {
                                    val permissions = if (Build.VERSION.SDK_INT < 33)
                                        arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
                                        else arrayOf(permission)
                                    requestPermissions(permissions, 4207)
                                } else requestDeviceNetwork(key)
                            }
                        }
                    }
                    "leave" -> { releaseNetwork(); stopDiscovery(); result.success(null) }
                    "discover" -> discover(call.argument<String>("id") ?: "", result)
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 4207) return
        val key = pendingKey ?: return
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) requestDeviceNetwork(key)
        else finishJoin("permission")
    }

    private fun requestDeviceNetwork(key: String) {
        if (Build.VERSION.SDK_INT < 29) { finishJoin("unsupported"); return }
        pendingKey = null
        val specifier = WifiNetworkSpecifier.Builder()
            .setSsidPattern(PatternMatcher("Dentra Cam ", PatternMatcher.PATTERN_PREFIX))
            .setWpa2Passphrase(key).build()
        val request = NetworkRequest.Builder().addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .setNetworkSpecifier(specifier).build()
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) { handler.post {
                if (networkCallback !== this) return@post
                // Force local HTTP onto this Wi-Fi even when cellular is the
                // default route because the camera has no internet access.
                if (connectivity.bindProcessToNetwork(network)) finishJoin(null)
                else { finishJoin("unavailable"); releaseNetwork() }
            } }
            override fun onUnavailable() { handler.post {
                if (networkCallback !== this) return@post
                finishJoin("cancelled"); releaseNetwork()
            } }
            override fun onLost(network: Network) { handler.post {
                if (networkCallback !== this) return@post
                connectivity.bindProcessToNetwork(null)
                // Keep the request alive while AP+STA switches radio channel.
                // Dart reconciles the actual state via /setup/status.
            } }
        }
        networkCallback = callback
        joinTimeout = Runnable { finishJoin("unavailable"); releaseNetwork() }
        handler.postDelayed(joinTimeout!!, 65_000)
        try { connectivity.requestNetwork(request, callback, 60_000) }
        catch (_: SecurityException) { finishJoin("permission"); releaseNetwork() }
        catch (_: Exception) { finishJoin("unavailable"); releaseNetwork() }
    }

    private fun finishJoin(error: String?) {
        joinTimeout?.let { handler.removeCallbacks(it) }; joinTimeout = null
        val result = joinResult ?: return
        joinResult = null; pendingKey = null
        if (error == null) result.success(null) else result.error(error, "Wi-Fi connection did not complete", null)
    }

    private fun releaseNetwork() {
        finishJoin("cancelled")
        connectivity.bindProcessToNetwork(null)
        networkCallback?.let { try { connectivity.unregisterNetworkCallback(it) } catch (_: Exception) {} }
        networkCallback = null
    }

    @Suppress("DEPRECATION")
    private fun discover(id: String, result: MethodChannel.Result) {
        stopDiscovery()
        if (!id.matches(Regex("[A-Fa-f0-9]{12}"))) { result.success(null); return }
        val manager = getSystemService(NSD_SERVICE) as NsdManager
        discoveryResult = result
        val listener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(type: String) {}
            override fun onDiscoveryStopped(type: String) {}
            override fun onStartDiscoveryFailed(type: String, code: Int) { handler.post {
                if (discovery === this) completeDiscovery(null)
            } }
            override fun onStopDiscoveryFailed(type: String, code: Int) {}
            override fun onServiceLost(info: NsdServiceInfo) {}
            override fun onServiceFound(info: NsdServiceInfo) {
                if (!info.serviceName.contains(id.takeLast(4), ignoreCase = true)) return
                manager.resolveService(info, object : NsdManager.ResolveListener {
                    override fun onResolveFailed(service: NsdServiceInfo, code: Int) {}
                    override fun onServiceResolved(service: NsdServiceInfo) { handler.post {
                        if (discoveryResult !== result) return@post
                        val foundId = service.attributes["id"]?.toString(Charsets.UTF_8)
                        val host = service.host
                        if (foundId.equals(id, ignoreCase = true) && host is Inet4Address) {
                            completeDiscovery(host.hostAddress)
                        }
                    } }
                })
            }
        }
        discovery = listener
        discoveryTimeout = Runnable { completeDiscovery(null) }
        handler.postDelayed(discoveryTimeout!!, 10_000)
        try { manager.discoverServices("_dentracam._tcp.", NsdManager.PROTOCOL_DNS_SD, listener) }
        catch (_: Exception) { completeDiscovery(null) }
    }

    private fun completeDiscovery(host: String?) {
        val result = discoveryResult
        discoveryResult = null
        stopDiscovery()
        result?.success(host)
    }

    private fun stopDiscovery() {
        discoveryTimeout?.let { handler.removeCallbacks(it) }; discoveryTimeout = null
        discovery?.let { try { (getSystemService(NSD_SERVICE) as NsdManager).stopServiceDiscovery(it) } catch (_: Exception) {} }
        discovery = null
        discoveryResult?.success(null); discoveryResult = null
    }

    override fun onDestroy() {
        releaseNetwork(); stopDiscovery()
        super.onDestroy()
    }
}
