import SwiftUI
import AppKit

let supportDir = "/Library/Application Support/SiteBlocker"
let configPath = supportDir + "/config.txt"
let scriptPath = supportDir + "/siteblocker.sh"
let plistPath = "/Library/LaunchDaemons/com.siteblocker.daemon.plist"

struct Slot: Identifiable {
    let id = UUID()
    var start: Date
    var end: Date
}

final class Model: ObservableObject {
    @Published var enabled = true
    @Published var sites = "linkedin.com\nyoutube.com\nreddit.com\nx.com"
    @Published var always = "tagesschau.de"
    @Published var slots = [Slot(start: Model.time(9, 0), end: Model.time(17, 0))]
    @Published var helperOutdated = false
    @Published var days: Set<Int> = [1, 2, 3, 4, 5]   // 1 = Mon ... 7 = Sun
    @Published var status = ""
    @Published var installed = false

    static func time(_ h: Int, _ m: Int) -> Date {
        Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date())!
    }
    static func hhmm(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour!, c.minute!)
    }
    static func parse(_ s: String) -> Date? {
        let p = s.split(separator: ":").compactMap { Int($0) }
        return p.count == 2 ? time(p[0], p[1]) : nil
    }

    init() { load(); refresh() }

    func refresh() {
        installed = FileManager.default.fileExists(atPath: plistPath)
        if installed, let res = Bundle.main.resourcePath {
            let bundled = try? String(contentsOfFile: res + "/siteblocker.sh", encoding: .utf8)
            let current = try? String(contentsOfFile: scriptPath, encoding: .utf8)
            helperOutdated = bundled != current
        }
        let hosts = (try? String(contentsOfFile: "/etc/hosts", encoding: .utf8)) ?? ""
        let alwaysSet = Set(clean(always).map { $0.hasPrefix("www.") ? String($0.dropFirst(4)) : $0 })
        let scheduled = clean(sites).map { $0.hasPrefix("www.") ? String($0.dropFirst(4)) : $0 }
            .filter { !alwaysSet.contains($0) }
        let blocking = scheduled.contains { hosts.contains("127.0.0.1 \($0)\n") }
        status = !installed ? "Not installed yet. Click Install first."
               : helperOutdated ? "⚠️ This version has new features. Click Update helper (asks for your password once)."
               : blocking ? "🔴 Schedule active: scheduled sites are blocked right now"
               : "🟢 Schedule not active right now (permanent list is always blocked)"
    }

    func load() {
        guard let text = try? String(contentsOfFile: configPath, encoding: .utf8) else { return }
        var single: (Date?, Date?) = (nil, nil)
        var loadedSlots: [Slot] = []
        for line in text.split(separator: "\n") {
            let kv = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard kv.count == 2 else { continue }
            switch kv[0] {
            case "ENABLED": enabled = kv[1] == "1"
            case "START": single.0 = Model.parse(kv[1])
            case "END": single.1 = Model.parse(kv[1])
            case "SLOTS":
                for part in kv[1].split(separator: ",") {
                    let t = part.split(separator: "-").map(String.init)
                    if t.count == 2, let a = Model.parse(t[0]), let b = Model.parse(t[1]) {
                        loadedSlots.append(Slot(start: a, end: b))
                    }
                }
            case "DAYS": days = Set(kv[1].compactMap { Int(String($0)) })
            case "SITES": sites = kv[1].split(separator: " ").joined(separator: "\n")
            case "ALWAYS": always = kv[1].split(separator: " ").joined(separator: "\n")
            default: break
            }
        }
        if loadedSlots.isEmpty, let a = single.0, let b = single.1 { loadedSlots = [Slot(start: a, end: b)] }
        if !loadedSlots.isEmpty { slots = loadedSlots }
    }

    func clean(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == "\n" || $0 == " " || $0 == "," })
            .map { s -> String in
                var x = s.lowercased().trimmingCharacters(in: .whitespaces)
                for p in ["https://", "http://"] where x.hasPrefix(p) { x.removeFirst(p.count) }
                if let slash = x.firstIndex(of: "/") { x = String(x[..<slash]) }
                return x
            }
            .filter { !$0.isEmpty && $0.range(of: "^[a-z0-9-]+(\\.[a-z0-9-]+)+$", options: .regularExpression) != nil }
    }

    var configText: String {
        """
        ENABLED=\(enabled ? 1 : 0)
        SLOTS=\(slots.map { "\(Model.hhmm($0.start))-\(Model.hhmm($0.end))" }.joined(separator: ","))
        START=\(Model.hhmm(slots.first?.start ?? Model.time(0, 0)))
        END=\(Model.hhmm(slots.first?.end ?? Model.time(0, 0)))
        DAYS=\(days.sorted().map(String.init).joined())
        SITES=\(clean(sites).joined(separator: " "))
        ALWAYS=\(clean(always).joined(separator: " "))

        """
    }

    func save() {
        guard installed else { status = "Click Install first."; return }
        do {
            try configText.write(toFile: configPath, atomically: false, encoding: .utf8)
            status = "Saved. Takes effect within a few seconds…"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.refresh() }
        } catch {
            status = "Could not save: \(error.localizedDescription)"
        }
    }

    func runAsAdmin(_ cmd: String) -> Bool {
        let esc = cmd.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        var err: NSDictionary?
        NSAppleScript(source: "do shell script \"\(esc)\" with administrator privileges")?.executeAndReturnError(&err)
        if let err { status = "Cancelled or failed: \(err[NSAppleScript.errorMessage] ?? "")" }
        return err == nil
    }

    func install() {
        guard let res = Bundle.main.resourcePath else { return }
        let tmp = NSTemporaryDirectory() + "siteblocker-config.txt"
        try? configText.write(toFile: tmp, atomically: true, encoding: .utf8)
        let q = { (s: String) in "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let cmd = [
            "mkdir -p \(q(supportDir))",
            "cp \(q(res + "/siteblocker.sh")) \(q(scriptPath))",
            "chown root:wheel \(q(scriptPath)) && chmod 755 \(q(scriptPath))",
            "[ -f \(q(configPath)) ] || cp \(q(tmp)) \(q(configPath))",
            "chmod 666 \(q(configPath))",
            "cp \(q(res + "/com.siteblocker.daemon.plist")) \(q(plistPath))",
            "chown root:wheel \(q(plistPath)) && chmod 644 \(q(plistPath))",
            "launchctl bootout system/com.siteblocker.daemon 2>/dev/null; launchctl bootstrap system \(q(plistPath))",
        ].joined(separator: "; ")
        if runAsAdmin(cmd) { refresh(); save() }
    }

    func uninstall() {
        let cmd = [
            "launchctl bootout system/com.siteblocker.daemon 2>/dev/null",
            "rm -f '\(plistPath)'",
            "sed -i '' '/^# >>> SiteBlocker >>>$/,/^# <<< SiteBlocker <<<$/d' /etc/hosts",
            "dscacheutil -flushcache; killall -HUP mDNSResponder",
            "rm -rf '\(supportDir)'",
        ].joined(separator: "; ")
        if runAsAdmin(cmd) { refresh() }
    }
}

