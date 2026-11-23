import Foundation

// Testes do Tipoteca. Rode com ./tests/run.sh (compila as fontes do app, sem a janela, junto com este arquivo).
// Não toca na biblioteca real: tudo acontece em pastas temporárias.

var failures = 0
var passed = 0

func check(_ condition: @autoclosure () -> Bool, _ name: String, file: String = #file, line: Int = #line) {
    if condition() { passed += 1; print("  ok  \(name)") }
    else { failures += 1; print("  FALHOU  \(name)  (linha \(line))") }
}

func section(_ title: String) { print("\n\(title)") }

let fm = FileManager.default
let tmp = fm.temporaryDirectory.appendingPathComponent("tipoteca-tests-\(UUID().uuidString)", isDirectory: true)
try! fm.createDirectory(at: tmp, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: tmp) }

func face(_ style: String, family: String = "Demo") -> FontFace {
    FontFace(path: "/tmp/\(family)-\(style).ttf", family: family, style: style, postScript: "\(family)-\(style)", source: .local)
}

// MARK: - Modelos

section("Modelos")
do {
    let family = FontFamilyItem(name: "Demo", faces: [face("Italic"), face("Light"), face("Regular"), face("Bold"), face("Bold Italic")])
    check(family.preview.style == "Regular", "a prévia é o estilo Regular")
    check(family.face(weight: 700).style == "Bold", "peso 700 escolhe Bold (e não Bold Italic)")
    check(family.face(weight: 300).style == "Light", "peso 300 escolhe Light")
    check(family.face(weight: 900).style == "Regular", "peso sem estilo correspondente cai na prévia")
    check(family.face(weight: nil).style == "Regular", "sem peso usa a prévia")
    check(FontFamilyItem.key("Open Sans") == "open sans", "chave da família é minúscula")
    check(FontFace(path: "/a.ttf", family: "A", style: "Regular", postScript: "A-Regular", source: .local).id == "/a.ttf#A-Regular", "id do estilo = caminho + PostScript")
}

section("Composições e projetos")
do {
    let starter = Composition.starter
    let data = try! JSONEncoder().encode(starter)
    let back = try! JSONDecoder().decode(Composition.self, from: data)
    check(back == starter, "composição sobrevive a codificar e decodificar")

    let minimal = #"{"name":"Antiga","blocks":[]}"#.data(using: .utf8)!
    let old = try? JSONDecoder().decode(Composition.self, from: minimal)
    check(old != nil && old!.isDark && old!.symbolSize == 72 && old!.symbolGap == 18, "arquivo antigo (sem campos novos) ainda abre, com valores padrão")

    var playground = PlaygroundState.starter
    check(playground.projects.count == 1 && !playground.compositions.isEmpty, "estado inicial tem 1 projeto com composições")
    playground.defaultTitle = "poppins"
    let resolved = playground.resolved(playground.compositions[0])
    check(resolved.blocks[0].familyID == "poppins", "fonte padrão do Título vale para blocos sem fonte própria")
    check(resolved.blocks[1].familyID == nil, "bloco Apoio sem fonte padrão continua sem fonte")

    var withOwn = playground.compositions[0]
    withOwn.blocks[0].familyID = "inter"
    check(playground.resolved(withOwn).blocks[0].familyID == "inter", "fonte própria do bloco não é sobrescrita")

    let encoded = try! JSONEncoder().encode(playground)
    let decoded = try! JSONDecoder().decode(PlaygroundState.self, from: encoded)
    check(decoded.projects.count == 1 && decoded.defaultTitle == "poppins", "estado do Playground sobrevive a codificar e decodificar")

    let legacy = #"{"compositions":[{"name":"A","blocks":[]}],"defaultTitle":"inter"}"#.data(using: .utf8)!
    let migrated = try? JSONDecoder().decode(PlaygroundState.self, from: legacy)
    check(migrated?.projects.count == 1 && migrated?.defaultTitle == "inter", "formato antigo (sem projetos) vira 1 projeto")
}

section("Modelos prontos")
do {
    check(Templates.all.count >= 9, "há pelo menos 9 modelos prontos")
    check(Set(Templates.all.map(\.id)).count == Templates.all.count, "ids dos modelos são únicos")
    check(Templates.all.allSatisfy { !$0.make().blocks.isEmpty }, "todo modelo tem blocos")
    check(Templates.all.allSatisfy { $0.make().blocks.allSatisfy { ["Título", "Apoio", "Corpo"].contains($0.label) } },
          "blocos usam só os rótulos internos Título/Apoio/Corpo")
}

// MARK: - Leitura de fontes

section("Leitura de fontes")
do {
    let source = URL(fileURLWithPath: "/System/Library/Fonts/Supplemental/Arial.ttf")
    let folder = tmp.appendingPathComponent("fontes", isDirectory: true)
    try! fm.createDirectory(at: folder, withIntermediateDirectories: true)
    let copy = folder.appendingPathComponent("Arial.ttf")
    try? fm.copyItem(at: source, to: copy)
    fm.createFile(atPath: folder.appendingPathComponent("._Arial.ttf").path, contents: Data([0, 1, 2]))
    fm.createFile(atPath: folder.appendingPathComponent("leia-me.txt").path, contents: Data("oi".utf8))

    let found = FontScanner.fontFiles(in: [folder])
    check(found.map(\.lastPathComponent) == ["Arial.ttf"], "ignora arquivos ._ e que não são fonte")
    let faces = FontScanner.faces(at: copy, source: .local)
    check(faces.count >= 1 && faces[0].family == "Arial", "lê a família de um arquivo de fonte")
    check(FontScanner.faces(at: folder.appendingPathComponent("._Arial.ttf"), source: .local).isEmpty, "arquivo ._ não vira fonte")
}

// MARK: - Biblioteca (pasta temporária)

section("Biblioteca")
MainActor.assumeIsolated {
    let support = tmp.appendingPathComponent("support", isDirectory: true)
    let store = LibraryStore(supportDirectory: support, startServices: false)
    check(store.state.faces.isEmpty, "biblioteca nova começa vazia")
    store.addCollection(named: "Cliente X")
    check(store.state.collections.count == 1 && store.state.collections[0].name == "Cliente X", "cria coleção")
    store.addCollection(named: "   ")
    check(store.state.collections.count == 1, "nome de coleção em branco é ignorado")
    store.deleteCollection(store.state.collections[0].id)
    check(store.state.collections.isEmpty, "exclui coleção")
    check(store.libraryDir.path.hasPrefix(support.path), "usa a pasta de teste e não a biblioteca real")
}

// MARK: - Textos (tr)

section("Textos")
do {
    check(tr("Hello") == "Hello", "sem tradução devolve a chave")
    check(tr("%ld families", 3) == "3 families", "tr aplica argumentos")
    check(trPlural(1, "%ld file", "%ld files") == "1 file", "plural: singular")
    check(trPlural(2, "%ld file", "%ld files") == "2 files", "plural: plural")
    check(trPlural(1, "%ld font for “%@”", "%ld fonts for “%@”", "X") == "1 font for “X”", "plural com argumento extra")
    check(blockLabel("Título") == "Title" && blockLabel("Corpo") == "Body" && blockLabel("Outro") == "Outro", "rótulos de bloco são traduzidos só na exibição")
}

print("\n\(passed) passaram, \(failures) falharam")
exit(failures == 0 ? 0 : 1)
