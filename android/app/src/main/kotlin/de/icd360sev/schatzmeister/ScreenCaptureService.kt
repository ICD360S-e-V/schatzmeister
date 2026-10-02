package de.icd360sev.schatzmeister

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * Fernwartung: Vordergrunddienst vom Typ mediaProjection — uebernommen aus der
 * Mitglieder-App und um den Ausschalter erweitert.
 *
 * Er traegt die Aufnahme, solange die App NICHT vorne ist: Android 10+ beendet
 * sie ohne ihn, sobald die App in den Hintergrund geht, und Android 14+ gibt
 * ohne ihn gar keine MediaProjection heraus. Geholfen wird aber meistens in
 * ANDEREN Apps — genau dann muss die Sitzung weiterlaufen.
 *
 * Seine Benachrichtigung ist deshalb mehr als ein Hinweis: ein Tipp holt die
 * App nach vorne, „Beenden" beendet die Sitzung von ueberall, ohne die App zu
 * oeffnen. Ohne das liesse sich eine Sitzung aus einer fremden App heraus nur
 * ueber den Umweg zurueck in diese App stoppen.
 *
 * Laeuft nur fuer die Dauer einer zugestimmten Sitzung (Start und Stopp aus
 * Dart, RemoteAgentService).
 */
class ScreenCaptureService : Service() {
    companion object {
        const val TAG = "ScreenCaptureService"
        const val CHANNEL_ID = "fernwartung_bildschirm"
        const val NOTIF_ID = 4712
        const val AKTION_BEENDEN = "de.icd360sev.schatzmeister.FERNWARTUNG_BEENDEN"
        const val EXTRA_TITEL = "titel"
        const val EXTRA_TEXT = "text"
        const val EXTRA_STOPP = "stopp"

        /**
         * Laeuft, wenn in der Benachrichtigung „Beenden" getippt wird. Gesetzt
         * von MainActivity: die Sitzung lebt in Dart, beendet wird sie dort —
         * dieser Dienst allein wuesste nichts von Peer-Verbindung und Vorsitz.
         */
        @Volatile
        var beiStopp: (() -> Unit)? = null
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == AKTION_BEENDEN) {
            Log.d(TAG, "Beenden in der Benachrichtigung getippt")
            val rueckruf = beiStopp
            // Ohne Dart (Engine schon weg) gibt es auch keine Sitzung mehr —
            // dann bleibt nur, den Dienst selbst zu beenden.
            if (rueckruf != null) rueckruf() else stopSelf()
            return START_NOT_STICKY
        }

        createChannel()
        val titel = intent?.getStringExtra(EXTRA_TITEL) ?: "Fernwartung aktiv"
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: "Ihr Bildschirm wird geteilt."
        val stopp = intent?.getStringExtra(EXTRA_STOPP) ?: "Beenden"
        val notification = baueBenachrichtigung(titel, text, stopp)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // ⚠️ `microphone` nur, wenn RECORD_AUDIO JETZT erteilt ist: ab
            // Android 14 wirft startForeground sonst eine SecurityException —
            // und die App waere weg statt nur ohne Ton. Ohne den Typ schneidet
            // Android den Ton im Hintergrund ab; deshalb fragt Dart das
            // Mikrofon VOR diesem Dienst ab.
            var typ = ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            val mitTon = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
                checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
            if (mitTon) typ = typ or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            try {
                startForeground(NOTIF_ID, notification, typ)
            } catch (e: Exception) {
                Log.w(TAG, "startForeground(typ=$typ) abgelehnt: ${e.message} — ohne Mikrofon")
                try {
                    startForeground(
                        NOTIF_ID, notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                    )
                } catch (e2: Exception) {
                    Log.e(TAG, "Vordergrunddienst nicht startbar: ${e2.message}")
                    stopSelf()
                }
            }
        } else {
            startForeground(NOTIF_ID, notification)
        }
        return START_NOT_STICKY
    }

    private fun baueBenachrichtigung(titel: String, text: String, stopp: String): Notification {
        // Tipp auf die Benachrichtigung = wie auf das App-Symbol: die laufende
        // App kommt nach vorne, es entsteht keine zweite.
        val oeffnen = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java)
                .setAction(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_LAUNCHER)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val beenden = PendingIntent.getService(
            this, 1,
            Intent(this, ScreenCaptureService::class.java).setAction(AKTION_BEENDEN),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle(titel)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setContentIntent(oeffnen)
            .addAction(
                Notification.Action.Builder(
                    Icon.createWithResource(this, android.R.drawable.ic_menu_close_clear_cancel),
                    stopp,
                    beenden
                ).build()
            )
            .build()
    }

    override fun onDestroy() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                // LOW: keine Toene, kein Aufpoppen — die Leiste steht trotzdem
                // dauerhaft oben, solange die Sitzung laeuft.
                val ch = NotificationChannel(
                    CHANNEL_ID, "Fernwartung", NotificationManager.IMPORTANCE_LOW
                )
                ch.setShowBadge(false)
                nm.createNotificationChannel(ch)
            }
        }
    }
}
