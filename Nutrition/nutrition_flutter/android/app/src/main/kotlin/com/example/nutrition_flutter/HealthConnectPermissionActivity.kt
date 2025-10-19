package com.example.nutrition_flutter

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.util.Log

/**
 * Health Connect permission activity.
 * Simply opens the Health Connect app so users can manually grant permissions.
 */
class HealthConnectPermissionActivity : Activity() {
    companion object {
        private const val TAG = "HealthConnectPermission"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "HealthConnectPermissionActivity started")
        
        // Check if Health Connect is installed
        if (!isHealthConnectInstalled()) {
            Log.w(TAG, "Health Connect not installed")
            openPlayStore()
            finish()
            return
        }
        
        // Open Health Connect app
        openHealthConnectApp()
        finish()
    }

    private fun openHealthConnectApp() {
        try {
            Log.d(TAG, "Opening Health Connect app")
            val intent = packageManager.getLaunchIntentForPackage("com.google.android.apps.healthdata")
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                startActivity(intent)
                Log.d(TAG, "Health Connect app launched")
            } else {
                Log.w(TAG, "Health Connect launch intent not found")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch Health Connect: ${e.message}")
        }
    }
    
    private fun openPlayStore() {
        try {
            Log.d(TAG, "Opening Play Store")
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=com.google.android.apps.healthdata"))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open Play Store: ${e.message}")
        }
    }
    
    private fun isHealthConnectInstalled(): Boolean {
        return try {
            packageManager.getPackageInfo("com.google.android.apps.healthdata", 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }
}
