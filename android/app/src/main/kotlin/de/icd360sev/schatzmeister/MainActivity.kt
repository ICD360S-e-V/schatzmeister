package de.icd360sev.schatzmeister

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.net.Socket

class MainActivity : FlutterActivity() {
    private val BATTERY_CHANNEL = "de.icd360sev.schatzmeister/battery"
    private val INTEGRITY_CHANNEL = "de.icd360sev.schatzmeister/device_integrity"

    companion object {
        const val TAG = "MainActivity"

        // Fernwartung — eigene Kanalnamen, nicht die der Mitglieder-App.
        const val SECURE_CHANNEL = "de.icd360sev.schatzmeister/secure_screen"
        const val CAPTURE_CHANNEL = "de.icd360sev.schatzmeister/screen_capture"
        const val STEUERUNG_CHANNEL = "de.icd360sev.schatzmeister/fernsteuerung"

        /**
         * Laeuft gerade eine Fernwartung, in der der Bildschirm geteilt wird?
         *
         * ⚠️ MUSS die Activity ueberleben: `onCreate` setzt FLAG_SECURE und
         * laeuft bei jeder Neuerzeugung erneut. Mitten in einer Sitzung setzte
         * das die Sperre wieder, und die App wurde im geteilten Bild SCHWARZ —
         * in der Mitglieder-App so geschehen, ohne jede Fehlermeldung.
         */
        @Volatile
        var fernwartungLaeuft: Boolean = false
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Prevent screenshots and screen recording — ausser waehrend einer
        // zugestimmten Fernwartung (siehe [fernwartungLaeuft]).
        if (!fernwartungLaeuft) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE
            )
        } else {
            Log.d(TAG, "FLAG_SECURE NICHT gesetzt — Fernwartung laeuft")
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // Ohne Engine gibt es niemanden mehr, der eine Sitzung beenden koennte;
        // der Dienst beendet sich dann selbst (siehe ScreenCaptureService).
        ScreenCaptureService.beiStopp = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Jede Kopie: sensibel markiert, nach 30 s geloescht, und die App
        // sagt es. Siehe [Zwischenablage].
        Zwischenablage.anbinden(this, flutterEngine)

        // Battery optimization channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isBatteryOptimizationDisabled" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(packageName))
                }
                "requestDisableBatteryOptimization" -> {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Device integrity channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INTEGRITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkDeviceIntegrity" -> {
                    val threat = checkDeviceIntegrity()
                    result.success(threat)
                }
                else -> result.notImplemented()
            }
        }

        fernwartungKanaele(flutterEngine)
    }

    /**
     * Fernwartung: FLAG_SECURE, Vordergrunddienst und Fernsteuerung —
     * uebernommen aus der Mitglieder-App.
     */
    private fun fernwartungKanaele(flutterEngine: FlutterEngine) {
        val boten = flutterEngine.dartExecutor.binaryMessenger

        // FLAG_SECURE nur waehrend einer zugestimmten Sitzung aufheben.
        MethodChannel(boten, SECURE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecure" -> {
                    val secure = call.argument<Boolean>("secure") ?: true
                    fernwartungLaeuft = !secure
                    // ⚠️ Die Antwort kommt AUS dem UI-Thread: `await
                    // setSecure(false)` soll heissen „ist aus", nicht
                    // „wird gleich aus sein".
                    runOnUiThread {
                        if (secure) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        val jetzt = (window.attributes.flags and
                            WindowManager.LayoutParams.FLAG_SECURE) != 0
                        Log.d(TAG, "FLAG_SECURE angefordert=$secure, tatsaechlich=$jetzt")
                        result.success(jetzt)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Vordergrunddienst um die Aufnahme. Er traegt die Sitzung, wenn die
        // App im Hintergrund ist — dort wird meistens geholfen.
        val aufnahme = MethodChannel(boten, CAPTURE_CHANNEL)
        aufnahme.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    // „Beenden" in der Benachrichtigung landet in Dart, wo die
                    // Sitzung lebt. onStartCommand laeuft schon im
                    // Hauptthread — direkt aufrufen, ohne die Activity
                    // festzuhalten.
                    ScreenCaptureService.beiStopp = {
                        aufnahme.invokeMethod("stoppGetippt", null)
                    }
                    val i = Intent(this, ScreenCaptureService::class.java)
                        .putExtra(ScreenCaptureService.EXTRA_TITEL, call.argument<String>("titel"))
                        .putExtra(ScreenCaptureService.EXTRA_TEXT, call.argument<String>("text"))
                        .putExtra(ScreenCaptureService.EXTRA_STOPP, call.argument<String>("stopp"))
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(i)
                    } else {
                        startService(i)
                    }
                    Log.d(TAG, "ScreenCaptureService gestartet")
                    result.success(null)
                }
                "stop" -> {
                    ScreenCaptureService.beiStopp = null
                    stopService(Intent(this, ScreenCaptureService::class.java))
                    Log.d(TAG, "ScreenCaptureService gestoppt")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Fernsteuerung ueber den AccessibilityService.
        MethodChannel(boten, STEUERUNG_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // Grundwahrheit: der Dienst setzt seine Instanz, sobald das
                // System ihn verbunden hat.
                "verfuegbar" -> result.success(FernwartungService.instanz != null)

                // Zweites Schloss — nur fuer die Dauer einer zugestimmten Sitzung.
                "freigeben" -> {
                    FernwartungService.freigegeben = call.argument<Boolean>("frei") ?: false
                    Log.d(TAG, "Fernsteuerung freigegeben=${FernwartungService.freigegeben}")
                    result.success(null)
                }

                "zug" -> {
                    val d = FernwartungService.instanz
                    if (d == null) {
                        result.success(false)
                    } else {
                        result.success(
                            d.zug(
                                call.argument<Double>("x1") ?: 0.0,
                                call.argument<Double>("y1") ?: 0.0,
                                call.argument<Double>("x2") ?: 0.0,
                                call.argument<Double>("y2") ?: 0.0,
                                (call.argument<Number>("ms") ?: 60).toLong()
                            )
                        )
                    }
                }

                "aktion" -> {
                    val d = FernwartungService.instanz
                    result.success(d?.globaleAktion(call.argument<String>("name") ?: "") ?: false)
                }

                // Eine App kann sich diese Berechtigung nicht selbst erteilen —
                // nur die Systemseite oeffnen.
                "einstellungenOeffnen" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        Log.w(TAG, "Bedienungshilfen nicht zu oeffnen: ${e.message}")
                        result.success(false)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun checkDeviceIntegrity(): String? {
        return checkSuBinaries()
            ?: checkRootManagers()
            ?: checkKernelSU()
            ?: checkAPatch()
            ?: checkHookingFrameworks()
            ?: checkBuildProperties()
            ?: checkSELinux()
            ?: checkMountInfo()
            ?: checkProcMaps()
            ?: checkFrida()
            ?: checkEmulator()
    }

    private fun checkSuBinaries(): String? {
        val paths = arrayOf(
            "/system/bin/su", "/system/xbin/su", "/sbin/su",
            "/data/local/xbin/su", "/data/local/bin/su", "/data/local/su",
            "/system/sd/xbin/su", "/system/bin/failsafe/su", "/su/bin/su",
            "/vendor/bin/su", "/product/bin/su", "/system_ext/bin/su",
            "/odm/bin/su", "/apex/com.android.runtime/bin/su"
        )
        for (path in paths) {
            if (File(path).exists()) return "Root-Zugriff erkannt (su)"
        }
        try {
            val process = Runtime.getRuntime().exec(arrayOf("which", "su"))
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val line = reader.readLine()
            process.waitFor()
            if (!line.isNullOrEmpty()) return "Root-Zugriff erkannt (su in PATH)"
        } catch (_: Exception) {}
        return null
    }

    private fun checkRootManagers(): String? {
        val paths = arrayOf(
            "/system/app/Superuser.apk", "/system/app/SuperSU.apk",
            "/data/data/eu.chainfire.supersu", "/data/data/com.topjohnwu.magisk",
            "/data/user/0/com.topjohnwu.magisk", "/data/data/io.github.vvb2060.magisk",
            "/data/adb/magisk", "/data/adb/magisk.db", "/data/adb/magisk/busybox",
            "/sbin/.magisk", "/cache/.disable_magisk", "/data/adb/modules",
            "/data/data/com.amphoras.hidemyroot", "/data/data/com.tsng.hidemyapplist"
        )
        for (path in paths) {
            try { if (File(path).exists()) return "Root-Software erkannt" } catch (_: Exception) {}
        }
        val rootPackages = arrayOf(
            "com.topjohnwu.magisk", "io.github.vvb2060.magisk",
            "eu.chainfire.supersu", "me.weishu.kernelsu", "me.bmax.apatch",
            "de.robv.android.xposed.installer", "org.lsposed.manager"
        )
        val pm = applicationContext.packageManager
        for (pkg in rootPackages) {
            try { pm.getPackageInfo(pkg, 0); return "Root-Software erkannt ($pkg)" } catch (_: Exception) {}
        }
        return null
    }

    private fun checkKernelSU(): String? {
        val paths = arrayOf("/data/adb/ksu", "/data/adb/ksu/modules", "/data/adb/ksud", "/sys/module/kernelsu")
        for (path in paths) {
            try { if (File(path).exists()) return "KernelSU erkannt" } catch (_: Exception) {}
        }
        try {
            val version = File("/proc/version").readText().lowercase()
            if (version.contains("ksu") || version.contains("kernelsu")) return "KernelSU erkannt (Kernel)"
        } catch (_: Exception) {}
        return null
    }

    private fun checkAPatch(): String? {
        val paths = arrayOf("/data/adb/ap", "/data/adb/ap/modules", "/data/adb/apd")
        for (path in paths) {
            try { if (File(path).exists()) return "APatch erkannt" } catch (_: Exception) {}
        }
        return null
    }

    private fun checkHookingFrameworks(): String? {
        val paths = arrayOf(
            "/system/framework/XposedBridge.jar", "/system/bin/app_process.orig",
            "/data/adb/lspd", "/data/adb/modules/zygisk_lsposed"
        )
        for (path in paths) {
            try { if (File(path).exists()) return "Hooking-Framework erkannt" } catch (_: Exception) {}
        }
        val busyboxPaths = arrayOf("/system/xbin/busybox", "/system/bin/busybox", "/sbin/busybox")
        for (path in busyboxPaths) {
            try { if (File(path).exists()) return "Root-Tools erkannt (BusyBox)" } catch (_: Exception) {}
        }
        return null
    }

    private fun checkBuildProperties(): String? {
        try {
            val tags = getProp("ro.build.tags")
            if (tags.contains("test-keys")) return "Unsigniertes System erkannt"
        } catch (_: Exception) {}
        try {
            val debuggable = getProp("ro.debuggable")
            if (debuggable == "1") {
                val buildType = getProp("ro.build.type")
                if (buildType == "userdebug" || buildType == "eng") return "Debug-System erkannt"
            }
        } catch (_: Exception) {}
        try { if (getProp("ro.secure") == "0") return "Unsicheres System erkannt" } catch (_: Exception) {}
        try { if (getProp("service.adb.root") == "1") return "ADB Root erkannt" } catch (_: Exception) {}
        return null
    }

    private fun checkSELinux(): String? {
        try {
            val process = Runtime.getRuntime().exec("getenforce")
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val status = reader.readLine()?.trim()?.lowercase() ?: ""
            process.waitFor()
            if (status == "permissive" || status == "disabled") return "Sicherheitssystem deaktiviert (SELinux)"
        } catch (_: Exception) {}
        return null
    }

    private fun checkMountInfo(): String? {
        try {
            val mounts = File("/proc/self/mounts").readText().lowercase()
            if (mounts.contains("magisk")) return "Root-Zugriff erkannt (Mount)"
            if (mounts.contains("/data/adb/modules")) return "Root-Module erkannt"
        } catch (_: Exception) {}
        try {
            val mountInfo = File("/proc/self/mountinfo").readText().lowercase()
            if (mountInfo.contains("magisk") || mountInfo.contains("ksu") || mountInfo.contains("ap_modules"))
                return "Root-Zugriff erkannt (Overlay)"
        } catch (_: Exception) {}
        return null
    }

    private fun checkProcMaps(): String? {
        try {
            val maps = File("/proc/self/maps").readText().lowercase()
            val suspicious = arrayOf("frida", "gadget", "xposed", "edxp", "lsposed", "substrate")
            for (lib in suspicious) { if (maps.contains(lib)) return "Hooking-Framework erkannt ($lib)" }
        } catch (_: Exception) {}
        try {
            val status = File("/proc/self/status").readText()
            val match = Regex("TracerPid:\\s*(\\d+)").find(status)
            val tracerPid = match?.groupValues?.get(1)?.toIntOrNull() ?: 0
            if (tracerPid != 0) return "Debugger erkannt"
        } catch (_: Exception) {}
        return null
    }

    private fun checkFrida(): String? {
        try {
            val socket = Socket()
            socket.connect(java.net.InetSocketAddress("127.0.0.1", 27042), 500)
            socket.close()
            return "Frida erkannt (Port 27042)"
        } catch (_: Exception) {}
        return null
    }

    private fun checkEmulator(): String? {
        val checks = mapOf(
            "ro.hardware" to arrayOf("goldfish", "ranchu", "vbox86"),
            "ro.product.model" to arrayOf("sdk", "emulator", "android sdk"),
            "ro.kernel.qemu" to arrayOf("1")
        )
        for ((prop, indicators) in checks) {
            try {
                val value = getProp(prop).lowercase()
                for (indicator in indicators) { if (value.contains(indicator)) return "Emulator erkannt" }
            } catch (_: Exception) {}
        }
        val emulatorFiles = arrayOf("/dev/qemu_pipe", "/dev/socket/qemud", "/dev/goldfish_pipe")
        for (path in emulatorFiles) { if (File(path).exists()) return "Emulator erkannt" }
        return null
    }

    private fun getProp(name: String): String {
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("getprop", name))
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val value = reader.readLine()?.trim() ?: ""
            process.waitFor()
            value
        } catch (_: Exception) { "" }
    }
}
