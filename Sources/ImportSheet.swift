import SwiftUI

/// Adicionar fontes: copiar para a biblioteca, ou só indexar onde já estão.
struct ImportSheet: View {
    @EnvironmentObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var trashOriginals = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(tr("Add fonts")).font(.system(size: 22, weight: .bold))
            libraryFolder
            action(title: tr("Index the library folder"),
                   detail: tr("Reads the folder above and adds whatever Tipoteca does not know yet. Copies nothing. Use it after putting fonts in the folder through Finder."),
                   button: tr("Sync"), primary: true) { store.syncLibraryFolder(); dismiss() }
            action(title: tr("Index another folder without copying"),
                   detail: tr("The fonts stay where they are (e.g. another drive) and simply start showing up in the library."),
                   button: tr("Choose folder…")) { choose(copy: false) }
            VStack(alignment: .leading, spacing: 8) {
                action(title: tr("Copy to the library"),
                       detail: tr("Copies the chosen files into the library folder (e.g. external drive)."),
                       button: tr("Choose files or folders…")) { choose(copy: true) }
                Toggle(tr("After copying, move the originals to Trash"), isOn: $trashOriginals).toggleStyle(.checkbox)
                    .font(.system(size: 12))
                Button(tr("Copy everything from ~/Library/Fonts")) {
                    let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Fonts")
                    store.importFonts(from: [dir], copy: true, trashOriginals: trashOriginals); dismiss()
                }.font(.system(size: 12))
                Text(tr("Recoverable: nothing is permanently deleted. Apple system fonts are never touched."))
                    .font(.system(size: 11)).foregroundStyle(T.muted)
            }
            HStack { Spacer(); Button(tr("Close")) { dismiss() } }
        }
        .padding(24).frame(width: 600).background(T.bg).preferredColorScheme(.dark)
    }

    private var libraryFolder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr("Library folder")).font(.system(size: 12)).foregroundStyle(T.muted)
            HStack {
                Text(store.libraryDir.path).font(.system(size: 13)).lineLimit(1).truncationMode(.middle)
                Spacer()
                Button(tr("Change…")) { chooseLibraryFolder() }
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
        panel.message = copy ? tr("Choose fonts (.ttf .otf .ttc) or folders to copy")
                             : tr("Choose the font folder to index (without copying)")
        guard panel.runModal() == .OK else { return }
        store.importFonts(from: panel.urls, copy: copy, trashOriginals: copy && trashOriginals)
        dismiss()
    }

    private func chooseLibraryFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
        panel.message = tr("Choose the folder where the library will live")
        if panel.runModal() == .OK, let url = panel.url { store.libraryDir = url }
    }
}
