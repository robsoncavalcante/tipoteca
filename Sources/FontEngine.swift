import Foundation
import CoreText

/// Leitura de metadados de fontes sem instalá-las.
enum FontScanner {
    static let extensions: Set<String> = ["ttf", "otf", "ttc", "otc"]

    static func fontFiles(in urls: [URL]) -> [URL] {
        let fm = FileManager.default
        var result: [URL] = []
        for url in urls {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }
            if !isDir.boolValue {
                if extensions.contains(url.pathExtension.lowercased()) { result.append(url) }
                continue
            }
            guard let walker = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsPackageDescendants]) else { continue }
            // "._nome.ttf" são metadados (AppleDouble) que o exFAT cria ao lado de cada arquivo: não são fontes.
            for case let file as URL in walker
            where extensions.contains(file.pathExtension.lowercased()) && !file.lastPathComponent.hasPrefix("._") {
                result.append(file)
            }
        }
        return result
    }

    static func faces(at url: URL, source: FontSource) -> [FontFace] {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] else { return [] }
        return descriptors.compactMap { d in
            guard
                let family = CTFontDescriptorCopyAttribute(d, kCTFontFamilyNameAttribute) as? String,
                let postScript = CTFontDescriptorCopyAttribute(d, kCTFontNameAttribute) as? String
            else { return nil }
            let style = (CTFontDescriptorCopyAttribute(d, kCTFontStyleNameAttribute) as? String) ?? "Regular"
            return FontFace(path: url.path, family: family, style: style, postScript: postScript, source: source)
        }
    }

    /// Descriptor para desenhar a prévia SEM registrar a fonte no sistema.
    private static let descriptorCache = NSCache<NSString, AnyObject>()

    static func previewDescriptor(for face: FontFace) -> CTFontDescriptor? {
        let key = face.id as NSString
        if let cached = descriptorCache.object(forKey: key) { return (cached as! CTFontDescriptor) }
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(face.url as CFURL) as? [CTFontDescriptor] else { return nil }
        let found = descriptors.first { (CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String) == face.postScript } ?? descriptors.first
        if let found { descriptorCache.setObject(found, forKey: key) }
        return found
    }
}

/// Ativação/desativação no sistema (visível para todos os apps do usuário).
enum FontActivator {
    private static let ignorable: Set<Int> = [
        Int(CTFontManagerError.alreadyRegistered.rawValue),
        Int(CTFontManagerError.notRegistered.rawValue)
    ]

    @discardableResult
    static func activate(_ urls: [URL]) -> [String] {
        guard !urls.isEmpty else { return [] }
        var errors = register(urls, scope: .persistent)
        if !errors.isEmpty { errors = register(urls, scope: .session) }
        return errors
    }

    @discardableResult
    static func deactivate(_ urls: [URL]) -> [String] {
        guard !urls.isEmpty else { return [] }
        var collected = unregister(urls, scope: .persistent)
        collected += unregister(urls, scope: .session)
        return collected.filter { !$0.isEmpty }
    }

    private static func register(_ urls: [URL], scope: CTFontManagerScope) -> [String] {
        var raw: Unmanaged<CFArray>?
        _ = CTFontManagerRegisterFontsForURLs(urls as CFArray, scope, &raw)
        return describe(raw)
    }

    private static func unregister(_ urls: [URL], scope: CTFontManagerScope) -> [String] {
        var raw: Unmanaged<CFArray>?
        _ = CTFontManagerUnregisterFontsForURLs(urls as CFArray, scope, &raw)
        return describe(raw)
    }

    private static func describe(_ raw: Unmanaged<CFArray>?) -> [String] {
        guard let list = raw?.takeRetainedValue() as? [CFError] else { return [] }
        return list.compactMap { error in
            ignorable.contains(CFErrorGetCode(error)) ? nil : (CFErrorCopyDescription(error) as String?)
        }
    }
}


