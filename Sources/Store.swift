import Foundation
import AppKit

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var state = LibraryState()
    @Published private(set) var adobeFaces: [FontFace] = []
    @Published private(set) var googleCatalog: [GoogleFamily] = []
    @Published var playground = PlaygroundState.starter {
        didSet { schedulePlaygroundSave() }
    }
    @Published var status: String = ""
    @Published var isBusy = false
    /// A escolha do usuário (padrão: Automático).
    @Published var activationMode: ActivationMode = ActivationMode(rawValue: UserDefaults.standard.string(forKey: "activationMode") ?? "") ?? .auto {
        didSet {
            UserDefaults.standard.set(activationMode.rawValue, forKey: "activationMode")
            artCraftWatcher.setFastPolling(activationMode == .auto)
        }
    }
    /// O que está valendo AGORA (nunca .auto): .system ou .folder.
    @Published private(set) var appliedMode: ActivationMode = .system
    /// Apps da ArtCraft abertos neste momento.
    @Published private(set) var artCraftApps: [String] = []
    @Published var libraryDir: URL {
        didSet { UserDefaults.standard.set(libraryDir.path, forKey: "libraryDir") }
    }

    private let stateURL: URL
    private let playgroundURL: URL
    private var playgroundSaveTask: Task<Void, Never>?
    private let artCraftWatcher = ArtCraftWatcher()

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Tipoteca", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        stateURL = support.appendingPathComponent("library.json")
        playgroundURL = support.appendingPathComponent("playground.json")

        if let saved = UserDefaults.standard.string(forKey: "libraryDir") {
            libraryDir = URL(fileURLWithPath: saved, isDirectory: true)
        } else {
            libraryDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/Tipoteca", isDirectory: true)
        }
        if let data = try? Data(contentsOf: stateURL), let loaded = try? JSONDecoder().decode(LibraryState.self, from: data) {
            state = loaded
        }
        if let data = try? Data(contentsOf: playgroundURL), let loaded = try? JSONDecoder().decode(PlaygroundState.self, from: data), !loaded.compositions.isEmpty {
            playground = loaded
        }
        refreshAdobe()
        artCraftApps = ArtCraftWatcher.currentlyRunning()
        appliedMode = resolvedMode()
        reactivateSavedFonts()
        prewarmCache(for: localFamilies.filter { state.active.contains($0.id) })
        artCraftWatcher.onChange = { [weak self] names in self?.artCraftAppsChanged(names) }
        artCraftWatcher.start()
        artCraftWatcher.setFastPolling(activationMode == .auto)
    }

    // MARK: Consulta

    var localFamilies: [FontFamilyItem] { group(state.faces) }
    var adobeFamilies: [FontFamilyItem] { group(adobeFaces) }

    func families(for item: SidebarItem) -> [FontFamilyItem] {
        switch item {
        case .all: return localFamilies
        case .active: return localFamilies.filter { isActive($0) }
        case .favorites: return localFamilies.filter { state.favorites.contains($0.id) }
        case .collection(let id):
            let members = state.collections.first { $0.id == id }?.familyIDs ?? []
            return localFamilies.filter { members.contains($0.id) }
        case .source(let source):
            return source == .adobe ? adobeFamilies : localFamilies.filter { $0.source == source }
        case .google, .playground: return []
        }
    }

    func isActive(_ family: FontFamilyItem) -> Bool { state.active.contains(family.id) }
    func isFavorite(_ family: FontFamilyItem) -> Bool { state.favorites.contains(family.id) }
    func isInLibrary(googleFamily: GoogleFamily) -> Bool {
        state.faces.contains { $0.source == .google && FontFamilyItem.key($0.family) == FontFamilyItem.key(googleFamily.name) }
            || state.faces.contains { $0.path.contains("/Google Fonts/\(googleFamily.name)/") }
    }

    private func group(_ faces: [FontFace]) -> [FontFamilyItem] {
        Dictionary(grouping: faces, by: { FontFamilyItem.key($0.family) })
            .values
            .map { FontFamilyItem(name: $0[0].family, faces: $0.sorted { $0.style < $1.style }) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: Ativação

    func toggleActive(_ family: FontFamilyItem) {
        if isActive(family) {
            let errors = deactivateEverywhere(family)
            FolderActivator.purgeCache(family)
            state.active.remove(family.id)
            status = errors.isEmpty ? "“\(family.name)” desativada." : "Desativada com avisos: \(errors.first ?? "")"
        } else {
            let errors = activate(family)
            if errors.isEmpty {
                prewarmCache(for: [family])
                state.active.insert(family.id)
                status = "“\(family.name)” ativada — já aparece nos seus apps."
            } else {
                status = "Não foi possível ativar “\(family.name)”: \(errors.first ?? "")"
            }
        }
        save()
    }

    func deactivateAll() {
        localFamilies.filter { isActive($0) }.forEach { _ = deactivateEverywhere($0) }
        FolderActivator.removeEmptyRoot()
        FolderActivator.purgeAllCache()
        state.active.removeAll()
        status = "Todas as fontes foram desativadas."
        save()
    }

    /// Mantém a cópia local das fontes ativas pronta (em segundo plano), para o modo por pasta ser instantâneo.
    private func prewarmCache(for families: [FontFamilyItem]) {
        guard !families.isEmpty else { return }
        Task.detached(priority: .utility) {
            for family in families { _ = FolderActivator.prewarm(family) }
        }
    }

    /// O modo que deve valer agora, dado o que o usuário escolheu e se há app da ArtCraft aberto.
    private func resolvedMode() -> ActivationMode {
        switch activationMode {
        case .auto: return artCraftApps.isEmpty ? .system : .folder
        case .system, .folder: return activationMode
        }
    }

    /// Reaplica ao abrir o app (cobre reinício do Mac e HD externo que acabou de ser conectado).
    /// Também limpa o que sobrou de uma sessão anterior no outro modo, para nada ficar duplicado.
    private func reactivateSavedFonts() {
        let families = localFamilies.filter { state.active.contains($0.id) }
        switch appliedMode {
        case .system, .auto:
            FolderActivator.removeAll()
            let urls = families.flatMap(\.urls).filter { FileManager.default.fileExists(atPath: $0.path) }
            FontActivator.activate(urls)
        case .folder:
            FontActivator.deactivate(families.flatMap(\.urls))
            // O HD pode estar desconectado: só copia o que está acessível.
            families.filter { family in family.urls.allSatisfy { FileManager.default.fileExists(atPath: $0.path) } }
                .forEach { _ = FolderActivator.activate($0) }
        }
    }

    /// Ativa pelo modo que está valendo.
    private func activate(_ family: FontFamilyItem) -> [String] {
        switch appliedMode {
        case .system, .auto: return FontActivator.activate(family.urls)
        case .folder: return FolderActivator.activate(family)
        }
    }

    /// Desativa pelos DOIS caminhos, para não sobrar fonte ativa quando o modo mudou.
    private func deactivateEverywhere(_ family: FontFamilyItem) -> [String] {
        let errors = FontActivator.deactivate(family.urls) + FolderActivator.deactivate(family)
        FolderActivator.removeEmptyRoot()
        return errors
    }

    /// O usuário escolheu outro modo.
    func setActivationMode(_ mode: ActivationMode) {
        guard mode != activationMode else { return }
        activationMode = mode
        applyResolvedMode(reason: "Modo “\(mode.title)”")
    }

    /// Abriu ou fechou um app da ArtCraft.
    private func artCraftAppsChanged(_ names: [String]) {
        artCraftApps = names
        guard activationMode == .auto else { return }
        let reason = names.isEmpty ? "ArtCraft fechado" : "\(names.joined(separator: ", ")) aberto"
        applyResolvedMode(reason: reason)
    }

    /// Migra as fontes ativas para o modo que deve valer agora (se for diferente do atual), sem duplicar.
    private func applyResolvedMode(reason: String) {
        let target = resolvedMode()
        guard target != appliedMode else { return }
        let active = localFamilies.filter { state.active.contains($0.id) }
        appliedMode = target
        var failed = 0

        // ORDEM IMPORTA: um app da ArtCraft lê as fontes ~0,5 s depois de abrir. Por isso, ao ir para a pasta,
        // criamos os links PRIMEIRO (milissegundos) e só depois desfazemos o registro no sistema (lento).
        if target == .folder {
            for family in active where !FolderActivator.activate(family).isEmpty { failed += 1 }
            for family in active { FontActivator.deactivate(family.urls) }
        } else {
            for family in active where !FontActivator.activate(family.urls).isEmpty { failed += 1 }
            for family in active { FolderActivator.deactivate(family) }
            FolderActivator.removeEmptyRoot()
        }
        // Se uma fonte falhar (ex.: HD externo ocupado/desconectado), ela CONTINUA na lista de ativas:
        // a intenção do usuário não se perde, e ela é tentada de novo na próxima abertura do Tipoteca.
        save()
        let how = target == .folder ? "copiadas para ~/Library/Fonts/Tipoteca" : "ativadas pelo sistema"
        status = failed == 0
            ? "\(reason): \(active.count) fonte(s) \(how)."
            : "\(reason): \(failed) fonte(s) não puderam ser ativadas agora (disco desconectado?) e serão tentadas de novo ao abrir o Tipoteca."
    }

    // MARK: Favoritos e coleções

    func toggleFavorite(_ family: FontFamilyItem) {
        if state.favorites.contains(family.id) { state.favorites.remove(family.id) } else { state.favorites.insert(family.id) }
        save()
    }

    func addCollection(named name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        state.collections.append(FontCollection(name: clean))
        save()
    }

    func deleteCollection(_ id: UUID) {
        state.collections.removeAll { $0.id == id }
        save()
    }

    func toggle(_ family: FontFamilyItem, in collectionID: UUID) {
        guard let i = state.collections.firstIndex(where: { $0.id == collectionID }) else { return }
        if state.collections[i].familyIDs.contains(family.id) { state.collections[i].familyIDs.remove(family.id) }
        else { state.collections[i].familyIDs.insert(family.id) }
        save()
    }

    /// Ativa/desativa uma coleção inteira de uma vez (ideal por cliente/projeto).
    func setCollection(_ id: UUID, active: Bool) {
        let members = families(for: .collection(id))
        for family in members where isActive(family) != active { toggleActive(family) }
        status = active ? "Coleção ativada (\(members.count) famílias)." : "Coleção desativada."
    }

    // MARK: Importação

    /// - copy: copia os arquivos para a pasta da biblioteca (ex.: HD externo).
    /// - trashOriginals: depois de copiar, manda os originais para a Lixeira (recuperável).
    func importFonts(from urls: [URL], copy: Bool, trashOriginals: Bool) {
        guard !isBusy else { return }
        isBusy = true
        status = "Lendo fontes…"
        let destination = libraryDir
        let known = Set(state.faces.map(\.postScript))
        let knownPaths = Set(state.faces.map(\.path))

        Task.detached(priority: .userInitiated) { [weak self] in
            let files = FontScanner.fontFiles(in: urls)
            var added: [FontFace] = []
            var skipped = 0
            var failures = 0
            var seen = known

            for (index, file) in files.enumerated() {
                if index % 100 == 0 {
                    let progress = "Lendo fontes… \(index) de \(files.count)"
                    await MainActor.run { self?.status = progress }
                }
                // Arquivo já indexado (mesmo caminho): pula sem nem abrir — torna a re-sincronização rápida.
                if knownPaths.contains(file.path) { skipped += 1; continue }
                let faces = FontScanner.faces(at: file, source: .local)
                if faces.isEmpty { failures += 1; continue }
                if faces.allSatisfy({ seen.contains($0.postScript) }) { skipped += 1; continue }

                var finalURL = file
                if copy {
                    let folder = destination.appendingPathComponent(faces[0].family, isDirectory: true)
                    let target = folder.appendingPathComponent(file.lastPathComponent)
                    do {
                        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        if !FileManager.default.fileExists(atPath: target.path) { try FileManager.default.copyItem(at: file, to: target) }
                        finalURL = target
                    } catch { failures += 1; continue }
                }
                let stored = FontScanner.faces(at: finalURL, source: .local)
                stored.forEach { seen.insert($0.postScript) }
                added.append(contentsOf: stored)
                if copy && trashOriginals && finalURL != file { try? FileManager.default.trashItem(at: file, resultingItemURL: nil) }
            }

            let summary = "\(added.count) estilos importados · \(skipped) já existiam · \(failures) com erro"
            await MainActor.run {
                guard let self else { return }
                self.state.faces.append(contentsOf: added)
                self.save()
                self.isBusy = false
                self.status = summary
            }
        }
    }

    /// Varre a pasta da biblioteca e indexa, SEM copiar, o que ainda não é conhecido
    /// (ex.: fontes que já estavam no HD externo antes de o app existir).
    func syncLibraryFolder() {
        importFonts(from: [libraryDir], copy: false, trashOriginals: false)
    }

    func removeFromLibrary(_ family: FontFamilyItem, trashFiles: Bool) {
        if isActive(family) { toggleActive(family) }
        let paths = Set(family.faces.map(\.path))
        state.faces.removeAll { paths.contains($0.path) }
        state.favorites.remove(family.id)
        for i in state.collections.indices { state.collections[i].familyIDs.remove(family.id) }
        if trashFiles { paths.forEach { try? FileManager.default.trashItem(at: URL(fileURLWithPath: $0), resultingItemURL: nil) } }
        status = "“\(family.name)” removida da biblioteca."
        save()
    }

    // MARK: Google Fonts

    func loadGoogleCatalog(force: Bool = false) {
        guard googleCatalog.isEmpty || force else { return }
        status = "Carregando catálogo do Google Fonts…"
        Task {
            do {
                googleCatalog = try await GoogleFonts.loadCatalog(forceRefresh: force)
                status = "\(googleCatalog.count) famílias no Google Fonts."
            } catch {
                status = "Sem conexão com o Google Fonts: \(error.localizedDescription)"
            }
        }
    }

    func download(_ family: GoogleFamily) {
        status = "Baixando “\(family.name)”…"
        let dir = libraryDir
        Task {
            do {
                let urls = try await GoogleFonts.downloadFamily(family, into: dir)
                let faces = urls.flatMap { FontScanner.faces(at: $0, source: .google) }
                let known = Set(state.faces.map(\.id))
                state.faces.append(contentsOf: faces.filter { !known.contains($0.id) })
                save()
                status = "“\(family.name)” baixada para a biblioteca (ainda desativada)."
            } catch {
                status = "Falha ao baixar “\(family.name)”: \(error.localizedDescription)"
            }
        }
    }

    // MARK: Adobe

    func refreshAdobe() {
        Task.detached {
            let faces = AdobeFonts.scan()
            await MainActor.run { [weak self] in self?.adobeFaces = faces }
        }
    }

    // MARK: Persistência

    /// Grava o Playground meio segundo depois da última alteração (evita gravar a cada pixel do slider).
    private func schedulePlaygroundSave() {
        playgroundSaveTask?.cancel()
        let snapshot = playground
        let url = playgroundURL
        playgroundSaveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            if let data = try? JSONEncoder().encode(snapshot) { try? data.write(to: url, options: .atomic) }
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: stateURL, options: .atomic)
        } catch {
            status = "Erro ao salvar a biblioteca: \(error.localizedDescription)"
        }
    }
}
