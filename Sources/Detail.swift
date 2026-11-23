import SwiftUI
import CoreText
import AppKit

/// Detalhe de uma família: estilos, mapa de glifos e eixos de fontes variáveis.
struct FamilyDetail: View {
    @EnvironmentObject var prefs: PreviewPrefs
    @Environment(\.dismiss) private var dismiss
    let family: FontFamilyItem
    @State private var tab: Tab = .styles
    @State private var faceID: String

    enum Tab: String, CaseIterable {
        case styles = "Estilos", glyphs = "Glifos", axes = "Eixos variáveis"
        var title: String {
            switch self { case .styles: return tr("Styles"); case .glyphs: return tr("Glyphs"); case .axes: return tr("Variable axes") }
        }
    }

    init(family: FontFamilyItem, tab: Tab = .styles) {
        self.family = family
        _tab = State(initialValue: tab)
        _faceID = State(initialValue: family.preview.id)
    }

    private var face: FontFace { family.faces.first { $0.id == faceID } ?? family.preview }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(T.line).frame(height: 1)
            Group {
                switch tab {
                case .styles: StylesTab(family: family)
                case .glyphs: GlyphsTab(face: face)
                case .axes: AxesTab(face: face)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 940, height: 660)
        .background(T.bg).foregroundStyle(T.text).preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(family.name).font(.system(size: 26, weight: .bold)).tracking(-0.5)
                Text(tr("%@ · %@", family.source.label, trPlural(family.faces.count, "%ld style", "%ld styles")))
                    .font(.system(size: 12)).foregroundStyle(T.muted)
                Spacer()
                Button(tr("Close")) { dismiss() }.keyboardShortcut(.cancelAction)
            }
            HStack(spacing: 4) {
                ForEach(Tab.allCases, id: \.self) { item in
                    Button { tab = item } label: {
                        Text(item.title).font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(tab == item ? T.green : T.muted)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .overlay(alignment: .bottom) { if tab == item { Rectangle().fill(T.green).frame(height: 2) } }
                    }.buttonStyle(.plain)
                }
                Spacer()
                if tab != .styles && family.faces.count > 1 {
                    Text(tr("Inspected style")).font(.system(size: 12)).foregroundStyle(T.muted)
                    Picker("", selection: $faceID) {
                        ForEach(family.faces) { Text($0.style).tag($0.id) }
                    }.labelsHidden().frame(width: 200)
                }
            }
        }.padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 6)
    }
}

// MARK: - Estilos

private struct StylesTab: View {
    @EnvironmentObject var prefs: PreviewPrefs
    let family: FontFamilyItem

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(family.faces) { face in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(face.style).font(.system(size: 13, weight: .bold))
                            Text(face.postScript).font(.system(size: 11)).foregroundStyle(T.muted)
                            Spacer()
                            Text((face.path as NSString).lastPathComponent).font(.system(size: 11)).foregroundStyle(T.muted)
                        }
                        FontPreview(face: face, size: min(prefs.size, 64)).frame(height: min(prefs.size, 64) * 1.35)
                    }
                    .padding(.horizontal, 24).padding(.vertical, 14)
                    .overlay(alignment: .bottom) { Rectangle().fill(T.line).frame(height: 1).padding(.horizontal, 24) }
                }
            }
        }
    }
}

// MARK: - Glifos

private struct GlyphsTab: View {
    let face: FontFace
    @State private var scalars: [UInt32] = []
    @State private var query = ""
    @State private var selected: UInt32?
    @State private var copied = false
    @State private var isLoading = true

    private static let limit = 4000

