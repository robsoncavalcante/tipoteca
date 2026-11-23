import SwiftUI
import UniformTypeIdentifiers

// MARK: - Janela principal

struct ContentView: View {
    @EnvironmentObject var store: LibraryStore
    @StateObject private var prefs = PreviewPrefs()
    @State private var selection: SidebarItem
    @State private var search = ""
    @State private var newCollection = ""
    @State private var showNewCollection = false
    @State private var showImport = false
    @State private var dropTargeted = false

    init(initialSelection: SidebarItem = .all) {
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selection: $selection, showNewCollection: $showNewCollection)
                .frame(width: 236)
            Rectangle().fill(T.line).frame(width: 1)
            VStack(spacing: 0) {
                if selection == .playground {
                    PlaygroundView()
                } else {
                    PageHeader(title: title, showImport: $showImport)
                    ControlsBar(search: $search)
                    content
                }
                FooterBar()
            }
        }
        .frame(minWidth: 1020, minHeight: 660)
        .background(T.bg)
        .foregroundStyle(T.text)
        .environmentObject(prefs)
        .preferredColorScheme(.dark)
        .background(WindowConfigurator())
        .sheet(isPresented: $showImport) { ImportSheet() }
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted, perform: handleDrop)
        .overlay { if dropTargeted { DropOverlay() } }
        .alert(tr("New collection"), isPresented: $showNewCollection) {
            TextField(tr("E.g. Client Coffee Shop"), text: $newCollection)
            Button(tr("Create")) { store.addCollection(named: newCollection); newCollection = "" }
            Button(tr("Cancel"), role: .cancel) { newCollection = "" }
        }
        .onAppear { store.loadGoogleCatalog() }
    }

    private var title: String {
        switch selection {
        case .all: return tr("All fonts")
        case .active: return tr("Active fonts")
        case .favorites: return tr("Favorites")
        case .google: return "Google Fonts"
        case .source: return "Adobe Fonts"
        case .playground: return "Playground"
        case .collection(let id): return store.state.collections.first { $0.id == id }?.name ?? tr("Collection")
        }
    }

    @ViewBuilder
    private var content: some View {
        if selection == .google {
            GoogleList(search: search)
        } else {
            let isAdobe = selection == .source(.adobe)
            FamilyList(items: filtered(store.families(for: selection)), readOnly: isAdobe, showAdobeNotice: isAdobe)
        }
    }

    private func filtered(_ items: [FontFamilyItem]) -> [FontFamilyItem] {
        let q = search.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? items : items.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var urls: [URL] = []
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url { urls.append(url) }
                group.leave()
            }
        }
        group.notify(queue: .main) { store.importFonts(from: urls, copy: true, trashOriginals: false) }
        return true
    }
}

// MARK: - Barra lateral

struct SidebarView: View {
    @EnvironmentObject var store: LibraryStore
    @Binding var selection: SidebarItem
    @Binding var showNewCollection: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Brand().padding(.top, 36).padding(.horizontal, 18).padding(.bottom, 22)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel(tr("YOUR LIBRARY"))
                    row(.all, "text.alignleft", tr("All fonts"), store.localFamilies.count)
                    row(.google, "globe", "Google Fonts", store.googleCatalog.count)
                    row(.active, "bolt", tr("Active fonts"), store.state.active.count)
                    row(.favorites, "heart", tr("Favorites"), store.state.favorites.count)
                    row(.source(.adobe), "a.circle", "Adobe Fonts", store.adobeFamilies.count)

                    SectionLabel(tr("TOOLS")).padding(.top, 22)
                    toolRow(.playground, "textformat.alt", "Playground")

                    HStack {
                        SectionLabel(tr("COLLECTIONS"))
                        Spacer()
                        IconButton(systemName: "plus", help: tr("New collection")) { showNewCollection = true }
                    }.padding(.top, 22)
                    ForEach(store.state.collections) { collection in
                        row(.collection(collection.id), "folder", collection.name, collection.familyIDs.count)
                            .contextMenu {
                                Button(tr("Activate collection")) { store.setCollection(collection.id, active: true) }
                                Button(tr("Deactivate collection")) { store.setCollection(collection.id, active: false) }
                                Divider()
                                Button(tr("Delete collection"), role: .destructive) { store.deleteCollection(collection.id) }
                            }
                    }
                    if store.state.collections.isEmpty {
                        Text(tr("Create collections per client or project to activate everything at once."))
                            .font(.system(size: 11)).foregroundStyle(T.muted).padding(.horizontal, 12).padding(.top, 4)
                    }
                    ActivationModeCard().padding(.horizontal, 12).padding(.top, 24).padding(.bottom, 16)
                }.padding(.horizontal, 10)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(T.sidebar)
    }

    private func toolRow(_ item: SidebarItem, _ icon: String, _ title: String) -> some View {
        let isSelected = selection == item
        return Button { selection = item } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 13)).frame(width: 18).foregroundStyle(isSelected ? T.green : T.muted)
                Text(title).font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                Spacer()
            }
            .padding(.horizontal, 10).frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 6).fill(isSelected ? T.selected : .clear))
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func row(_ item: SidebarItem, _ icon: String, _ title: String, _ count: Int) -> some View {
        let isSelected = selection == item
        return Button { selection = item } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 13)).frame(width: 18)
                    .foregroundStyle(isSelected ? T.green : T.muted)
                Text(title).font(.system(size: 13, weight: isSelected ? .semibold : .regular)).lineLimit(1)
                Spacer()
                Text("\(count)").font(.system(size: 11)).foregroundStyle(T.muted)
            }
            .padding(.horizontal, 10).frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 6).fill(isSelected ? T.selected : .clear))
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

