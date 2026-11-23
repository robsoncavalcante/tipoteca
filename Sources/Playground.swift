import SwiftUI
import CoreText
import UniformTypeIdentifiers

/// Fonte do CoreText a partir de um arquivo, com peso opcional (eixo 'wght' em fontes variáveis).
enum CTFonts {
    static func font(face: FontFace, size: Double, weight: Int?) -> Font? {
        guard let base = FontScanner.previewDescriptor(for: face) else { return nil }
        let descriptor = weight.map {
            CTFontDescriptorCreateCopyWithVariation(base, 2003265652 as CFNumber, CGFloat($0))
        } ?? base
        return Font(CTFontCreateWithFontDescriptor(descriptor, size, nil))
    }
}

private let weightOptions: [(String, Int?)] = [
    (tr("Default"), nil), ("Light 300", 300), ("Regular 400", 400), ("Medium 500", 500),
    ("SemiBold 600", 600), ("Bold 700", 700), ("Black 900", 900)
]

// MARK: - Tela

struct PlaygroundView: View {
    @EnvironmentObject var store: LibraryStore
    @State private var selected = 0
    @State private var showDefaults = false
    @State private var showTemplates = false

    private var count: Int { store.playground.compositions.count }
    private var current: Int { min(selected, max(count - 1, 0)) }
    private var other: Int { (current + 1) % max(count, 1) }
    private var showsTwo: Bool { store.playground.compare && count > 1 }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(T.line).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .top, spacing: 24) {
                        CompositionEditor(composition: binding(current))
                        if showsTwo { CompositionEditor(composition: binding(other)) }
                    }
                    ProjectNotesCard()
                }.padding(28)
            }
        }
        .onAppear { suggestDefaultsIfNeeded() }
        .onChange(of: store.playground.currentID) { _, _ in
            selected = 0
            suggestDefaultsIfNeeded()
        }
        .sheet(isPresented: $showTemplates) { TemplateGallery { addComposition($0) } }
    }

    /// Projeto sem fontes padrão: sugere uma que exista na biblioteca, para já abrir com texto desenhado.
    private func suggestDefaultsIfNeeded() {
        guard !store.playground.hasDefaults else { return }
        let preferred = ["poppins", "montserrat", "inter", "roboto", "open sans"]
        let ids = Set(store.localFamilies.map(\.id))
        guard let pick = preferred.first(where: { ids.contains($0) }) else { return }
        store.playground.defaultTitle = pick
        store.playground.defaultSupport = pick
        store.playground.defaultBody = pick
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Text("Playground").font(.system(size: 28, weight: .bold)).tracking(-0.6)
                ProjectMenuButton()
                Spacer()
                Button { showTemplates = true } label: {
                    Label(tr("Templates"), systemImage: "square.grid.2x2").font(.system(size: 12, weight: .semibold))
                }.buttonStyle(.plain)
                Button { showDefaults.toggle() } label: {
                    Label(tr("Default fonts"), systemImage: "textformat")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(store.playground.hasDefaults ? T.text : T.green)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showDefaults, arrowEdge: .bottom) { DefaultFontsPanel() }
                Toggle(tr("Compare"), isOn: $store.playground.compare)
                    .toggleStyle(.switch).controlSize(.small).tint(T.green).disabled(count < 2)
                    .help(count < 2 ? tr("Create a second composition to compare") : tr("Shows two compositions side by side"))
            }
            HStack(spacing: 8) {
                ForEach(Array(store.playground.compositions.enumerated()), id: \.element.id) { index, composition in
                    Button { selected = index } label: {
                        Text(composition.name).font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(index == current ? .black : T.muted)
                            .padding(.horizontal, 12).frame(height: 28)
                            .background(Capsule().fill(index == current ? T.text : T.panel))
                    }.buttonStyle(.plain)
                }
                IconButton(systemName: "plus", help: tr("New composition (copies the current one)")) { duplicate() }
                Spacer()
            }
        }
        .padding(.horizontal, 28).padding(.top, 34).padding(.bottom, 14)
    }

    private func binding(_ index: Int) -> Binding<Composition> {
        Binding(
            get: { store.playground.compositions[min(index, store.playground.compositions.count - 1)] },
            set: { newValue in
                guard index < store.playground.compositions.count else { return }
                store.playground.compositions[index] = newValue
            })
    }

    private func duplicate() {
        var copy = LibraryStore.freshIDs(store.playground.compositions[current])
        copy.name = tr("Composition %ld", count + 1)
        store.playground.compositions.append(copy)
        selected = count - 1
    }

    /// Usa um modelo: entra como nova composição do projeto atual.
    private func addComposition(_ template: Composition) {
        var copy = LibraryStore.freshIDs(template)
        if store.playground.compositions.contains(where: { $0.name == copy.name }) { copy.name += " \(count + 1)" }
        store.playground.compositions.append(copy)
        selected = count - 1
        store.status = tr("Template “%@” added to the project.", copy.name)
    }
}

