package com.example.nutrition_flutter

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.example.nutrition_flutter/healthconnect"
    private val TAG = "MainActivity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchPermissions" -> {
                    Log.d(TAG, "launchPermissions called")
                    try {
                        val intent = Intent(this, HealthConnectPermissionActivity::class.java)
                        startActivity(intent)
                        Log.d(TAG, "HealthConnectPermissionActivity started successfully")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to launch HealthConnectPermissionActivity: ${e.message}")
                        result.error("LAUNCH_ERROR", e.message, null)
                    }
                }
                "openSettings" -> {
                    Log.d(TAG, "openSettings called")
                    try {
                        // 1) Try generic HC settings (A14+)
                        try {
                            Log.d(TAG, "Trying Health Connect settings intent")
                            val i1 = Intent("androidx.health.platform.ACTION_HEALTH_CONNECT_SETTINGS")
                            if (i1.resolveActivity(packageManager) != null) {
                                startActivity(i1)
                                Log.d(TAG, "Health Connect settings opened successfully")
                                result.success(true)
                                return@setMethodCallHandler
                            } else {
                                Log.w(TAG, "Health Connect settings intent cannot be resolved")
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Health Connect settings failed: ${e.message}")
                        }

                        // 2) Try request permissions (lets system resolve)
                        try {
                            Log.d(TAG, "Trying Health Connect permissions intent")
                            val i2 = Intent("androidx.health.ACTION_REQUEST_PERMISSIONS")
                            if (i2.resolveActivity(packageManager) != null) {
                                startActivity(i2)
                                Log.d(TAG, "Health Connect permissions opened successfully")
                                result.success(true)
                                return@setMethodCallHandler
                            } else {
                                Log.w(TAG, "Health Connect permissions intent cannot be resolved")
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Health Connect permissions failed: ${e.message}")
                        }

                        // 3) Try explicit package
                        try {
                            Log.d(TAG, "Trying Health Connect with explicit package")
                            val i3 = Intent("androidx.health.ACTION_REQUEST_PERMISSIONS")
                            i3.setPackage("com.google.android.apps.healthdata")
                            if (isHealthConnectInstalled()) {
                                startActivity(i3)
                                Log.d(TAG, "Health Connect with package opened successfully")
                                result.success(true)
                                return@setMethodCallHandler
                            } else {
                                Log.w(TAG, "Health Connect not installed")
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Health Connect with package failed: ${e.message}")
                        }

                        // 4) Launch HC app
                        try {
                            Log.d(TAG, "Trying to launch Health Connect app directly")
                            val launch = packageManager.getLaunchIntentForPackage("com.google.android.apps.healthdata")
                            if (launch != null) {
                                startActivity(launch)
                                Log.d(TAG, "Health Connect app launched successfully")
                                result.success(true)
                                return@setMethodCallHandler
                            } else {
                                Log.w(TAG, "Health Connect app launch intent not found")
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Health Connect app launch failed: ${e.message}")
                        }

                        // 5) Open app info page for HC
                        try {
                            Log.d(TAG, "Trying to open Health Connect app info")
                            val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            intent.data = android.net.Uri.parse("package:com.google.android.apps.healthdata")
                            startActivity(intent)
                            Log.d(TAG, "Health Connect app info opened successfully")
                            result.success(true)
                            return@setMethodCallHandler
                        } catch (e: Exception) {
                            Log.e(TAG, "Health Connect app info failed: ${e.message}")
                        }

                        // 6) Fallback: Play Store
                        try {
                            Log.d(TAG, "Trying to open Play Store for Health Connect")
                            val store = Intent(Intent.ACTION_VIEW, android.net.Uri.parse("market://details?id=com.google.android.apps.healthdata"))
                            startActivity(store)
                            Log.d(TAG, "Play Store opened successfully")
                            result.success(true)
                            return@setMethodCallHandler
                        } catch (e: Exception) {
                            Log.e(TAG, "Play Store failed: ${e.message}")
                            result.error("SETTINGS_ERROR", "Could not open Health Connect or Play Store: ${e.message}", null)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "openSettings failed: ${e.message}")
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "isInstalled" -> {
                    Log.d(TAG, "isInstalled called")
                    try {
                        val installed = isHealthConnectInstalled()
                        result.success(installed)
                    } catch (e: Exception) {
                        Log.e(TAG, "isInstalled failed: ${e.message}")
                        result.error("CHECK_ERROR", e.message, null)
                    }
                }
                else -> {
                    Log.w(TAG, "Unknown method called: ${call.method}")
                    result.notImplemented()
                }
            }
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
