import AppKit
import Darwin

/// Percebe quando um app da suíte ArtCraft (bundle id "ai.storyteller.*") abre ou fecha.
/// O ArtCraft Launcher não conta: ele só instala/atualiza os apps e não usa fontes.
///
/// Por que dois mecanismos? Os apps da ArtCraft leem as fontes ~0,5 s depois de abrir, e o aviso do macOS
/// ("willLaunch") só chega ~0,6 s depois do início do app — tarde demais. Por isso há uma vigia rápida da lista
/// de processos (25 ms) que percebe o app no instante em que ele nasce; as notificações ficam como reforço
/// (e para detectar o fechamento).
@MainActor
final class ArtCraftWatcher {
    static let bundlePrefix = "ai.storyteller."
    static let ignored: Set<String> = ["ai.storyteller.artcraft-launcher"]
    /// Apps da mesma família que não usam o prefixo acima, mas também só leem pastas de fontes (o TraceDraw varre
    /// /Library/Fonts, ~/Library/Fonts e /System/Library/Fonts, sem passar pelo CoreText).
    static let extraBundleIDs: Set<String> = ["dev.tracedraw.app"]

    /// Esse bundle id é de um app que precisa das fontes em pasta?
    nonisolated static func matches(bundleID: String) -> Bool {
        if ignored.contains(bundleID) { return false }
        return bundleID.hasPrefix(bundlePrefix) || extraBundleIDs.contains(bundleID)
    }

    /// Chamado sempre que a lista de apps ArtCraft abertos muda (nomes ordenados; vazio = nenhum).
    var onChange: (([String]) -> Void)?

    private var observers: [NSObjectProtocol] = []
    private var terminateCheck: Task<Void, Never>?
    private let poller = FastProcessPoller()
    private var fastApps: [pid_t: String] = [:]
    private(set) var runningNames: [String] = []

    static func isArtCraft(_ bundleID: String?) -> Bool {
        guard let id = bundleID else { return false }
        return matches(bundleID: id)
    }

    static func currentlyRunning() -> [String] {
        NSWorkspace.shared.runningApplications
            .filter { isArtCraft($0.bundleIdentifier) }
            .compactMap { $0.localizedName ?? $0.bundleIdentifier }
            .sorted()
    }

    func start() {
        runningNames = currentNames()
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard Self.isArtCraft(app?.bundleIdentifier) else { return }
            MainActor.assumeIsolated { self?.scheduleRefreshAfterTerminate() }
        })
        poller.onLaunch = { [weak self] pid, name in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.fastLaunch(pid: pid, name: name) } }
        }
    }

    /// A vigia rápida só precisa rodar no modo Automático (custa ~1% de CPU).
    func setFastPolling(_ enabled: Bool) {
        if enabled { poller.start() } else { poller.stop() }
    }

    /// Nomes dos apps abertos: o que o macOS informa + o que a vigia rápida viu (e ainda está vivo).
    private func currentNames() -> [String] {
        fastApps = fastApps.filter { kill($0.key, 0) == 0 }
        return Array(Set(Self.currentlyRunning() + fastApps.values)).sorted()
    }

    private func fastLaunch(pid: pid_t, name: String) {
        fastApps[pid] = name
        publish(currentNames())
    }

    private func refresh() { publish(currentNames()) }

    private func publish(_ names: [String]) {
        guard names != runningNames else { return }
        runningNames = names
        onChange?(names)
    }

    /// Espera alguns segundos antes de concluir que fechou (evita vai-e-vem ao trocar de um app para outro).
    private func scheduleRefreshAfterTerminate() {
        terminateCheck?.cancel()
        terminateCheck = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }
}

/// Olha a lista de processos a cada 25 ms e avisa quando nasce um app da ArtCraft.
/// Só trabalha de verdade com PIDs novos (lê o caminho do executável e o bundle id, com cache).
final class FastProcessPoller: @unchecked Sendable {
    var onLaunch: ((pid_t, String) -> Void)?

    private let queue = DispatchQueue(label: "br.com.criativecom.tipoteca.process-poll", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var known = Set<pid_t>()
    private var recheck: [pid_t: Int] = [:]
    private var bundleCache: [String: String?] = [:]

    func stop() {
        queue.async { [self] in
            timer?.cancel()
            timer = nil
            recheck.removeAll()
        }
    }

    func start() {
        queue.async { [self] in
            guard timer == nil else { return }
            known = currentPids()
            let t = DispatchSource.makeTimerSource(queue: queue)
            t.schedule(deadline: .now() + .milliseconds(25), repeating: .milliseconds(25), leeway: .milliseconds(5))
            t.setEventHandler { [weak self] in self?.tick() }
            t.resume()
            timer = t
        }
    }

    private func currentPids() -> Set<pid_t> {
        let bytesNeeded = proc_listallpids(nil, 0)
        guard bytesNeeded > 0 else { return [] }
        var buffer = [pid_t](repeating: 0, count: Int(bytesNeeded) + 64)
        let result = proc_listallpids(&buffer, Int32(buffer.count * MemoryLayout<pid_t>.size))
        guard result > 0 else { return [] }
        // Em algumas versões o retorno é a contagem de PIDs, em outras o número de bytes: aceita os dois.
        let count = Int(result) <= buffer.count ? Int(result) : Int(result) / MemoryLayout<pid_t>.size
        return Set(buffer.prefix(count).filter { $0 > 0 })
    }

    private func tick() {
        let current = currentPids()
        let fresh = current.subtracting(known)
        known = current
        for pid in fresh { recheck[pid] = 4 }              // recheca por alguns ciclos (o PID pode nascer antes do exec)
        for (pid, left) in recheck {
            if !current.contains(pid) { recheck[pid] = nil; continue }
            if let name = artCraftName(pid: pid) { recheck[pid] = nil; onLaunch?(pid, name); continue }
            recheck[pid] = left > 1 ? left - 1 : nil
        }
    }

    private func artCraftName(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        let path = String(cString: buffer)
        guard let range = path.range(of: ".app/Contents/MacOS/") else { return nil }
        let appPath = String(path[..<range.lowerBound]) + ".app"
        let id: String?
        if let cached = bundleCache[appPath] { id = cached }
        else { id = Bundle(path: appPath)?.bundleIdentifier; bundleCache[appPath] = id }
        guard let bundleID = id, ArtCraftWatcher.matches(bundleID: bundleID) else { return nil }
        return ((appPath as NSString).lastPathComponent as NSString).deletingPathExtension
    }
}
