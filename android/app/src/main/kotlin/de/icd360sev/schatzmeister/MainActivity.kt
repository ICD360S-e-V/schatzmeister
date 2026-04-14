package de.icd360sev.schatzmeister

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Prevent screenshots and screen recording
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
