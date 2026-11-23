import SwiftUI

/// Adicionar fontes: copiar para a biblioteca, ou só indexar onde já estão.
struct ImportSheet: View {
    @EnvironmentObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var trashOriginals = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Adicionar fontes").font(.system(size: 22, weight: .bold))
            libraryFolder
            action(title: "Indexar a pasta da biblioteca",
                   detail: "Lê a pasta acima e adiciona o que o Tipoteca ainda não conhece. Não copia nada. Use depois de colocar fontes na pasta pelo Finder.",
                   button: "Sincronizar", primary: true) { store.syncLibraryFolder(); dismiss() }
            action(title: "Indexar outra pasta sem copiar",
                   detail: "As fontes continuam onde estão (ex.: outro HD) e só passam a aparecer na biblioteca.",
                   button: "Escolher pasta…") { choose(copy: false) }
            VStack(alignment: .leading, spacing: 8) {
                action(title: "Copiar para a biblioteca",
                       detail: "Copia os arquivos escolhidos para a pasta da biblioteca (ex.: HD externo).",
                       button: "Escolher arquivos ou pastas…") { choose(copy: true) }
                Toggle("Depois de copiar, mover os originais para a Lixeira", isOn: $trashOriginals).toggleStyle(.checkbox)
                    .font(.system(size: 12))
                Button("Copiar tudo de ~/Library/Fonts") {
                    let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Fonts")
                    store.importFonts(from: [dir], copy: true, trashOriginals: trashOriginals); dismiss()
                }.font(.system(size: 12))
                Text("Recuperável: nada é apagado em definitivo. Fontes do sistema da Apple nunca são tocadas.")
                    .font(.system(size: 11)).foregroundStyle(T.muted)
            }
            HStack { Spacer(); Button("Fechar") { dismiss() } }
        }
        .padding(24).frame(width: 600).background(T.bg).preferredColorScheme(.dark)
    }

    private var libraryFolder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pasta da biblioteca").font(.system(size: 12)).foregroundStyle(T.muted)
            HStack {
                Text(store.libraryDir.path).font(.system(size: 13)).lineLimit(1).truncationMode(.middle)
                Spacer()
                Button("Trocar…") { chooseLibraryFolder() }
            }.padding(12).background(RoundedRectangle(cornerRadius: 8).fill(T.panel))
        }
    }

    private func action(title: String, detail: String, button: String, primary: Bool = false,
                        run: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(T.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if primary { GreenButton(title: button, action: run) } else { Button(button, action: run) }
        }
    }

    private func choose(copy: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = copy; panel.canChooseDirectories = true; panel.allowsMultipleSelection = true
        panel.message = copy ? "Escolha fontes (.ttf .otf .ttc) ou pastas para copiar"
                             : "Escolha a pasta de fontes que será indexada (sem copiar)"
        guard panel.runModal() == .OK else { return }
        store.importFonts(from: panel.urls, copy: copy, trashOriginals: copy && trashOriginals)
        dismiss()
    }

    private func chooseLibraryFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
        panel.message = "Escolha a pasta onde a biblioteca ficará"
        if panel.runModal() == .OK, let url = panel.url { store.libraryDir = url }
    }
}
