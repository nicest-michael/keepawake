import Cocoa
import IOKit.pwr_mgt

let helperPath  = "/usr/local/bin/keepawake-helper"
let sudoersPath = "/etc/sudoers.d/keepawake"

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var isActive   = false
    var toggleItem: NSMenuItem!

    var assertSystemSleep:  IOPMAssertionID = 0
    var assertDisplaySleep: IOPMAssertionID = 0
    var assertIdleSleep:    IOPMAssertionID = 0

    var savedLockOn    = "1"
    var savedLockDelay = "5"

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        toggleItem = NSMenuItem(title: "Prevent Sleep", action: #selector(toggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
        updateUI()

        // Install helper silently on first run (one-time admin prompt)
        if !helperInstalled() { installHelper() }
    }

    // MARK: - Toggle

    @objc func toggle() {
        isActive ? stopKeepAwake() : startKeepAwake()
        isActive.toggle()
        updateUI()
    }

    func startKeepAwake() {
        runHelper("enable")

        let name = "KeepAwake" as CFString
        let on   = IOPMAssertionLevel(kIOPMAssertionLevelOn)
        IOPMAssertionCreateWithName(kIOPMAssertionTypePreventSystemSleep as CFString,          on, name, &assertSystemSleep)
        IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString, on, name, &assertDisplaySleep)
        IOPMAssertionCreateWithName(kIOPMAssertionTypeNoIdleSleep as CFString,                on, name, &assertIdleSleep)

        savedLockOn    = shell("/usr/bin/defaults", ["read", "com.apple.screensaver", "askForPassword"])
        savedLockDelay = shell("/usr/bin/defaults", ["read", "com.apple.screensaver", "askForPasswordDelay"])
        if savedLockOn.isEmpty    { savedLockOn    = "1" }
        if savedLockDelay.isEmpty { savedLockDelay = "5" }
        shell("/usr/bin/defaults", ["write", "com.apple.screensaver", "askForPassword",      "-int", "0"])
        shell("/usr/bin/defaults", ["write", "com.apple.screensaver", "askForPasswordDelay", "-int", "86400"])
        shell("/usr/bin/killall",  ["cfprefsd"])
    }

    func stopKeepAwake() {
        runHelper("disable")

        if assertSystemSleep  != 0 { IOPMAssertionRelease(assertSystemSleep);  assertSystemSleep  = 0 }
        if assertDisplaySleep != 0 { IOPMAssertionRelease(assertDisplaySleep); assertDisplaySleep = 0 }
        if assertIdleSleep    != 0 { IOPMAssertionRelease(assertIdleSleep);    assertIdleSleep    = 0 }

        shell("/usr/bin/defaults", ["write", "com.apple.screensaver", "askForPassword",      "-int", savedLockOn])
        shell("/usr/bin/defaults", ["write", "com.apple.screensaver", "askForPasswordDelay", "-int", savedLockDelay])
        shell("/usr/bin/killall",  ["cfprefsd"])
    }

    // MARK: - Privileged helper

    func helperInstalled() -> Bool {
        FileManager.default.fileExists(atPath: sudoersPath)
    }

    func installHelper() {
        let username = shell("/usr/bin/whoami")

        // Write the helper script content (shell, no quotes needed inside)
        let helperScript = [
            "#!/bin/bash",
            "case \"$1\" in",
            "  enable)",
            "    /usr/bin/pmset -a disablesleep 1",
            "    /usr/bin/defaults write /Library/Preferences/com.apple.screensaver askForPassword -int 0",
            "    ;;",
            "  disable)",
            "    /usr/bin/pmset -a disablesleep 0",
            "    /usr/bin/defaults delete /Library/Preferences/com.apple.screensaver askForPassword 2>/dev/null || true",
            "    ;;",
            "esac",
        ].joined(separator: "\n")

        // Write setup script to /tmp (no admin needed for /tmp)
        let tmpSetup = "/tmp/keepawake_install.sh"
        try? helperScript.write(toFile: "/tmp/keepawake_helper_content.sh",
                                atomically: true, encoding: .utf8)

        // Build and write the install script to /tmp
        let installScript = """
#!/bin/bash
cp /tmp/keepawake_helper_content.sh \(helperPath)
chmod 755 \(helperPath)
printf '\(username) ALL=(ALL) NOPASSWD: \(helperPath)\\n' > \(sudoersPath)
chmod 440 \(sudoersPath)
"""
        try? installScript.write(toFile: tmpSetup, atomically: true, encoding: .utf8)
        shell("/bin/chmod", ["755", tmpSetup])

        // One-time admin prompt to install
        sudo("bash \(tmpSetup)")

        // Cleanup temp files
        try? FileManager.default.removeItem(atPath: tmpSetup)
        try? FileManager.default.removeItem(atPath: "/tmp/keepawake_helper_content.sh")
    }

    func runHelper(_ arg: String) {
        // Runs without password after installHelper() has been called once
        shell("/usr/bin/sudo", [helperPath, arg])
    }

    // MARK: - Helpers

    @discardableResult
    func shell(_ path: String, _ args: [String] = []) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError  = Pipe()
        try? p.run(); p.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    @discardableResult
    func sudo(_ command: String) -> Bool {
        let safe = command.replacingOccurrences(of: "\\", with: "\\\\")
                          .replacingOccurrences(of: "\"", with: "\\\"")
        let src  = "do shell script \"\(safe)\" with administrator privileges"
        var err: NSDictionary?
        NSAppleScript(source: src)?.executeAndReturnError(&err)
        return err == nil
    }

    // MARK: - UI

    func updateUI() {
        if let btn = statusItem.button {
            btn.title   = isActive ? "☕" : "💤"
            btn.toolTip = isActive ? "KeepAwake ON" : "KeepAwake OFF"
        }
        toggleItem.title = isActive ? "✓ Active — allow sleep" : "Prevent Sleep"
    }

    @objc func quit() {
        if isActive { stopKeepAwake() }
        NSApplication.shared.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if isActive { stopKeepAwake() }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
