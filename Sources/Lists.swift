import SwiftUI
import CoreText

// MARK: - Prévia

/// Desenha o texto com a fonte lida direto do arquivo — sem instalar nada no sistema.
struct FontPreview: View {
    @EnvironmentObject var prefs: PreviewPrefs
    let face: FontFace
    var size: Double? = nil

    var body: some View {
        let points = size ?? prefs.size
        if let base = FontScanner.previewDescriptor(for: face) {
            let descriptor = prefs.weight.map {
                CTFontDescriptorCreateCopyWithVariation(base, 2003265652 as CFNumber, CGFloat($0))   // eixo 'wght'
            } ?? base
            Text(prefs.text.isEmpty ? face.family : prefs.text)
                .font(Font(CTFontCreateWithFontDescriptor(descriptor, points, nil)))
                .tracking(prefs.tracking * points)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
        } else {
            Text(face.family).foregroundStyle(T.muted)
        }
    }
}

private func previewHeight(_ size: Double) -> CGFloat { CGFloat(size * 1.35) }

// MARK: - Fontes da biblioteca (e Adobe, somente leitura)

struct FamilyList: View {
    @EnvironmentObject var prefs: PreviewPrefs
    let items: [FontFamilyItem]
    let readOnly: Bool
    let showAdobeNotice: Bool

    var body: some View {
        VStack(spacing: 0) {
            if showAdobeNotice { AdobeNotice() }
            CountRow(text: "\(items.count) famílias")
            if items.isEmpty {
                EmptyState(title: "Nenhuma fonte aqui",
                           message: readOnly ? "Nenhuma fonte do Adobe Fonts ativada no Creative Cloud."
                                             : "Arraste fontes ou pastas para a janela, ou clique em Adicionar fontes.")
            } else {
                ScrollView {
                    if prefs.isList {
                        LazyVStack(spacing: 0) {
                            ForEach(items) { family in
                                FamilyEntry(family: family, readOnly: readOnly, compact: false)
                                    .padding(.horizontal, 28).padding(.vertical, 16)
                                    .overlay(alignment: .bottom) { Rectangle().fill(T.line).frame(height: 1).padding(.horizontal, 28) }
                            }
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 0)], spacing: 0) {
                            ForEach(items) { family in
                                FamilyEntry(family: family, readOnly: readOnly, compact: true)
                                    .padding(16)
                                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                            }
                        }.padding(.horizontal, 28)
                    }
                }
            }
        }
    }
}

struct FamilyEntry: View {
    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var prefs: PreviewPrefs
    let family: FontFamilyItem
    let readOnly: Bool
    let compact: Bool
    @State private var showStyles = false

    var body: some View {
        let active = store.isActive(family)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if readOnly { Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(T.muted).frame(width: 17) }
                else { ActivateDot(isOn: active) { store.toggleActive(family) } }
                Text(family.name).font(.system(size: 15, weight: .bold)).lineLimit(1)
                if !compact {
                    Rectangle().fill(T.lineStrong).frame(width: 1, height: 14)
                    Chips(family: family)
                }
                Spacer(minLength: 4)
                if !readOnly { actions }
            }
            if compact { Chips(family: family) }
            FontPreview(face: family.face(weight: prefs.weight))
                .frame(height: previewHeight(prefs.size))
            HStack {
                Text(readOnly ? "Gerenciada pelo Creative Cloud" : (active ? "Ativa no sistema" : "Desativada"))
                    .font(.system(size: 11)).foregroundStyle(active ? T.green : T.muted)
                Spacer()
                Button { showStyles.toggle() } label: {
                    Text("Explorar família ›").font(.system(size: 12, weight: .semibold))
                        .padding(.vertical, 6).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showStyles) { FamilyDetail(family: family) }
            }
        }
        .contextMenu {
            if !readOnly {
                Button("Mostrar no Finder") { NSWorkspace.shared.activateFileViewerSelecting([family.preview.url]) }
                Divider()
                Button("Remover da biblioteca") { store.removeFromLibrary(family, trashFiles: false) }
                Button("Remover e mover arquivos para a Lixeira", role: .destructive) { store.removeFromLibrary(family, trashFiles: true) }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 0) {
            IconButton(systemName: store.isFavorite(family) ? "heart.fill" : "heart",
                       tint: store.isFavorite(family) ? T.green : T.muted, help: "Favoritar") { store.toggleFavorite(family) }
            Menu {
                if store.state.collections.isEmpty { Text("Crie uma coleção na barra lateral") }
                ForEach(store.state.collections) { c in
                    Button { store.toggle(family, in: c.id) } label: {
                        Label(c.name, systemImage: c.familyIDs.contains(family.id) ? "checkmark" : "folder")
                    }
                }
            } label: {
                Image(systemName: "plus").font(.system(size: 14)).foregroundStyle(T.muted).frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 28).help("Adicionar à coleção")
        }
    }
}

struct Chips: View {
    let family: FontFamilyItem

