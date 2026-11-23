import SwiftUI

@main
struct TipotecaApp: App {
    @StateObject private var store = LibraryStore()

    var body: some Scene {
        // Janela única: o item da barra de menus reabre esta mesma janela.
        Window("Tipoteca", id: "main") {
            ContentView().environmentObject(store)
        }
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra {
            MenuBarContent().environmentObject(store)
        } label: {
            MenuBarLabel().environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }
}