// MARK: - Cores e símbolo (utilitários)

private func hexString(_ color: Color) -> String {
    let ns = NSColor(color).usingColorSpace(.sRGB) ?? .black
    return String(format: "%02X%02X%02X", Int((ns.redComponent * 255).rounded()),
                  Int((ns.greenComponent * 255).rounded()), Int((ns.blueComponent * 255).rounded()))
}

private func color(fromHex hex: String?) -> Color? {
    guard let hex, hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
    return Color(hex: value)
}

private enum SymbolCache {
    private static let cache = NSCache<NSString, NSImage>()
    static func image(at path: String) -> NSImage? {
        if let cached = cache.object(forKey: path as NSString) { return cached }
        guard let image = NSImage(contentsOfFile: path) else { return nil }
        cache.setObject(image, forKey: path as NSString)
        return image
    }
}

// MARK: - A peça visual (usada na tela e na exportação em PNG)

struct CompositionCanvas: View {
    let composition: Composition
    let families: [FontFamilyItem]

    var body: some View {
        let ink = color(fromHex: composition.inkHex) ?? (composition.isDark ? Color(hex: 0xF1F3F1) : Color(hex: 0x111411))
        let background = color(fromHex: composition.backgroundHex) ?? (composition.isDark ? Color(hex: 0x0D120F) : Color(hex: 0xF4F6F4))
        let texts = VStack(alignment: .leading, spacing: 10) {
            ForEach(composition.blocks) { block in
                BlockText(block: block, families: families).foregroundStyle(ink)
            }
        }
        Group {
            if let path = composition.symbolPath, let image = SymbolCache.image(at: path) {
                let symbol = Image(nsImage: image).resizable().scaledToFit().frame(height: composition.symbolSize)
                if composition.symbolOnTop {
                    VStack(alignment: .leading, spacing: composition.symbolGap) { symbol; texts }
                } else {
                    HStack(alignment: .center, spacing: composition.symbolGap) { symbol; texts }
                }
            } else {
                texts
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
        .background(background)
    }
}

// MARK: - Editor de uma composição

private struct CompositionEditor: View {
    @EnvironmentObject var store: LibraryStore
    @Binding var composition: Composition

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CompositionCanvas(composition: store.playground.resolved(composition), families: store.localFamilies)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.line))
            header
            colorsRow
            symbolRow
            ForEach($composition.blocks) { $block in BlockControls(block: $block) }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 12) {
            TextField(tr("Name"), text: $composition.name).inputField().frame(width: 180)
            Toggle(tr("Dark background"), isOn: $composition.isDark).toggleStyle(.switch).controlSize(.small).tint(T.green)
            Spacer()
            Button(tr("Activate fonts")) { activateUsedFonts() }
                .help(tr("Activates in the system the fonts used in this composition"))
            Button(tr("Export PNG")) { exportPNG() }
            Menu {
                Button(tr("Save as template")) { saveAsTemplate() }
                Button(tr("Delete composition"), role: .destructive) {
                    store.playground.compositions.removeAll { $0.id == composition.id }
                }.disabled(store.playground.compositions.count < 2)
            } label: {
                Image(systemName: "ellipsis.circle").font(.system(size: 15)).foregroundStyle(T.muted)
            }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        }
    }

    private var colorsRow: some View {
        HStack(spacing: 16) {
            ColorPicker(tr("Background"), selection: Binding(
                get: { color(fromHex: composition.backgroundHex) ?? (composition.isDark ? Color(hex: 0x0D120F) : Color(hex: 0xF4F6F4)) },
                set: { composition.backgroundHex = hexString($0) }))
            ColorPicker(tr("Text"), selection: Binding(
                get: { color(fromHex: composition.inkHex) ?? (composition.isDark ? Color(hex: 0xF1F3F1) : Color(hex: 0x111411)) },
                set: { composition.inkHex = hexString($0) }))
            if composition.backgroundHex != nil || composition.inkHex != nil {
                Button(tr("Default colors")) { composition.backgroundHex = nil; composition.inkHex = nil }
                    .buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).foregroundStyle(T.lime)
            }
            Spacer()
        }.font(.system(size: 12))
    }

    private var symbolRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(tr("Symbol")).font(.system(size: 13, weight: .bold))
                Button(composition.symbolPath == nil ? tr("Choose image…") : tr("Change…")) { chooseSymbol() }
                if let path = composition.symbolPath {
                    Text((path as NSString).lastPathComponent).font(.system(size: 11)).foregroundStyle(T.muted).lineLimit(1)
                    if SymbolCache.image(at: path) == nil {
                        Text(tr("could not open")).font(.system(size: 11)).foregroundStyle(.red)
                    }
                    Spacer()
                    Button(tr("Remove")) { composition.symbolPath = nil }
                        .buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).foregroundStyle(T.muted)
                } else {
                    Text(tr("PNG, JPEG, PDF or SVG — appears next to the text")).font(.system(size: 11)).foregroundStyle(T.muted)
                    Spacer()
                }
            }
            if composition.symbolPath != nil {
                HStack(spacing: 18) {
                    LabeledSlider(label: tr("Size"), valueText: "\(Int(composition.symbolSize)) px",
                                  value: $composition.symbolSize, range: 24...240)
                    LabeledSlider(label: tr("Distance"), valueText: "\(Int(composition.symbolGap)) px",
                                  value: $composition.symbolGap, range: 0...120)
                    Toggle(tr("Above the text"), isOn: $composition.symbolOnTop).toggleStyle(.switch)
                        .controlSize(.small).tint(T.green).font(.system(size: 12))
                }
            }
        }
        .padding(14).background(RoundedRectangle(cornerRadius: 10).fill(T.panel))
    }

    // MARK: Ações

    private func saveAsTemplate() {
        var template = LibraryStore.freshIDs(composition)
        template.name = composition.name
        store.playground.userTemplates.append(template)
        store.status = tr("Template “%@” saved in Templates > My templates.", template.name)
    }

    private func chooseSymbol() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .pdf, .svg]
        panel.message = tr("Choose the brand symbol")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        composition.symbolPath = url.path
    }

    private func activateUsedFonts() {
        let ids = Set(store.playground.resolved(composition).blocks.compactMap(\.familyID))
        let families = store.localFamilies.filter { ids.contains($0.id) }
        guard !families.isEmpty else { store.status = tr("Choose the block fonts before activating."); return }
        let pending = families.filter { !store.isActive($0) }
        pending.forEach { store.toggleActive($0) }
        store.status = pending.isEmpty
            ? tr("This composition's fonts were already active.")
            : trPlural(pending.count, "%ld font activated for this composition.", "%ld fonts activated for this composition.")
    }

    @MainActor
    private func exportPNG() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(composition.name).png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let content = CompositionCanvas(composition: store.playground.resolved(composition), families: store.localFamilies).frame(width: 1200)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            store.status = tr("Could not generate the image.")
            return
        }
        do {
            try png.write(to: url)
            store.status = tr("Composition exported: %@", url.lastPathComponent)
        } catch {
            store.status = tr("Error saving the image: %@", error.localizedDescription)
        }
    }
}