struct Brand: View {
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 9)
                .fill(LinearGradient(colors: [T.green, T.lime], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 30, height: 30)
                .overlay(Text("T").font(.system(size: 18, weight: .black)).foregroundStyle(.black))
            Text("tipoteca").font(.system(size: 21, weight: .bold)).tracking(-0.5)
        }
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 10.5, weight: .semibold)).tracking(0.6)
            .foregroundStyle(T.muted).padding(.horizontal, 10).padding(.vertical, 8)
    }
}

// MARK: - Cabeçalho, controles e rodapé

struct PageHeader: View {
    let title: String
    @Binding var showImport: Bool

    var body: some View {
        HStack {
            Text(title).font(.system(size: 28, weight: .bold)).tracking(-0.6).lineLimit(1)
            Spacer()
            GreenButton(title: tr("Add fonts"), icon: "plus") { showImport = true }
        }
        .padding(.horizontal, 28).padding(.top, 34).padding(.bottom, 14)
    }
}

struct ControlsBar: View {
    @EnvironmentObject var prefs: PreviewPrefs
    @Binding var search: String

    private let weights: [(String, Int?)] = [
        (tr("Default"), nil), ("Light 300", 300), ("Regular 400", 400), ("Medium 500", 500),
        ("SemiBold 600", 600), ("Bold 700", 700), ("Black 900", 900)
    ]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(T.muted)
                    TextField(tr("Search fonts"), text: $search).textFieldStyle(.plain)
                }
                .frame(width: 280).inputField()
                Spacer()
                viewToggle
            }
            HStack(spacing: 10) {
                Image(systemName: "textformat").foregroundStyle(T.muted)
                Text(tr("Preview")).font(.system(size: 12)).foregroundStyle(T.muted)
                TextField(tr("Type the preview text"), text: $prefs.text).inputField()
            }
            HStack(alignment: .bottom, spacing: 24) {
                LabeledSlider(label: tr("Size"), valueText: "\(Int(prefs.size)) px", value: $prefs.size, range: 14...140)
                LabeledSlider(label: tr("Spacing"),
                              valueText: abs(prefs.tracking) < 0.005 ? "Normal" : String(format: "%+.2f em", prefs.tracking),
                              value: $prefs.tracking, range: -0.1...0.4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Weight")).font(.system(size: 12)).foregroundStyle(T.muted)
                    Picker("", selection: $prefs.weight) {
                        ForEach(weights, id: \.0) { Text($0.0).tag($0.1) }
                    }.labelsHidden().frame(width: 150)
                }
            }
        }
        .padding(.horizontal, 28).padding(.bottom, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(T.line).frame(height: 1) }
    }

    private var viewToggle: some View {
        HStack(spacing: 2) {
            toggleButton("list.bullet", isOn: prefs.isList) { prefs.isList = true }
            toggleButton("square.grid.2x2", isOn: !prefs.isList) { prefs.isList = false }
        }
    }

    private func toggleButton(_ icon: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 13))
                .foregroundStyle(isOn ? .black : T.muted)
                .frame(width: 32, height: 30)
                .background(RoundedRectangle(cornerRadius: 5).fill(isOn ? T.text : .clear))
        }.buttonStyle(.plain)
    }
}

struct FooterBar: View {
    @EnvironmentObject var store: LibraryStore

    var body: some View {
        HStack(spacing: 8) {
            if store.isBusy { ProgressView().controlSize(.small) }
            Text(store.status.isEmpty
                 ? tr("Local library · %@", store.libraryDir.path)
                 : store.status)
                .font(.system(size: 11)).foregroundStyle(T.muted).lineLimit(1).truncationMode(.middle)
            Spacer()
            Button(tr("Deactivate all")) { store.deactivateAll() }
                .buttonStyle(.plain).font(.system(size: 11, weight: .semibold))
                .foregroundStyle(store.state.active.isEmpty ? T.muted : T.text)
                .disabled(store.state.active.isEmpty)
            Text(tr("%ld styles · %ld families", store.state.faces.count, store.localFamilies.count))
                .font(.system(size: 11)).foregroundStyle(T.muted)
        }
        .padding(.horizontal, 28).frame(height: 30)
        .overlay(alignment: .top) { Rectangle().fill(T.line).frame(height: 1) }
    }
}

struct DropOverlay: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16).strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10]))
            .foregroundStyle(T.green).background(T.bg.opacity(0.85)).padding(14)
            .overlay(Text(tr("Drop fonts or folders to add")).font(.system(size: 20, weight: .bold)))
            .allowsHitTesting(false)
    }
}
