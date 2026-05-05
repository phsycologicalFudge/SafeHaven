package com.colourswift.safehaven

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "safehaven/installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("path")

                    if (path.isNullOrBlank()) {
                        result.error("invalid_path", "APK path is missing", null)
                        return@setMethodCallHandler
                    }

                    installApk(path, result)
                }

                "getPackageState" -> {
                    val targetPackage = call.argument<String>("packageName")

                    if (targetPackage.isNullOrBlank()) {
                        result.error("invalid_package", "Package name is missing", null)
                        return@setMethodCallHandler
                    }

                    getPackageState(targetPackage, result)
                }

                "openApp" -> {
                    val targetPackage = call.argument<String>("packageName")

                    if (targetPackage.isNullOrBlank()) {
                        result.error("invalid_package", "Package name is missing", null)
                        return@setMethodCallHandler
                    }

                    openApp(targetPackage, result)
                }

                "uninstallApp" -> {
                    val targetPackage = call.argument<String>("packageName")

                    if (targetPackage.isNullOrBlank()) {
                        result.error("invalid_package", "Package name is missing", null)
                        return@setMethodCallHandler
                    }

                    uninstallApp(targetPackage, result)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun installApk(path: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            val settingsIntent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName")
            )

            settingsIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(settingsIntent)

            result.error(
                "install_permission_required",
                "Install permission is required",
                null
            )
            return
        }

        val file = File(path)

        if (!file.exists()) {
            result.error("file_missing", "APK file does not exist", null)
            return
        }

        val apkUri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file
        )

        val installIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        startActivity(installIntent)
        result.success(true)
    }

    private fun getPackageState(targetPackage: String, result: MethodChannel.Result) {
        try {
            val info = packageManager.getPackageInfo(targetPackage, 0)
            val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                info.versionCode.toLong()
            }

            result.success(
                mapOf(
                    "installed" to true,
                    "versionCode" to versionCode
                )
            )
        } catch (_: PackageManager.NameNotFoundException) {
            result.success(
                mapOf(
                    "installed" to false,
                    "versionCode" to 0L
                )
            )
        } catch (_: SecurityException) {
            result.success(
                mapOf(
                    "installed" to false,
                    "versionCode" to 0L
                )
            )
        }
    }

    private fun openApp(targetPackage: String, result: MethodChannel.Result) {
        val launchIntent = packageManager.getLaunchIntentForPackage(targetPackage)

        if (launchIntent == null) {
            result.error("app_not_found", "App cannot be opened", null)
            return
        }

        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(launchIntent)
        result.success(true)
    }

    private fun uninstallApp(targetPackage: String, result: MethodChannel.Result) {
        try {
            val uninstallIntent = Intent(Intent.ACTION_DELETE).apply {
                data = Uri.fromParts("package", targetPackage, null)
            }

            startActivity(uninstallIntent)
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            try {
                val settingsIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", targetPackage, null)
                }

                startActivity(settingsIntent)
                result.success(true)
            } catch (settingsError: Exception) {
                result.error("uninstall_unavailable", settingsError.message, null)
            }
        } catch (e: Exception) {
            result.error("uninstall_failed", e.message, null)
        }
    }
}
