package com.example.nutrition_flutter

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log

/**
 * Health Connect permission rationale activity.
 * This activity is called by Health Connect to show permission rationale.
 */
class HealthConnectPermissionRationaleActivity : Activity() {
    companion object {
        private const val TAG = "HealthConnectRationale"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "HealthConnectPermissionRationaleActivity started")

        // For now, just finish immediately
        // In a real app, you would show a rationale dialog here
        finish()
    }
}