/// Ativação "por pasta": põe as fontes da família em ~/Library/Fonts/Tipoteca/<Família>/.
/// O macOS ativa sozinho o que está em ~/Library/Fonts, e apps que só leem pastas (EffectCraft etc.) também enxergam.
///
/// Para ser RÁPIDO (um app da ArtCraft lê as fontes em ~0,5 s depois de abrir), o Tipoteca mantém uma cópia local
/// das fontes ativas em ~/Library/Application Support/Tipoteca/font-cache e, na hora de ativar, cria HARD LINKS
/// (arquivos comuns, sem ocupar espaço extra) — leva milissegundos, mesmo com o HD externo dormindo.
/// Link SIMBÓLICO não serve: o EffectCraft trava ao abrir com um link simbólico em ~/Library/Fonts.
enum FolderActivator {
    static var root: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Fonts/Tipoteca", isDirectory: true)
    }

    static var cacheRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tipoteca/font-cache", isDirectory: true)
    }

    private static func safeName(_ family: FontFamilyItem) -> String {
        family.name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
    }

    static func folder(for family: FontFamilyItem) -> URL { root.appendingPathComponent(safeName(family), isDirectory: true) }
    static func cacheFolder(for family: FontFamilyItem) -> URL { cacheRoot.appendingPathComponent(safeName(family), isDirectory: true) }

    /// Garante a cópia local (lê do HD só se ainda não existir). Pode demorar: use fora da thread principal.
    @discardableResult
    static func prewarm(_ family: FontFamilyItem) -> [String] {
        let fm = FileManager.default
        let dir = cacheFolder(for: family)
        do { try fm.createDirectory(at: dir, withIntermediateDirectories: true) }
        catch { return ["cache: \(error.localizedDescription)"] }
        var errors: [String] = []
        for source in family.urls {
            let target = dir.appendingPathComponent(source.lastPathComponent)
            if fm.fileExists(atPath: target.path) { continue }
            do { try fm.copyItem(at: source, to: target) }
            catch { errors.append("\(source.lastPathComponent): \(error.localizedDescription)") }
        }
        return errors
    }

    static func purgeCache(_ family: FontFamilyItem) {
        let dir = cacheFolder(for: family)
        guard dir.path.hasPrefix(cacheRoot.path + "/") else { return }
        try? FileManager.default.removeItem(at: dir)
    }

    static func purgeAllCache() {
        guard cacheRoot.path.hasSuffix("/Tipoteca/font-cache") else { return }
        try? FileManager.default.removeItem(at: cacheRoot)
    }

    @discardableResult
    static func activate(_ family: FontFamilyItem) -> [String] {
        let fm = FileManager.default
        let dir = folder(for: family)
        let cache = cacheFolder(for: family)
        do { try fm.createDirectory(at: dir, withIntermediateDirectories: true) }
        catch { return [tr("could not create the folder: %@", error.localizedDescription)] }
        var errors: [String] = []
        for source in family.urls {
            let name = source.lastPathComponent
            let target = dir.appendingPathComponent(name)
            if fm.fileExists(atPath: target.path) { continue }
            let cached = cache.appendingPathComponent(name)
            do {
                if fm.fileExists(atPath: cached.path) {
                    // Hard link: instantâneo. Se não der (volumes diferentes), copia o arquivo local.
                    do { try fm.linkItem(at: cached, to: target) } catch { try fm.copyItem(at: cached, to: target) }
                } else {
                    try fm.copyItem(at: source, to: target)          // 1ª vez: lê do HD (mais lento)
                }
            } catch { errors.append("\(name): \(error.localizedDescription)") }
        }
        return errors
    }

    /// Apaga só a pasta da família dentro de ~/Library/Fonts/Tipoteca (nunca mexe em arquivos de outros lugares).
    @discardableResult
    static func deactivate(_ family: FontFamilyItem) -> [String] {
        let dir = folder(for: family)
        guard dir.path.hasPrefix(root.path + "/"), FileManager.default.fileExists(atPath: dir.path) else { return [] }
        do { try FileManager.default.removeItem(at: dir); return [] }
        catch { return ["\(family.name): \(error.localizedDescription)"] }
    }

    /// Apaga TODAS as cópias do Tipoteca em ~/Library/Fonts/Tipoteca (a pasta é só nossa).
    static func removeAll() {
        guard root.path.hasSuffix("/Library/Fonts/Tipoteca") else { return }
        try? FileManager.default.removeItem(at: root)
    }

    static func removeEmptyRoot() {
        let items = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        if items.allSatisfy({ $0.hasPrefix(".") }) { try? FileManager.default.removeItem(at: root) }
    }
}
