import SwiftUI

// MARK: - Operações de projeto (na biblioteca)

extension LibraryStore {
    private func clean(_ text: String, fallback: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    var clients: [String] {
        Array(Set(playground.projects.map(\.client))).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func projects(of client: String) -> [Project] {
        playground.projects.filter { $0.client == client }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func selectProject(_ id: UUID) { playground.currentID = id }

    /// Novo projeto: herda as fontes padrão do atual para não começar do zero.
    func addProject(client: String, name: String, notes: String) {
        var project = Project(client: clean(client, fallback: tr("No client")), name: clean(name, fallback: tr("New project")),
                              notes: notes, compositions: [.starter])
        project.defaultTitle = playground.defaultTitle
        project.defaultSupport = playground.defaultSupport
        project.defaultBody = playground.defaultBody
        playground.projects.append(project)
        playground.currentID = project.id
        status = tr("Project “%@” created for %@.", project.name, project.client)
    }

    func updateCurrentProject(client: String, name: String, notes: String) {
        playground.current.client = clean(client, fallback: tr("No client"))
        playground.current.name = clean(name, fallback: tr("Project"))
        playground.current.notes = notes
        playground.current.updatedAt = Date()
    }

    func duplicateCurrentProject() {
        var copy = playground.current
        copy.id = UUID()
        copy.name += tr(" (copy)")
        copy.updatedAt = Date()
        copy.compositions = copy.compositions.map { Self.freshIDs($0) }
        playground.projects.append(copy)
        playground.currentID = copy.id
        status = tr("Project duplicated.")
    }

    func deleteCurrentProject() {
        guard playground.projects.count > 1 else { return }
        let id = playground.currentID
        playground.projects.removeAll { $0.id == id }
        playground.currentID = playground.projects[0].id
        status = tr("Project deleted.")
    }

    /// Famílias usadas em qualquer composição do projeto (já com as fontes padrão aplicadas).
    func familiesOfCurrentProject() -> [FontFamilyItem] {
        let ids = Set(playground.compositions.flatMap { playground.resolved($0).blocks.compactMap(\.familyID) })
        return localFamilies.filter { ids.contains($0.id) }
    }

    func setCurrentProjectFonts(active: Bool) {
        let families = familiesOfCurrentProject()
        guard !families.isEmpty else { status = tr("This project does not use any library font yet."); return }
        let pending = families.filter { isActive($0) != active }
        pending.forEach { toggleActive($0) }
        status = pending.isEmpty
            ? (active ? tr("The project fonts were already active.") : tr("The project fonts were already deactivated."))
            : (active ? trPlural(pending.count, "%ld font activated for project “%@”.", "%ld fonts activated for project “%@”.", playground.current.name) : trPlural(pending.count, "%ld font deactivated for project “%@”.", "%ld fonts deactivated for project “%@”.", playground.current.name))
    }

    static func freshIDs(_ composition: Composition) -> Composition {
        var copy = composition
        copy.id = UUID()
        copy.blocks = composition.blocks.map { var block = $0; block.id = UUID(); return block }
        return copy
    }
}

// MARK: - Menu do projeto (cabeçalho do Playground)

struct ProjectMenuButton: View {
    @EnvironmentObject var store: LibraryStore
    @State private var isOpen = false
    @State private var sheetMode: ProjectSheet.Mode?
    @State private var confirmDelete = false

    var body: some View {
        Button { isOpen.toggle() } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder").foregroundStyle(T.green)
                Text(store.playground.current.client).foregroundStyle(T.muted)
                Text("·").foregroundStyle(T.muted)
                Text(store.playground.current.name).fontWeight(.semibold)
                Image(systemName: "chevron.down").font(.system(size: 9)).foregroundStyle(T.muted)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 12).frame(height: 30)
            .background(Capsule().fill(T.panel))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isOpen, arrowEdge: .bottom) { panel }
        .sheet(item: $sheetMode) { ProjectSheet(mode: $0) }
        .confirmationDialog(tr("Delete project “%@”?", store.playground.current.name), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(tr("Delete project"), role: .destructive) { store.deleteCurrentProject() }
            Button(tr("Cancel"), role: .cancel) {}
        } message: {
            Text(tr("This project's compositions and notes will be deleted. Library fonts are not affected."))
        }
    }

    // MARK: Painel

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(store.clients, id: \.self) { client in
                        Text(client.uppercased()).font(.system(size: 10.5, weight: .semibold)).tracking(0.6)
                            .foregroundStyle(T.muted).padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 4)
                        ForEach(store.projects(of: client)) { project in projectRow(project) }
                    }
                }.padding(.bottom, 8)
            }.frame(maxHeight: 280)
            Rectangle().fill(T.line).frame(height: 1)
            VStack(alignment: .leading, spacing: 0) {
                action("plus", tr("New project…")) { sheetMode = .new }
                action("pencil", tr("Edit project details…")) { sheetMode = .edit }
                action("doc.on.doc", tr("Duplicate project")) { store.duplicateCurrentProject() }
                action("bolt", tr("Activate the project fonts")) { store.setCurrentProjectFonts(active: true) }
                action("bolt.slash", tr("Deactivate the project fonts")) { store.setCurrentProjectFonts(active: false) }
                action("trash", tr("Delete project…"), enabled: store.playground.projects.count > 1) { confirmDelete = true }
            }.padding(.vertical, 6)
        }
        .frame(width: 320).background(T.bg).foregroundStyle(T.text).preferredColorScheme(.dark)
    }

    private func projectRow(_ project: Project) -> some View {
        let isCurrent = project.id == store.playground.currentID
        return Button { store.selectProject(project.id); isOpen = false } label: {
            HStack(spacing: 8) {
                Image(systemName: isCurrent ? "checkmark" : "circle.fill")
                    .font(.system(size: isCurrent ? 11 : 4)).foregroundStyle(isCurrent ? T.green : T.muted).frame(width: 14)
                Text(project.name).font(.system(size: 13, weight: isCurrent ? .semibold : .regular)).lineLimit(1)
                Spacer()
                Text("\(project.compositions.count)").font(.system(size: 11)).foregroundStyle(T.muted)
            }
            .padding(.horizontal, 14).frame(height: 30)
            .background(isCurrent ? T.selected : .clear)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func action(_ icon: String, _ title: String, enabled: Bool = true, run: @escaping () -> Void) -> some View {
        Button { isOpen = false; run() } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 12)).frame(width: 16).foregroundStyle(T.muted)
                Text(title).font(.system(size: 13))
                Spacer()
            }
            .padding(.horizontal, 14).frame(height: 30).contentShape(Rectangle())
            .opacity(enabled ? 1 : 0.4)
        }.buttonStyle(.plain).disabled(!enabled)
    }
}

