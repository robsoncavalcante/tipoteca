import Foundation

// MARK: - Google Fonts (repositório público github.com/google/fonts, sem chave de API)

struct GoogleFamily: Identifiable, Codable, Hashable {
    let name: String
    let dir: String          // ex.: "ofl/poppins"
    let license: String      // ofl | apache | ufl
    let files: [String]      // caminhos .ttf dentro do repositório

    var id: String { dir }
    var regularFile: String {
        files.first { $0.localizedCaseInsensitiveContains("-Regular.ttf") }
            ?? files.first { $0.contains("[") }
            ?? files[0]
    }
}

enum GoogleFonts {
    private static let treeURL = URL(string: "https://api.github.com/repos/google/fonts/git/trees/main?recursive=1")!
    private static let rawBase = "https://raw.githubusercontent.com/google/fonts/main/"
    private static let cdnBase = "https://cdn.jsdelivr.net/gh/google/fonts@main/"

    static var cacheDir: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Tipoteca/google", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func loadCatalog(forceRefresh: Bool = false) async throws -> [GoogleFamily] {
        let cache = cacheDir.appendingPathComponent("catalog.json")
        let maxAge: TimeInterval = 7 * 24 * 3600
        if !forceRefresh,
           let attrs = try? FileManager.default.attributesOfItem(atPath: cache.path),
           let modified = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) < maxAge,
           let data = try? Data(contentsOf: cache),
           let cached = try? JSONDecoder().decode([GoogleFamily].self, from: data) {
            return cached
        }

        let (data, response) = try await URLSession.shared.data(from: treeURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        struct Tree: Decodable { struct Node: Decodable { let path: String; let type: String }; let tree: [Node] }
        let tree = try JSONDecoder().decode(Tree.self, from: data)

        var grouped: [String: [String]] = [:]
        for node in tree.tree where node.type == "blob" && node.path.hasSuffix(".ttf") {
            let parts = node.path.split(separator: "/")
            guard parts.count >= 3, ["ofl", "apache", "ufl"].contains(String(parts[0])) else { continue }
            grouped[parts[0] + "/" + parts[1], default: []].append(node.path)
        }
        let families = grouped.map { dir, files -> GoogleFamily in
            let sorted = files.sorted()
            return GoogleFamily(name: displayName(from: sorted[0]), dir: dir, license: String(dir.split(separator: "/")[0]), files: sorted)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        if let encoded = try? JSONEncoder().encode(families) { try? encoded.write(to: cache) }
        return families
    }

    /// "OpenSans[wdth,wght].ttf" -> "Open Sans", "IBMPlexSans-Bold.ttf" -> "IBM Plex Sans"
    static func displayName(from path: String) -> String {
        var base = (path as NSString).lastPathComponent.replacingOccurrences(of: ".ttf", with: "")
        if let i = base.firstIndex(of: "[") { base = String(base[..<i]) }
        if let i = base.firstIndex(of: "-") { base = String(base[..<i]) }
        var out = ""
        let chars = Array(base)
        for (i, c) in chars.enumerated() {
            if i > 0, c.isUppercase {
                let prev = chars[i - 1]
                let next = i + 1 < chars.count ? chars[i + 1] : " "
                if prev.isLowercase || prev.isNumber || (prev.isUppercase && next.isLowercase) { out.append(" ") }
            }
            out.append(c)
        }
        return out
    }

    /// Baixa só 1 arquivo (para a prévia). Fica em cache e NÃO entra na biblioteca.
    static func previewFile(for family: GoogleFamily) async -> URL? {
        let file = family.regularFile
        let dest = cacheDir.appendingPathComponent("preview", isDirectory: true).appendingPathComponent((file as NSString).lastPathComponent)
        if FileManager.default.fileExists(atPath: dest.path) { return dest }
        return try? await download(path: file, to: dest)
    }

    /// Baixa todos os estilos da família para a pasta da biblioteca.
    static func downloadFamily(_ family: GoogleFamily, into libraryDir: URL) async throws -> [URL] {
        let folder = libraryDir.appendingPathComponent("Google Fonts/\(family.name)", isDirectory: true)
        var urls: [URL] = []
        for file in family.files {
            let dest = folder.appendingPathComponent((file as NSString).lastPathComponent)
            urls.append(try await download(path: file, to: dest))
        }
        return urls
    }

    /// Tenta o CDN jsDelivr primeiro (sem limite apertado) e o GitHub raw como reserva.
    private static func download(path: String, to dest: URL) async throws -> URL {
        if FileManager.default.fileExists(atPath: dest.path) { return dest }
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let mirrors = [cdnBase + encoded, rawBase + encoded].compactMap(URL.init(string:))

        var lastError: Error = URLError(.badURL)
        for url in mirrors {
            do {
                let (tmp, response) = try await URLSession.shared.download(from: url)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                guard FontScanner.faces(at: tmp, source: .google).isEmpty == false || isFontMagic(tmp) else { throw URLError(.cannotParseResponse) }
                try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.moveItem(at: tmp, to: dest)
                return dest
            } catch { lastError = error }
        }
        throw lastError
    }

    /// Garante que não gravamos uma página de erro (HTML) como se fosse fonte.
    private static func isFontMagic(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url), let head = try? handle.read(upToCount: 4) else { return false }
        try? handle.close()
        return [Data([0, 1, 0, 0]), Data("OTTO".utf8), Data("true".utf8), Data("ttcf".utf8)].contains(head)
    }
}

// MARK: - Adobe Fonts (somente leitura)
//
// A Adobe não oferece API para baixar os arquivos: o Creative Cloud ativa as fontes
// e as guarda numa pasta interna. O Tipoteca apenas LISTA o que já está ativado por lá,
// para aparecer junto das demais. Ativar/desativar continua sendo pelo fonts.adobe.com.

enum AdobeFonts {
    static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Adobe/CoreSync/plugins/livetype", isDirectory: true)
    }

    static func scan() -> [FontFace] {
        FontScanner.fontFiles(in: [folder]).flatMap { FontScanner.faces(at: $0, source: .adobe) }
    }
}
