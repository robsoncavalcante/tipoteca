import Foundation

/// Como o Tipoteca coloca uma fonte à disposição dos apps.
enum ActivationMode: String, CaseIterable {
    /// Usa "Pelo sistema" e muda sozinho para "Por pasta" enquanto um app da ArtCraft estiver aberto.
    case auto
    /// Pergunta ao sistema (CoreText): nada é copiado. Funciona no Adobe, Figma, DesignCraft, PhotoCraft...
    case system
    /// Copia os arquivos para ~/Library/Fonts/Tipoteca. Serve também apps que só leem pastas de fontes (ex.: EffectCraft).
    case folder

    var title: String {
        switch self {
        case .auto: return tr("Automatic (recommended)")
        case .system: return tr("Through the system")
        case .folder: return tr("By folder (ArtCraft)")
        }
    }

    var detail: String {
        switch self {
        case .auto: return tr("Copies nothing day to day. When an ArtCraft app opens, it copies the active fonts on the spot; when the last one closes, it deletes the copies.")
        case .system: return tr("Copies nothing. Works in Adobe and almost everything, but some apps (like EffectCraft) cannot see them.")
        case .folder: return tr("Always keeps the active fonts copied to ~/Library/Fonts/Tipoteca. Every app sees them; when you deactivate, the copy is deleted.")
        }
    }
}

enum FontSource: String, Codable, CaseIterable {
    case local, google, adobe

    var label: String {
        switch self {
        case .local: return "Local"
        case .google: return "Google Fonts"
        case .adobe: return "Adobe Fonts"
        }
    }
}

/// Um arquivo/estilo de fonte (ex.: Poppins Bold).
struct FontFace: Identifiable, Codable, Hashable {
    let path: String
    let family: String
    let style: String
    let postScript: String
    let source: FontSource

    var id: String { path + "#" + postScript }
    var url: URL { URL(fileURLWithPath: path) }
}

/// Uma família agrupando todos os estilos (é a unidade de ativação).
struct FontFamilyItem: Identifiable, Hashable {
    let name: String
    let faces: [FontFace]

    var id: String { FontFamilyItem.key(name) }
    var source: FontSource { faces.first?.source ?? .local }
    var urls: [URL] { Array(Set(faces.map(\.path))).sorted().map { URL(fileURLWithPath: $0) } }
    var preview: FontFace {
        faces.first { $0.style.lowercased() == "regular" } ?? faces.first { $0.style.lowercased() == "book" } ?? faces[0]
    }

    /// Estilo mais próximo do peso pedido (nil = estilo padrão da família).
    func face(weight: Int?) -> FontFace {
        guard let weight, let word = FontFamilyItem.weightWords[weight] else { return preview }
        let match = faces.first { face in
            let style = face.style.lowercased()
            return word.contains { style.contains($0) } && !style.contains("italic") && !style.contains("oblique")
        }
        return match ?? preview
    }

    static let weightWords: [Int: [String]] = [
        300: ["light"], 400: ["regular", "book"], 500: ["medium"],
        600: ["semibold", "demibold", "semi bold"], 700: ["bold"], 900: ["black", "heavy"]
    ]

    static func key(_ name: String) -> String { name.lowercased() }
}

struct FontCollection: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var familyIDs: Set<String> = []
}

/// Tudo o que é persistido em library.json.
struct LibraryState: Codable {
    var faces: [FontFace] = []
    var collections: [FontCollection] = []
    var favorites: Set<String> = []
    var active: Set<String> = []
}

enum SidebarItem: Hashable {
    case all, active, favorites
    case collection(UUID)
    case source(FontSource)
    case google
    case playground
}

// MARK: - Playground

struct TextBlock: Codable, Identifiable, Hashable {
    var id = UUID()
    var label: String
    var text: String
    var familyID: String?
    var weight: Int?
    var size: Double
    var tracking: Double = 0      // em
    var lineHeight: Double = 1.2
}

struct Composition: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var isDark = true
    var blocks: [TextBlock]
    // Símbolo (marca) ao lado ou acima do texto
    var symbolPath: String?
    var symbolSize: Double = 72
    var symbolGap: Double = 18
    var symbolOnTop = false
    // Cores personalizadas (hex "RRGGBB"); nil = padrão do tema claro/escuro
    var backgroundHex: String?
    var inkHex: String?

    init(name: String, isDark: Bool = true, blocks: [TextBlock]) {
        self.name = name; self.isDark = isDark; self.blocks = blocks
    }

    // Decodificação tolerante: arquivos salvos antes dos campos novos continuam abrindo.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        isDark = try c.decodeIfPresent(Bool.self, forKey: .isDark) ?? true
        blocks = try c.decode([TextBlock].self, forKey: .blocks)
        symbolPath = try c.decodeIfPresent(String.self, forKey: .symbolPath)
        symbolSize = try c.decodeIfPresent(Double.self, forKey: .symbolSize) ?? 72
        symbolGap = try c.decodeIfPresent(Double.self, forKey: .symbolGap) ?? 18
        symbolOnTop = try c.decodeIfPresent(Bool.self, forKey: .symbolOnTop) ?? false
        backgroundHex = try c.decodeIfPresent(String.self, forKey: .backgroundHex)
        inkHex = try c.decodeIfPresent(String.self, forKey: .inkHex)
    }
}

