package com.colourswift.safehaven

import android.app.*
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import java.io.File
import java.net.URL
import android.content.pm.PackageInstaller

class UpdateForegroundService : Service() {
    private val CHANNEL_ID = "safehaven_update_channel"
    private val NOTIFICATION_ID = 888
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Updating Apps")
            .setContentText("SafeHaven is downloading updates in the background...")
            .setSmallIcon(R.drawable.ic_notification_safehaven)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()

        startForeground(NOTIFICATION_ID, notification)

        @Suppress("DEPRECATION")
        val updates: ArrayList<HashMap<String, String>>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent?.getSerializableExtra("updates", ArrayList::class.java) as? ArrayList<HashMap<String, String>>
        } else {
            intent?.getSerializableExtra("updates") as? ArrayList<HashMap<String, String>>
        }

        if (updates.isNullOrEmpty()) {
            stopSelf(startId)
            return START_NOT_STICKY
        }

        scope.launch {
            for (update in updates) {
                val packageName = update["packageName"] ?: continue
                val downloadUrl = update["downloadUrl"] ?: continue
                processUpdate(packageName, downloadUrl)
            }
            stopSelf(startId)
        }

        return START_NOT_STICKY
    }

    private suspend fun processUpdate(packageName: String, downloadUrl: String) {
        val file = File(cacheDir, "${packageName}_update.apk")
        try {
            URL(downloadUrl).openStream().use { input ->
                file.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            installApk(packageName, file)
        } catch (_: Exception) {
        } finally {
            file.delete()
        }
    }

    private fun installApk(packageName: String, file: File) {
        val packageInstaller = packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
        }

        val sessionId = packageInstaller.createSession(params)
        val session = packageInstaller.openSession(sessionId)

        try {
            file.inputStream().use { input ->
                session.openWrite("package_install_session", 0, file.length()).use { output ->
                    input.copyTo(output)
                    session.fsync(output)
                }
            }

            val intent = Intent(this, UpdateReceiver::class.java).apply {
                putExtra(PackageInstaller.EXTRA_PACKAGE_NAME, packageName)
            }
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                sessionId,
                intent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
            )

            session.commit(pendingIntent.intentSender)
        } finally {
            session.close()
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Safe Haven Update Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}