struct ContentView: View {
    @StateObject var m = Model()
    let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Oh no, distractions").font(.largeTitle.bold()).shadow(color: .white, radius: 4)
            Toggle("Schedule on (permanent list stays blocked either way)", isOn: $m.enabled)

            Text("Always blocked (one per line)").font(.headline)
            TextEditor(text: $m.always)
                .font(.system(.body, design: .monospaced))
                .frame(height: 70)
                .scrollContentBackground(.hidden)
                .padding(4)
                .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.25)))

            Text("Blocked on a schedule (one per line)").font(.headline)
            TextEditor(text: $m.sites)
                .font(.system(.body, design: .monospaced))
                .frame(height: 110)
                .scrollContentBackground(.hidden)
                .padding(4)
                .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.25)))

            Text("When").font(.headline)
            ForEach($m.slots) { $slot in
                HStack {
                    DatePicker("From", selection: $slot.start, displayedComponents: .hourAndMinute)
                    DatePicker("to", selection: $slot.end, displayedComponents: .hourAndMinute)
                    Button {
                        m.slots.removeAll { $0.id == slot.id }
                    } label: { Image(systemName: "minus.circle") }
                    .buttonStyle(.borderless)
                    .disabled(m.slots.count <= 1)
                    .help("Remove this time slot")
                }
            }
            Button {
                m.slots.append(Slot(start: Model.time(15, 0), end: Model.time(17, 0)))
            } label: { Label("Add time slot", systemImage: "plus.circle") }
            .buttonStyle(.borderless)
            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { d in
                    Toggle(dayNames[d - 1], isOn: Binding(
                        get: { m.days.contains(d) },
                        set: { if $0 { m.days.insert(d) } else { m.days.remove(d) } }))
                    .toggleStyle(.button)
                }
            }
            Text("Overnight works too, e.g. 22:00 to 06:00.").font(.caption.weight(.medium)).foregroundStyle(.black.opacity(0.7))

            Divider()
            Text(m.status).font(.callout.weight(.medium))
            HStack {
                if m.installed {
                    if m.helperOutdated {
                        Button("Update helper") { m.install() }.keyboardShortcut(.defaultAction)
                    } else {
                        Button("Save") { m.save() }.keyboardShortcut(.defaultAction)
                    }
                    Button("Refresh status") { m.refresh() }
                    Spacer()
                    Button("Uninstall", role: .destructive) { m.uninstall() }
                } else {
                    Button("Install (asks for your Mac password once)") { m.install() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 600)
        .frame(minHeight: 710)
        .background {
            ZStack {
                if let path = Bundle.main.path(forResource: "background", ofType: "png"),
                   let img = NSImage(contentsOfFile: path) {
                    Image(nsImage: img).resizable().scaledToFill()
                }
                // light wash so the comic shows through but the text stays readable
                Color.white.opacity(0.55)
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.light)
    }
}

@main
struct TouchGrassApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }.windowResizability(.contentSize)
    }
}