    private var filtered: [UInt32] {
        let q = query.trimmingCharacters(in: .whitespaces).uppercased()
        guard !q.isEmpty else { return scalars }
        let hex = q.replacingOccurrences(of: "U+", with: "")
        return scalars.filter { value in
            if let scalar = Unicode.Scalar(value), String(scalar).uppercased() == q { return true }
            return String(value, radix: 16, uppercase: true).contains(hex)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(T.muted)
                    TextField(tr("Search character or U+0041"), text: $query).textFieldStyle(.plain)
                }.inputField().frame(width: 320)
                Text(isLoading ? tr("Reading glyphs…") : tr("%ld of %ld characters", filtered.count, scalars.count) + (scalars.count >= Self.limit ? tr(" (limited to %ld)", Self.limit) : ""))
                    .font(.system(size: 11)).foregroundStyle(T.muted)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 0)], spacing: 0) {
                        ForEach(filtered, id: \.self) { cell($0) }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)
            Rectangle().fill(T.line).frame(width: 1)
            inspector.frame(width: 260).padding(20)
        }
        .task(id: face.id) { await load() }
    }

    private func cell(_ value: UInt32) -> some View {
        Button { selected = value; copied = false } label: {
            VStack(spacing: 4) {
                GlyphText(face: face, value: value, size: 28).frame(height: 38)
                Text(String(format: "U+%04X", value)).font(.system(size: 9)).foregroundStyle(T.muted)
            }
            .frame(maxWidth: .infinity).frame(height: 68)
            .background(selected == value ? T.selected : .clear)
            .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    @ViewBuilder
    private var inspector: some View {
        if let selected, let scalar = Unicode.Scalar(selected) {
            VStack(alignment: .leading, spacing: 12) {
                GlyphText(face: face, value: selected, size: 120)
                    .frame(maxWidth: .infinity).frame(height: 160)
                    .background(RoundedRectangle(cornerRadius: 8).fill(T.panel))
                Text(String(format: "U+%04X", selected)).font(.system(size: 16, weight: .bold))
                if let name = String(scalar).applyingTransform(.toUnicodeName, reverse: false) {
                    Text(name.replacingOccurrences(of: "\\N{", with: "").replacingOccurrences(of: "}", with: ""))
                        .font(.system(size: 12)).foregroundStyle(T.muted)
                }
                Button(copied ? tr("Copied ✓") : tr("Copy character")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(String(scalar), forType: .string)
                    copied = true
                }
                Spacer()
            }
        } else {
            Text(tr("Select a glyph to enlarge it, see its code and copy the character."))
                .font(.system(size: 12)).foregroundStyle(T.muted)
            Spacer()
        }
    }

    private func load() async {
        isLoading = true
        let target = face
        let result: [UInt32] = await Task.detached(priority: .userInitiated) {
            guard let descriptor = FontScanner.previewDescriptor(for: target) else { return [] }
            let font = CTFontCreateWithFontDescriptor(descriptor, 20, nil)
            // Mapa de bits do plano básico (BMP): 8 KB, leitura instantânea (bit n do byte n>>3).
            guard let bitmap = CFCharacterSetCreateBitmapRepresentation(nil, CTFontCopyCharacterSet(font)) as Data? else { return [] }
            var found: [UInt32] = []
            for value in UInt32(0x20)..<UInt32(0x10000) {
                if found.count >= GlyphsTab.limit { break }
                if value >= 0x7F && value <= 0x9F { continue }               // controles
                if value >= 0xD800 && value <= 0xF8FF { continue }           // substitutos e uso privado
                let byte = Int(value >> 3)
                if byte < bitmap.count, bitmap[byte] & (1 << UInt8(value & 7)) != 0 { found.append(value) }
            }
            return found
        }.value
        scalars = result
        selected = nil
        isLoading = false
    }
}

private struct GlyphText: View {
    let face: FontFace
    let value: UInt32
    let size: Double

    var body: some View {
        if let descriptor = FontScanner.previewDescriptor(for: face), let scalar = Unicode.Scalar(value) {
            Text(String(scalar)).font(Font(CTFontCreateWithFontDescriptor(descriptor, size, nil))).lineLimit(1)
        }
    }
}

// MARK: - Eixos variáveis

private struct Axis: Identifiable {
    let id: Int
    let name: String
    let minimum: Double
    let maximum: Double
    let initial: Double

    var tag: String {
        let bytes = [UInt8((id >> 24) & 0xFF), UInt8((id >> 16) & 0xFF), UInt8((id >> 8) & 0xFF), UInt8(id & 0xFF)]
        return String(bytes: bytes, encoding: .ascii) ?? "\(id)"
    }
}

private struct AxesTab: View {
    @EnvironmentObject var prefs: PreviewPrefs
    let face: FontFace
    @State private var axes: [Axis] = []
    @State private var values: [Int: Double] = [:]

    var body: some View {
        if axes.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3").font(.system(size: 28)).foregroundStyle(T.muted)
                Text(tr("This font has no variable axes.")).font(.system(size: 14, weight: .semibold))
                Text(tr("Variable fonts store several weights/widths in a single file (e.g. Alkatra[wght].ttf)."))
                    .font(.system(size: 12)).foregroundStyle(T.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: face.id) { loadAxes() }
        } else {
            HStack(alignment: .top, spacing: 0) {
                preview.padding(24)
                Rectangle().fill(T.line).frame(width: 1)
                controls.frame(width: 320).padding(24)
            }
            .task(id: face.id) { loadAxes() }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(prefs.text.isEmpty ? face.family : prefs.text)
                .font(variedFont(size: 72)).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
            Text("ABCDEFGHIJKLMNOPQRSTUVWXYZ\nabcdefghijklmnopqrstuvwxyz\n0123456789 !?&@#")
                .font(variedFont(size: 28)).foregroundStyle(T.muted)
            Spacer()
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(tr("Available axes")).font(.system(size: 13, weight: .bold))
            ForEach(axes) { axis in
                LabeledSlider(label: "\(axis.name) (\(axis.tag))",
                              valueText: String(format: "%.0f", values[axis.id] ?? axis.initial),
                              value: Binding(get: { values[axis.id] ?? axis.initial }, set: { values[axis.id] = $0 }),
                              range: axis.minimum...max(axis.maximum, axis.minimum + 0.001))
            }
            Button(tr("Reset to default")) { values = Dictionary(uniqueKeysWithValues: axes.map { ($0.id, $0.initial) }) }
            Text(tr("The chosen positions apply to this preview only.")).font(.system(size: 11)).foregroundStyle(T.muted)
            Spacer()
        }
    }

    private func variedFont(size: Double) -> Font {
        guard let base = FontScanner.previewDescriptor(for: face) else { return .system(size: size) }
        let variation = Dictionary(uniqueKeysWithValues: values.map { (NSNumber(value: $0.key), NSNumber(value: $0.value)) })
        let descriptor = CTFontDescriptorCreateCopyWithAttributes(base, [kCTFontVariationAttribute: variation] as CFDictionary)
        return Font(CTFontCreateWithFontDescriptor(descriptor, size, nil))
    }

    private func loadAxes() {
        guard let descriptor = FontScanner.previewDescriptor(for: face) else { axes = []; return }
        let font = CTFontCreateWithFontDescriptor(descriptor, 12, nil)
        let raw = (CTFontCopyVariationAxes(font) as? [[String: Any]]) ?? []
        let parsed: [Axis] = raw.compactMap { dict in
            guard let id = (dict[kCTFontVariationAxisIdentifierKey as String] as? NSNumber)?.intValue else { return nil }
            let minimum = (dict[kCTFontVariationAxisMinimumValueKey as String] as? NSNumber)?.doubleValue ?? 0
            let maximum = (dict[kCTFontVariationAxisMaximumValueKey as String] as? NSNumber)?.doubleValue ?? 1
            let initial = (dict[kCTFontVariationAxisDefaultValueKey as String] as? NSNumber)?.doubleValue ?? minimum
            let name = (dict[kCTFontVariationAxisNameKey as String] as? String) ?? tr("Axis")
            return Axis(id: id, name: name, minimum: minimum, maximum: maximum, initial: initial)
        }
        axes = parsed
        values = Dictionary(uniqueKeysWithValues: parsed.map { ($0.id, $0.initial) })
    }
}
