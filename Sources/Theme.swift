import SwiftUI
import AppKit

/// Paleta (modo escuro): fundo quase preto, verde-menta e lima.
enum T {
    static let bg = Color(hex: 0x070807)
    static let sidebar = Color(hex: 0x0A0D0B)
    static let panel = Color(hex: 0x0D120F)
    static let selected = Color(hex: 0x17231C)
    static let line = Color.white.opacity(0.09)
    static let lineStrong = Color.white.opacity(0.18)
    static let text = Color(hex: 0xF1F3F1)
    static let muted = Color(hex: 0x8A968F)
    static let green = Color(hex: 0x08EC99)
    static let lime = Color(hex: 0xC7FE83)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

/// Preferências de prévia compartilhadas por todas as listas.
final class PreviewPrefs: ObservableObject {
    @Published var text = tr("Made for creating")
    @Published var size: Double = 48
    @Published var tracking: Double = 0      // em
    @Published var weight: Int? = nil        // nil = padrão
    @Published var isList = true
}

// MARK: - Componentes

struct GreenButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 12, weight: .bold)) }
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 16).frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 5).fill(T.green))
        }.buttonStyle(.plain)
    }
}

struct ActivateDot: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().strokeBorder(isOn ? T.green : T.muted, lineWidth: 1.5).frame(width: 17, height: 17)
                if isOn {
                    Circle().fill(T.green).frame(width: 17, height: 17)
                    Image(systemName: "checkmark").font(.system(size: 8, weight: .heavy)).foregroundStyle(.black)
                }
            }
            .frame(width: 30, height: 30)
            .contentShape(Rectangle())   // o miolo transparente também recebe o clique
        }
        .buttonStyle(.plain)
        .help(isOn ? tr("Deactivate in the system") : tr("Activate in the system"))
    }
}

struct IconButton: View {
    let systemName: String
    var tint: Color = T.muted
    var help: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName).font(.system(size: 14)).foregroundStyle(tint)
                .frame(width: 30, height: 30).contentShape(Rectangle())
        }.buttonStyle(.plain).help(help)
    }
}

struct LabeledSlider: View {
    let label: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(label).font(.system(size: 12)).foregroundStyle(T.muted)
                Spacer()
                Text(valueText).font(.system(size: 12, weight: .bold))
            }
            Slider(value: $value, in: range).tint(T.green).controlSize(.small)
        }
    }
}

struct InputField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 10).frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 6).fill(T.panel))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(T.lineStrong))
    }
}

extension View {
    func inputField() -> some View { modifier(InputField()) }
}

/// Deixa a janela arrastável pelo fundo e com a barra de título transparente.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isMovableByWindowBackground = true
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(T.bg)
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}


/// Escolha de como as fontes ativas chegam aos apps (sistema ou pasta).
struct ActivationModeCard: View {
    @EnvironmentObject var store: LibraryStore
    var showsDetails = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("ACTIVATION MODE")).font(.system(size: 10.5, weight: .semibold)).tracking(0.6).foregroundStyle(T.muted)
            ForEach(ActivationMode.allCases, id: \.self) { mode in
                Button { store.setActivationMode(mode) } label: {
                    HStack(alignment: .top, spacing: 8) {
                        ZStack {
                            Circle().strokeBorder(store.activationMode == mode ? T.green : T.muted, lineWidth: 1.5).frame(width: 15, height: 15)
                            if store.activationMode == mode { Circle().fill(T.green).frame(width: 7, height: 7) }
                        }.padding(.top, 1)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.title).font(.system(size: 12, weight: .semibold))
                            if showsDetails {
                                Text(mode.detail).font(.system(size: 10.5)).foregroundStyle(T.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            liveStatus
        }
    }

    /// O que está valendo agora, em linguagem simples.
    private var liveStatus: some View {
        let isFolder = store.appliedMode == .folder
        let apps = store.artCraftApps
        let text: String
        if !apps.isEmpty && isFolder { text = tr("%@ open · fonts copied to ~/Library/Fonts/Tipoteca", apps.joined(separator: ", ")) }
        else if !apps.isEmpty { text = tr("%@ open · system activation", apps.joined(separator: ", ")) }
        else if isFolder { text = tr("Fonts copied to ~/Library/Fonts/Tipoteca") }
        else { text = tr("No ArtCraft app open · system activation") }
        return HStack(alignment: .top, spacing: 6) {
            Circle().fill(isFolder ? T.lime : T.green).frame(width: 7, height: 7).padding(.top, 4)
            Text(text).font(.system(size: 10.5)).foregroundStyle(T.muted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }
}