    var body: some View {
        HStack(spacing: 10) {
            ForEach(labels, id: \.self) { Text($0).font(.system(size: 11)).foregroundStyle(T.muted) }
        }
    }

    private var labels: [String] {
        var result = [family.source.label]
        let isVariable = family.faces.contains { $0.path.contains("[") }
        result.append(isVariable ? "Variável" : "Estática")
        result.append("\(family.faces.count) \(family.faces.count == 1 ? "face" : "faces")")
        return result
    }
}

struct StylesPopover: View {
    @EnvironmentObject var prefs: PreviewPrefs
    let family: FontFamilyItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(family.faces) { face in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(face.style).font(.system(size: 11)).foregroundStyle(T.muted)
                        FontPreview(face: face, size: 26).frame(height: 38)
                    }
                }
            }.padding(16)
        }
        .frame(width: 380, height: min(CGFloat(family.faces.count) * 62 + 32, 440))
        .background(T.panel)
    }
}

// MARK: - Google Fonts

struct GoogleList: View {
    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var prefs: PreviewPrefs
    let search: String

    private var items: [GoogleFamily] {
        let q = search.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? store.googleCatalog : store.googleCatalog.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            CountRow(text: "\(items.count) famílias · catálogo do Google Fonts")
            if store.googleCatalog.isEmpty {
                ProgressView("Carregando catálogo…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    if prefs.isList {
                        LazyVStack(spacing: 0) {
                            ForEach(items) { family in
                                GoogleEntry(family: family, compact: false)
                                    .padding(.horizontal, 28).padding(.vertical, 16)
                                    .overlay(alignment: .bottom) { Rectangle().fill(T.line).frame(height: 1).padding(.horizontal, 28) }
                            }
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 0)], spacing: 0) {
                            ForEach(items) { family in
                                GoogleEntry(family: family, compact: true)
                                    .padding(16).overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                            }
                        }.padding(.horizontal, 28)
                    }
                }
            }
        }
    }
}

struct GoogleEntry: View {
    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var prefs: PreviewPrefs
    let family: GoogleFamily
    let compact: Bool
    @State private var previewFace: FontFace?

    var body: some View {
        let inLibrary = store.isInLibrary(googleFamily: family)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: inLibrary ? "checkmark.circle.fill" : "icloud")
                    .font(.system(size: 14)).foregroundStyle(inLibrary ? T.green : T.muted).frame(width: 17)
                Text(family.name).font(.system(size: 15, weight: .bold)).lineLimit(1)
                if !compact { Rectangle().fill(T.lineStrong).frame(width: 1, height: 14) }
                Text("Google Fonts · \(family.license.uppercased()) · \(family.files.count) \(family.files.count == 1 ? "arquivo" : "arquivos")")
                    .font(.system(size: 11)).foregroundStyle(T.muted).lineLimit(1)
                Spacer(minLength: 4)
                if !inLibrary { IconButton(systemName: "arrow.down.to.line", help: "Baixar para a biblioteca") { store.download(family) } }
            }
            Group {
                if let previewFace { FontPreview(face: previewFace) }
                else { Text(prefs.text).font(.system(size: prefs.size)).foregroundStyle(T.line).redacted(reason: .placeholder).lineLimit(1) }
            }.frame(height: previewHeight(prefs.size), alignment: .leading)
            HStack {
                Text(inLibrary ? "Na biblioteca · ative na aba Todas as fontes" : "Disponível online · prévia sem ativação")
                    .font(.system(size: 11)).foregroundStyle(inLibrary ? T.green : T.muted)
                Spacer()
            }
        }
        .task(id: family.id) {
            guard previewFace == nil, let url = await GoogleFonts.previewFile(for: family) else { return }
            previewFace = FontScanner.faces(at: url, source: .google).first
        }
    }
}

// MARK: - Peças comuns

struct CountRow: View {
    let text: String
    var body: some View {
        HStack {
            Text(text).font(.system(size: 12)).foregroundStyle(T.muted)
            Spacer()
        }.padding(.horizontal, 28).padding(.vertical, 10)
    }
}

struct EmptyState: View {
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "textformat").font(.system(size: 30)).foregroundStyle(T.muted)
            Text(title).font(.system(size: 16, weight: .semibold))
            Text(message).font(.system(size: 12)).foregroundStyle(T.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
    }
}

struct AdobeNotice: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle").foregroundStyle(T.lime)
            Text("A Adobe não permite baixar os arquivos das fontes fora do Creative Cloud. Aqui você vê as que já estão ativadas lá.")
                .font(.system(size: 12)).foregroundStyle(T.muted)
            Spacer()
            Link("Abrir Adobe Fonts", destination: URL(string: "https://fonts.adobe.com/my_fonts")!)
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(T.lime)
        }
        .padding(12).background(RoundedRectangle(cornerRadius: 8).fill(T.panel))
        .padding(.horizontal, 28).padding(.top, 10)
    }
}
