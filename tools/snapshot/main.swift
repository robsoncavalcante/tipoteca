import SwiftUI
import AppKit

// Gera as imagens do README (docs/screenshots/*.png) sem abrir janela e sem tocar na sua biblioteca:
// usa uma biblioteca de demonstração feita com fontes que já vêm no macOS. Veja tools/snapshot.sh.

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/screenshots"
let fm = FileManager.default
let work = fm.temporaryDirectory.appendingPathComponent("tipoteca-snap-\(UUID().uuidString)", isDirectory: true)
try! fm.createDirectory(at: work, withIntermediateDirectories: true)
try! fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: work) }

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

func spin(_ seconds: Double) { RunLoop.current.run(until: Date().addingTimeInterval(seconds)) }

let demoFiles = ["Didot.ttc", "Futura.ttc", "Georgia.ttf", "Baskerville.ttc", "Copperplate.ttc", "GillSans.ttc",
                 "Hoefler Text.ttc", "Rockwell.ttc", "AmericanTypewriter.ttc", "Bodoni 72.ttc", "Trebuchet MS.ttf",
                 "SnellRoundhand.ttc", "Verdana.ttf", "Chalkduster.ttf"]
let urls = demoFiles.map { URL(fileURLWithPath: "/System/Library/Fonts/Supplemental/\($0)") }.filter { fm.fileExists(atPath: $0.path) }

var store: LibraryStore! = nil
MainActor.assumeIsolated {
    let first = LibraryStore(supportDirectory: work, startServices: false)
    first.importFonts(from: urls, copy: false, trashOriginals: false)
    while first.isBusy { spin(0.1) }
    spin(0.5)
    // Marca algumas famílias como ativas direto no arquivo (sem ativar de verdade no sistema).
    let stateURL = work.appendingPathComponent("library.json")
    var state = try! JSONDecoder().decode(LibraryState.self, from: Data(contentsOf: stateURL))
    let names = Set(state.faces.map(\.family))
    state.active = Set(["didot", "futura", "georgia", "baskerville"].filter { names.map { $0.lowercased() }.contains($0) })
    var collection = FontCollection(name: "Coffee Shop")
    collection.familyIDs = state.active
    state.collections = [collection]
    state.favorites = ["didot", "futura"]
    try! JSONEncoder().encode(state).write(to: stateURL)

    store = LibraryStore(supportDirectory: work, startServices: false)
    store.playground.defaultTitle = "didot"
    store.playground.defaultSupport = "futura"
    store.playground.defaultBody = "georgia"
    var composition = Templates.all.first { $0.id == "editorial" }!.make()
    composition.name = "Editorial"
    store.playground.current.name = "Visual identity"
    store.playground.current.client = "Coffee Shop"
    store.playground.current.compositions = [composition]
}

func render(_ name: String, selection: SidebarItem, size: CGSize = CGSize(width: 1240, height: 780)) {
    MainActor.assumeIsolated {
        let root = ContentView(initialSelection: selection).environmentObject(store).preferredColorScheme(.dark)
        let host = NSHostingView(rootView: root)
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        window.layoutIfNeeded()
        spin(1.2)
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { print("falhou: \(name)"); return }
        host.cacheDisplay(in: host.bounds, to: rep)
        let path = "\(outDir)/\(name).png"
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        print("gerado \(path)")
    }
}

render("biblioteca", selection: .all)
render("playground", selection: .playground)