private struct BlockText: View {
    let block: TextBlock
    let families: [FontFamilyItem]

    var body: some View {
        let family = families.first { $0.id == block.familyID }
        let font: Font = family.flatMap { CTFonts.font(face: $0.face(weight: block.weight), size: block.size, weight: block.weight) }
            ?? .system(size: block.size, weight: .regular)
        Text(block.text.isEmpty ? " " : block.text)
            .font(font)
            .tracking(block.tracking * block.size)
            .lineSpacing(max(0, (block.lineHeight - 1.0) * block.size))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BlockControls: View {
    @EnvironmentObject var store: LibraryStore
    @Binding var block: TextBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(blockLabel(block.label)).font(.system(size: 13, weight: .bold)).frame(width: 52, alignment: .leading)
                FamilyPickerButton(familyID: $block.familyID, fallbackID: store.playground.defaultFamily(for: block.label))
                Picker("", selection: $block.weight) {
                    ForEach(weightOptions, id: \.0) { Text($0.0).tag($0.1) }
                }.labelsHidden().frame(width: 130)
            }
            TextField(tr("Text"), text: $block.text, axis: .vertical).lineLimit(1...3).inputFieldFlexible()
            HStack(spacing: 18) {
                LabeledSlider(label: tr("Size"), valueText: "\(Int(block.size)) px", value: $block.size, range: 8...160)
                LabeledSlider(label: tr("Spacing"),
                              valueText: abs(block.tracking) < 0.005 ? "Normal" : String(format: "%+.2f", block.tracking),
                              value: $block.tracking, range: -0.1...0.4)
                LabeledSlider(label: tr("Line height"), valueText: String(format: "%.2f", block.lineHeight),
                              value: $block.lineHeight, range: 0.8...2.2)
            }
        }
        .padding(14).background(RoundedRectangle(cornerRadius: 10).fill(T.panel))
    }
}

