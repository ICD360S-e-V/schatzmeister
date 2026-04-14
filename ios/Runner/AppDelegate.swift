import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var blurEffectView: UIVisualEffectView?
    private let CHANNEL = "de.icd360sev.schatzmeister/device_integrity"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Setup Platform Channel for device integrity checks
        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(name: CHANNEL, binaryMessenger: controller.binaryMessenger)
            channel.setMethodCallHandler { [weak self] (call, result) in
                if call.method == "checkDeviceIntegrity" {
                    let threat = self?.checkDeviceIntegrity()
                    result(threat)
                } else {
                    result(FlutterMethodNotImplemented)
                }
            }
        }

        // Listen for screenshot notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDidTakeScreenshot),
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Jailbreak detection
    private func checkDeviceIntegrity() -> String? {
        return checkClassicPaths()
            ?? checkRootlessPaths()
            ?? checkSandboxEscape()
            ?? checkForkExecution()
            ?? checkDylibs()
            ?? checkEnvironment()
            ?? checkSymbolicLinks()
    }

    private func checkClassicPaths() -> String? {
        let paths = [
            "/Applications/Cydia.app", "/Applications/Sileo.app", "/Applications/Zebra.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash", "/usr/sbin/sshd", "/usr/bin/ssh",
            "/etc/apt", "/private/var/lib/apt/", "/private/var/lib/cydia",
        ]
        let fm = FileManager.default
        for path in paths {
            if fm.fileExists(atPath: path) { return "Jailbreak erkannt" }
        }
        return nil
    }

    private func checkRootlessPaths() -> String? {
        let paths = [
            "/var/jb", "/var/jb/usr/bin/su", "/var/jb/basebin/",
            "/var/jb/Applications/Sileo.app", "/var/jb/usr/lib/TweakInject/",
            "/var/mobile/Library/Preferences/com.opa334.dopamine.plist",
            "/cores/binpack/", "/cores/binpack/usr/bin/su",
            "/var/mobile/Library/Preferences/com.opa334.TrollStore.plist",
        ]
        let fm = FileManager.default
        for path in paths {
            if fm.fileExists(atPath: path) { return "Jailbreak erkannt (rootless)" }
        }
        if let preboot = try? FileManager.default.contentsOfDirectory(atPath: "/private/preboot") {
            for item in preboot {
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: "/private/preboot/\(item)") {
                    for sub in contents {
                        if sub.hasPrefix("jb-") || sub == "procursus" || sub == "palera1n" {
                            return "Jailbreak erkannt (preboot)"
                        }
                    }
                }
            }
        }
        return nil
    }

    private func checkSandboxEscape() -> String? {
        let testPath = "/private/jb_test_\(Int(Date().timeIntervalSince1970))"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return "Sandbox-Escape erkannt"
        } catch {}
        if let fstab = try? String(contentsOfFile: "/etc/fstab", encoding: .utf8), !fstab.isEmpty {
            return "Jailbreak erkannt (fstab)"
        }
        return nil
    }

    private func checkForkExecution() -> String? {
        let pid = fork()
        if pid >= 0 {
            if pid > 0 { kill(pid, SIGTERM) }
            return "Jailbreak erkannt (fork)"
        }
        return nil
    }

    private func checkDylibs() -> String? {
        let suspiciousLibs = [
            "MobileSubstrate", "SubstrateLoader", "CydiaSubstrate",
            "TweakInject", "ElleKit", "libellekit", "substitute",
            "libhooker", "frida", "FridaGadget", "libgadget", "cycript",
        ]
        let imageCount = _dyld_image_count()
        for i in 0..<imageCount {
            if let imageName = _dyld_get_image_name(i) {
                let name = String(cString: imageName)
                for suspicious in suspiciousLibs {
                    if name.lowercased().contains(suspicious.lowercased()) {
                        return "Hooking-Framework erkannt (\(suspicious))"
                    }
                }
            }
        }
        if let _ = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "MSHookFunction") {
            return "Hooking-Framework erkannt (Substrate)"
        }
        return nil
    }

    private func checkEnvironment() -> String? {
        let suspiciousVars = ["DYLD_INSERT_LIBRARIES", "_MSSafeMode", "SUBSTRATE_DYLIB"]
        for varName in suspiciousVars {
            if let _ = getenv(varName) { return "Hooking-Framework erkannt (\(varName))" }
        }
        return nil
    }

    private func checkSymbolicLinks() -> String? {
        let symlinkPaths = ["/var/lib/undecimus/apt", "/Applications", "/Library/Ringtones"]
        let fm = FileManager.default
        for path in symlinkPaths {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: path, isDirectory: &isDir) {
                if let attrs = try? fm.attributesOfItem(atPath: path),
                   let type = attrs[.type] as? FileAttributeType,
                   type == .typeSymbolicLink {
                    return "Jailbreak erkannt (Symlink)"
                }
            }
        }
        return nil
    }

    // Screenshot protection
    override func applicationWillResignActive(_ application: UIApplication) {
        addBlurEffect()
        super.applicationWillResignActive(application)
    }

    override func applicationDidBecomeActive(_ application: UIApplication) {
        removeBlurEffect()
        super.applicationDidBecomeActive(application)
    }

    @objc private func userDidTakeScreenshot() {
        print("Screenshot detected - content may be protected")
    }

    private func addBlurEffect() {
        guard blurEffectView == nil, let window = self.window else { return }
        let blurEffect = UIBlurEffect(style: .light)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = window.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.tag = 999
        window.addSubview(blurView)
        blurEffectView = blurView
    }

    private func removeBlurEffect() {
        blurEffectView?.removeFromSuperview()
        blurEffectView = nil
    }
}