// MARK: - Criar / editar projeto

struct ProjectSheet: View {
    enum Mode: String, Identifiable { case new, edit; var id: String { rawValue } }

    let mode: Mode
    @EnvironmentObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var client = ""
    @State private var name = ""
    @State private var notes = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(mode == .new ? tr("New project") : tr("Project details")).font(.system(size: 22, weight: .bold))
            VStack(alignment: .leading, spacing: 6) {
                Text(tr("Client")).font(.system(size: 12)).foregroundStyle(T.muted)
                HStack(spacing: 8) {
                    TextField(tr("E.g. Coffee Shop"), text: $client).inputField()
                    if !store.clients.isEmpty {
                        Menu(tr("Existing")) { ForEach(store.clients, id: \.self) { c in Button(c) { client = c } } }
                            .menuStyle(.borderlessButton).fixedSize()
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(tr("Project")).font(.system(size: 12)).foregroundStyle(T.muted)
                TextField(tr("E.g. Visual identity"), text: $name).inputField()
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(tr("Notes")).font(.system(size: 12)).foregroundStyle(T.muted)
                TextEditor(text: $notes).font(.system(size: 13)).scrollContentBackground(.hidden)
                    .padding(8).frame(height: 110)
                    .background(RoundedRectangle(cornerRadius: 6).fill(T.panel))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(T.lineStrong))
            }
            if mode == .new {
                Text(tr("The new project starts with the same default fonts as the current project."))
                    .font(.system(size: 11)).foregroundStyle(T.muted)
            }
            HStack {
                Spacer()
                Button(tr("Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                GreenButton(title: mode == .new ? tr("Create project") : tr("Save")) {
                    if mode == .new { store.addProject(client: client, name: name, notes: notes) }
                    else { store.updateCurrentProject(client: client, name: name, notes: notes) }
                    dismiss()
                }
            }
        }
        .padding(24).frame(width: 520).background(T.bg).preferredColorScheme(.dark)
        .onAppear {
            guard mode == .edit else { return }
            client = store.playground.current.client
            name = store.playground.current.name
            notes = store.playground.current.notes
        }
    }
}

// MARK: - Notas do projeto

struct ProjectNotesCard: View {
    @EnvironmentObject var store: LibraryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr("Project notes")).font(.system(size: 13, weight: .bold))
            TextEditor(text: Binding(
                get: { store.playground.current.notes },
                set: { store.playground.current.notes = $0 }))
                .font(.system(size: 13)).scrollContentBackground(.hidden)
                .padding(8).frame(minHeight: 90)
                .background(RoundedRectangle(cornerRadius: 6).fill(T.bg))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(T.lineStrong))
            Text(tr("E.g. the client approved option 2; avoid script fonts; official palette #0B3D2E."))
                .font(.system(size: 11)).foregroundStyle(T.muted)
        }
        .padding(14).background(RoundedRectangle(cornerRadius: 10).fill(T.panel))
    }
}