extension View {
    /// Campo de texto de várias linhas, no mesmo estilo (altura livre).
    func inputFieldFlexible() -> some View {
        self.textFieldStyle(.plain).font(.system(size: 13))
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 6).fill(T.bg))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(T.lineStrong))
    }
}

// MARK: - Seletor de família (com busca)

private struct FamilyPickerButton: View {
    @EnvironmentObject var store: LibraryStore
    @Binding var familyID: String?
    var fallbackID: String? = nil
    var allowsClear = false
    @State private var isOpen = false
    @State private var query = ""

    private var effectiveID: String? { familyID ?? fallbackID }
    private var isFallback: Bool { familyID == nil && fallbackID != nil }
    private var currentName: String? { store.localFamilies.first { $0.id == effectiveID }?.name }

    var body: some View {
        Button { isOpen.toggle() } label: {
            HStack {
                Text(currentName ?? tr("Choose font…")).font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(currentName == nil ? T.green : T.text).lineLimit(1)
                if isFallback { Text(tr("default")).font(.system(size: 10)).foregroundStyle(T.muted) }
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10)).foregroundStyle(T.muted)
            }
            .padding(.horizontal, 10).frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 6).fill(T.bg))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(T.lineStrong))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isOpen, arrowEdge: .bottom) { picker }
    }

    private var picker: some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        let items = q.isEmpty ? store.localFamilies : store.localFamilies.filter { $0.name.localizedCaseInsensitiveContains(q) }
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(T.muted)
                TextField(tr("Search library"), text: $query).textFieldStyle(.plain)
            }.inputField().padding(10)
            Rectangle().fill(T.line).frame(height: 1)
            if allowsClear || (familyID != nil && fallbackID != nil) {
                Button(allowsClear ? tr("No default font") : tr("Use the default font")) { familyID = nil; isOpen = false }
                    .buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).foregroundStyle(T.lime)
                    .padding(.horizontal, 14).frame(height: 30, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
                Rectangle().fill(T.line).frame(height: 1)
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { family in
                        Button { familyID = family.id; isOpen = false } label: {
                            HStack {
                                NameInFont(face: family.preview, size: 16).lineLimit(1)
                                Spacer()
                                if family.id == effectiveID { Image(systemName: "checkmark").foregroundStyle(T.green) }
                            }
                            .padding(.horizontal, 14).frame(height: 34)
                            .background(family.id == effectiveID ? T.selected : .clear)
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }
            }.frame(height: 320)
        }
        .frame(width: 320).background(T.bg).preferredColorScheme(.dark)
    }
}


// MARK: - Painel "Fontes padrão"

private struct DefaultFontsPanel: View {
    @EnvironmentObject var store: LibraryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("Default fonts")).font(.system(size: 15, weight: .bold))
            Text(tr("They apply to every composition, new or old, where the block has no font of its own."))
                .font(.system(size: 11)).foregroundStyle(T.muted).fixedSize(horizontal: false, vertical: true)
            row("Título", $store.playground.defaultTitle)
            row("Apoio", $store.playground.defaultSupport)
            row("Corpo", $store.playground.defaultBody)
            Button(tr("Use the default fonts in every block of every composition")) { clearOverrides() }
                .buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).foregroundStyle(T.lime)
        }
        .padding(18).frame(width: 380).background(T.bg).preferredColorScheme(.dark)
    }

    private func row(_ label: String, _ binding: Binding<String?>) -> some View {
        HStack(spacing: 10) {
            Text(blockLabel(label)).font(.system(size: 13, weight: .bold)).frame(width: 52, alignment: .leading)
            FamilyPickerButton(familyID: binding, allowsClear: true)
        }
    }

    /// Remove as escolhas individuais da composição que está em foco, para ela seguir os padrões.
    private func clearOverrides() {
        guard !store.playground.compositions.isEmpty else { return }
        for index in store.playground.compositions.indices {
            for block in store.playground.compositions[index].blocks.indices {
                store.playground.compositions[index].blocks[block].familyID = nil
            }
        }
    }
}