extension Composition {
    static var starter: Composition {
        Composition(name: tr("Composition 1"), blocks: [
            TextBlock(label: "Título", text: tr("Morning Brew!"), familyID: nil, weight: 700, size: 64),
            TextBlock(label: "Apoio", text: tr("Hydrated with my 12 cups of coffee!"), familyID: nil, weight: nil, size: 24),
            TextBlock(label: "Corpo", text: tr("Coffee is 98% water and 2% energy. Test here how the title talks to the paragraph, the hierarchy and the rhythm of the text."), familyID: nil, weight: nil, size: 16, lineHeight: 1.45)
        ])
    }
}

/// Um trabalho de um cliente: composições, notas e fontes padrão próprias.
struct Project: Codable, Identifiable, Hashable {
    var id = UUID()
    var client: String
    var name: String
    var notes: String = ""
    var compositions: [Composition]
    var defaultTitle: String?
    var defaultSupport: String?
    var defaultBody: String?
    var updatedAt = Date()
}

struct PlaygroundState: Codable {
    var projects: [Project]
    var currentID: UUID
    var compare = false
    /// "Meus modelos": composições salvas para reutilizar em qualquer projeto.
    var userTemplates: [Composition] = []

    init(projects: [Project], currentID: UUID) {
        self.projects = projects
        self.currentID = currentID
    }

    static var starter: PlaygroundState {
        let project = Project(client: tr("No client"), name: tr("Drafts"), compositions: [.starter])
        return PlaygroundState(projects: [project], currentID: project.id)
    }

    // MARK: Projeto atual (o resto do app continua usando compositions/defaults como antes)

    private var currentIndex: Int { projects.firstIndex { $0.id == currentID } ?? 0 }

    var current: Project {
        get { projects[currentIndex] }
        set { projects[currentIndex] = newValue }
    }

    var compositions: [Composition] {
        get { current.compositions }
        set { current.compositions = newValue; current.updatedAt = Date() }
    }
    var defaultTitle: String? {
        get { current.defaultTitle }
        set { current.defaultTitle = newValue }
    }
    var defaultSupport: String? {
        get { current.defaultSupport }
        set { current.defaultSupport = newValue }
    }
    var defaultBody: String? {
        get { current.defaultBody }
        set { current.defaultBody = newValue }
    }

    func defaultFamily(for label: String) -> String? {
        switch label {
        case "Título": return defaultTitle
        case "Apoio": return defaultSupport
        default: return defaultBody
        }
    }

    /// Composição com as fontes padrão do projeto aplicadas aos blocos sem fonte própria.
    func resolved(_ composition: Composition) -> Composition {
        var copy = composition
        copy.blocks = composition.blocks.map { block in
            var b = block
            if b.familyID == nil { b.familyID = defaultFamily(for: b.label) }
            return b
        }
        return copy
    }

    var hasDefaults: Bool { defaultTitle != nil || defaultSupport != nil || defaultBody != nil }

    // MARK: Codable (lê também o formato antigo, de um projeto só)

    enum CodingKeys: String, CodingKey {
        case projects, currentID, compare, userTemplates
        case compositions, defaultTitle, defaultSupport, defaultBody   // formato antigo
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        compare = try c.decodeIfPresent(Bool.self, forKey: .compare) ?? false
        userTemplates = try c.decodeIfPresent([Composition].self, forKey: .userTemplates) ?? []
        if let list = try c.decodeIfPresent([Project].self, forKey: .projects), !list.isEmpty {
            projects = list
            let saved = try c.decodeIfPresent(UUID.self, forKey: .currentID)
            currentID = list.contains { $0.id == saved } ? (saved ?? list[0].id) : list[0].id
        } else {
            let old = try c.decodeIfPresent([Composition].self, forKey: .compositions) ?? []
            var project = Project(client: tr("No client"), name: tr("Drafts"), compositions: old.isEmpty ? [.starter] : old)
            project.defaultTitle = try c.decodeIfPresent(String.self, forKey: .defaultTitle)
            project.defaultSupport = try c.decodeIfPresent(String.self, forKey: .defaultSupport)
            project.defaultBody = try c.decodeIfPresent(String.self, forKey: .defaultBody)
            projects = [project]
            currentID = project.id
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(projects, forKey: .projects)
        try c.encode(currentID, forKey: .currentID)
        try c.encode(compare, forKey: .compare)
        try c.encode(userTemplates, forKey: .userTemplates)
    }
}
