import SwiftUI
import CoreText

/// Nome da família escrito com a própria fonte (lida do arquivo, sem depender de a fonte estar registrada).
struct NameInFont: View {
    let face: FontFace
    let size: Double

    var body: some View {
        if let descriptor = FontScanner.previewDescriptor(for: face) {
            Text(face.family).font(Font(CTFontCreateWithFontDescriptor(descriptor, size, nil)))
        } else {
            Text(face.family).font(.system(size: size))
        }
    }
}

/// Ícone da barra de menus: quadrado arredondado com o "T" vazado (imagem "template": o macOS pinta de claro/escuro).
enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 4.5, yRadius: 4.5).fill()
            let glyph = NSAttributedString(string: "T", attributes: [
                .font: NSFont.systemFont(ofSize: 12.5, weight: .black),
                .foregroundColor: NSColor.black
            ])
            let box = glyph.size()
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            glyph.draw(at: NSPoint(x: rect.midX - box.width / 2, y: rect.midY - box.height / 2))
            return true
        }
        image.isTemplate = true
        return image
    }()
}

struct MenuBarLabel: View {
    @EnvironmentObject var store: LibraryStore

    var body: some View {
        let count = store.state.active.count
        HStack(spacing: 4) {
            Image(nsImage: MenuBarIcon.image)
            if count > 0 { Text("\(count)") }
        }
    }
}

/// Painel da barra de menus: busca, lista de toda a biblioteca e check para ativar/desativar.
struct MenuBarContent: View {
    @EnvironmentObject var store: LibraryStore
    @Environment(\.openWindow) private var openWindow
    @State private var query = ""
    @State private var onlyActive = false
    @State private var loginState = LoginItem.state
    @State private var loginMessage: String?

    private let listHeight: CGFloat = 340   // altura fixa: ScrollView sem altura fixa colapsa em painel de menu

    var body: some View {
        let all = store.localFamilies
        let activeCount = all.filter { store.isActive($0) }.count
        let shown = visible(all)

        VStack(alignment: .leading, spacing: 0) {
            header(active: activeCount, total: all.count)
            divider
            controls(active: activeCount, total: all.count)
            divider
            list(shown, totalInLibrary: all.count)
            divider
            loginRow
            divider
            ActivationModeCard(showsDetails: false).padding(.horizontal, 14).padding(.vertical, 10)
            divider
            footer
        }
        .frame(width: 340)
        .background(T.bg)
        .foregroundStyle(T.text)
        .preferredColorScheme(.dark)
    }

    private var divider: some View { Rectangle().fill(T.line).frame(height: 1) }

    private func visible(_ all: [FontFamilyItem]) -> [FontFamilyItem] {
        var result = onlyActive ? all.filter { store.isActive($0) } : all
        let q = query.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty { result = result.filter { $0.name.localizedCaseInsensitiveContains(q) } }
        return result   // ordem alfabética fixa: a linha não "pula" ao ativar
    }

    private func header(active: Int, total: Int) -> some View {
        HStack(spacing: 8) {
            Circle().fill(active == 0 ? T.muted : T.green).frame(width: 8, height: 8)
            Text(active == 0 ? tr("No active fonts") : trPlural(active, "%ld active family", "%ld active families"))
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text(tr("%ld in library", total)).font(.system(size: 11)).foregroundStyle(T.muted)
        }.padding(14)
    }

    private func controls(active: Int, total: Int) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(T.muted)
                TextField(tr("Search library"), text: $query).textFieldStyle(.plain)
            }.inputField()
            HStack(spacing: 6) {
                chip(tr("All %ld", total), isOn: !onlyActive) { onlyActive = false }
                chip(tr("Active %ld", active), isOn: onlyActive) { onlyActive = true }
                Spacer()
            }
        }.padding(12)
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isOn ? .black : T.muted)
                .padding(.horizontal, 10).frame(height: 24)
                .background(Capsule().fill(isOn ? T.text : T.panel))
        }.buttonStyle(.plain)
    }

    @ViewBuilder
    private func list(_ items: [FontFamilyItem], totalInLibrary: Int) -> some View {
        if items.isEmpty {
            Text(totalInLibrary == 0 ? tr("The library is empty. Add fonts in the main window.")
                                     : tr("No fonts found."))
                .font(.system(size: 12)).foregroundStyle(T.muted)
                .multilineTextAlignment(.center).padding(24)
                .frame(maxWidth: .infinity).frame(height: listHeight)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) { ForEach(items) { row($0) } }
            }.frame(height: listHeight)
        }
    }

    private func row(_ family: FontFamilyItem) -> some View {
        let isOn = store.isActive(family)
        return Button { store.toggleActive(family) } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4).strokeBorder(isOn ? T.green : T.muted, lineWidth: 1.5)
                        .background(RoundedRectangle(cornerRadius: 4).fill(isOn ? T.green : .clear))
                        .frame(width: 17, height: 17)
                    if isOn { Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(.black) }
                }
                NameInFont(face: family.preview, size: 16).lineLimit(1)
                Text("\(family.faces.count)").font(.system(size: 10)).foregroundStyle(T.muted)
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 14).frame(height: 36)
            .background(isOn ? T.selected : .clear)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private var loginRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(tr("Open at login")).font(.system(size: 12))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { loginState == .enabled || loginState == .needsApproval },
                    set: { on in
                        loginMessage = LoginItem.set(enabled: on)
                        loginState = LoginItem.state
                    })
                ).toggleStyle(.switch).controlSize(.small).labelsHidden().tint(T.green)
            }
            if loginState == .needsApproval {
                Button(tr("Approve in System Settings…")) { LoginItem.openSystemSettings() }
                    .buttonStyle(.plain).font(.system(size: 11, weight: .semibold)).foregroundStyle(T.lime)
            }
            if let loginMessage { Text(loginMessage).font(.system(size: 11)).foregroundStyle(T.muted) }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .onAppear { loginState = LoginItem.state }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button(tr("Open Tipoteca")) {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            Button(tr("Deactivate all")) { store.deactivateAll() }
                .disabled(store.state.active.isEmpty)
            Spacer()
            Button(tr("Quit")) { NSApp.terminate(nil) }
        }
        .buttonStyle(.plain).font(.system(size: 12, weight: .semibold))
        .padding(14)
    }
}
