package com.colourswift.safehaven

import android.content.Intent
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
}