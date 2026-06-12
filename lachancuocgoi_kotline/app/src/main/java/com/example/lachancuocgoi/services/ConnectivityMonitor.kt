package com.example.lachancuocgoi.services

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class ConnectivityMonitor(context: Context) {

    companion object {
        private const val TAG = "ConnectivityMonitor"
    }

    private val appContext = context.applicationContext
    private val connectivityManager =
        appContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    private val _isNetworkAvailable = MutableStateFlow(checkCurrentConnectivity())
    val isNetworkAvailable: StateFlow<Boolean> = _isNetworkAvailable.asStateFlow()

    private var isStarted = false

    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            publishCurrentStatus()
        }

        override fun onLost(network: Network) {
            publishCurrentStatus()
        }

        override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
            publishCurrentStatus()
        }

        override fun onUnavailable() {
            _isNetworkAvailable.value = false
        }
    }

    fun start() {
        if (isStarted) return
        isStarted = true
        publishCurrentStatus()
        try {
            connectivityManager.registerDefaultNetworkCallback(networkCallback)
        } catch (e: Exception) {
            isStarted = false
            Log.e(TAG, "Failed to register network callback", e)
        }
    }

    fun stop() {
        if (!isStarted) return
        try {
            connectivityManager.unregisterNetworkCallback(networkCallback)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to unregister network callback cleanly", e)
        } finally {
            isStarted = false
        }
    }

    fun checkCurrentConnectivity(): Boolean {
        val activeNetwork = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(activeNetwork) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }

    private fun publishCurrentStatus() {
        _isNetworkAvailable.value = checkCurrentConnectivity()
    }
}
