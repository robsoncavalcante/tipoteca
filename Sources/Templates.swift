import SwiftUI

/// Modelo pronto: uma composição de partida. As fontes vêm das "Fontes padrão" do projeto.
struct CompositionTemplate: Identifiable {
    let id: String
    let name: String
    let summary: String
    let make: () -> Composition
}

enum Templates {
    private static func block(_ label: String, _ text: String, size: Double, weight: Int? = nil,
                              tracking: Double = 0, line: Double = 1.2) -> TextBlock {
        TextBlock(label: label, text: text, familyID: nil, weight: weight, size: size, tracking: tracking, lineHeight: line)
    }

    private static func composition(_ name: String, dark: Bool = true, background: String? = nil, ink: String? = nil,
                                    blocks: [TextBlock]) -> Composition {
        var c = Composition(name: name, isDark: dark, blocks: blocks)
        c.backgroundHex = background
        c.inkHex = ink
        return c
    }

    static let all: [CompositionTemplate] = [
        CompositionTemplate(id: "marca", name: "Marca", summary: "Nome + descritor. Adicione o símbolo na linha Símbolo.") {
            composition("Marca", blocks: [
                block("Título", "Café da Zi!", size: 84, weight: 700, tracking: -0.02, line: 1.0),
                block("Apoio", "CAFETERIA DE BAIRRO", size: 16, weight: 500, tracking: 0.28)
            ])
        },
        CompositionTemplate(id: "cartaz", name: "Cartaz", summary: "Título gigante, data e chamada.") {
            composition("Cartaz", background: "111111", ink: "F4F1EA", blocks: [
                block("Título", "FESTIVAL DE VERÃO", size: 88, weight: 900, tracking: -0.02, line: 0.95),
                block("Apoio", "Sábado, 14 de dezembro · Praça Central", size: 22, weight: 500),
                block("Corpo", "Entrada gratuita. Música, comida e arte local o dia todo.", size: 15, line: 1.5)
            ])
        },
        CompositionTemplate(id: "instagram", name: "Post de Instagram", summary: "Frase forte em fundo de cor.") {
            composition("Post de Instagram", dark: false, background: "C7FE83", ink: "0A0D0B", blocks: [
                block("Título", "Pare de adiar.\nComece hoje.", size: 72, weight: 800, tracking: -0.02, line: 1.0),
                block("Apoio", "Três passos simples para organizar suas fontes", size: 22, weight: 500),
                block("Corpo", "@suamarca", size: 15, weight: 600, tracking: 0.04)
            ])
        },
        CompositionTemplate(id: "editorial", name: "Editorial", summary: "Revista: título, linha fina e texto corrido.") {
            composition("Editorial", dark: false, background: "F6F1E7", ink: "1B1712", blocks: [
                block("Título", "O mundo lá fora que lute", size: 60, weight: 700, tracking: -0.01, line: 1.05),
                block("Apoio", "Aqui dentro o café é saboroso e a sua paz é sagrada.", size: 24, line: 1.25),
                block("Corpo", "Na cafeteria, a regra é simples: o mundo lá fora sempre pode esperar por quinze minutos. Teste como o título conversa com o parágrafo, o ritmo das linhas e a hierarquia da página.", size: 16, line: 1.6)
            ])
        },
        CompositionTemplate(id: "site", name: "Site (hero)", summary: "Título de chamada, subtítulo e preço.") {
            composition("Site (hero)", blocks: [
                block("Título", "Peça café especial", size: 64, weight: 700, tracking: -0.02, line: 1.05),
                block("Apoio", "Torrado na semana, entregue na sua porta.", size: 22),
                block("Corpo", "Assinaturas a partir de R$ 39,90 por mês. Cancele quando quiser.", size: 16, line: 1.5)
            ])
        },
        CompositionTemplate(id: "citacao", name: "Citação", summary: "Frase em destaque e autor.") {
            composition("Citação", background: "0B3D2E", ink: "F4F1EA", blocks: [
                block("Título", "“Design é pensar\ntornado visível.”", size: 56, weight: 600, tracking: -0.01, line: 1.12),
                block("Apoio", "— SAUL BASS", size: 15, weight: 600, tracking: 0.2)
            ])
        },
        CompositionTemplate(id: "convite", name: "Convite", summary: "Chamada pequena, nome grande e detalhes.") {
            composition("Convite", dark: false, background: "FBEFE6", ink: "3A1F14", blocks: [
                block("Apoio", "VOCÊ ESTÁ CONVIDADO", size: 14, weight: 600, tracking: 0.3),
                block("Título", "Aniversário da Zi", size: 68, weight: 700, tracking: -0.01, line: 1.05),
                block("Corpo", "Sábado, 20h · Rua das Flores, 123\nConfirme presença até quinta.", size: 17, line: 1.7)
            ])
        },
        CompositionTemplate(id: "cardapio", name: "Cardápio", summary: "Seção, itens e preços.") {
            composition("Cardápio", blocks: [
                block("Título", "Cardápio", size: 60, weight: 700, tracking: -0.02, line: 1.0),
                block("Apoio", "CAFÉS", size: 15, weight: 600, tracking: 0.25),
                block("Corpo", "Espresso · R$ 7\nCapuccino · R$ 12\nLatte · R$ 14\nCoado do dia · R$ 10", size: 19, line: 1.8)
            ])
        },
        CompositionTemplate(id: "hierarquia", name: "Hierarquia de texto", summary: "Título, apoio e corpo para testar pares de fontes.") {
            Composition.starter
        }
    ]
}

// MARK: - Galeria

struct TemplateGallery: View {
    @EnvironmentObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    let onUse: (Composition) -> Void

    private let columns = [GridItem(.adaptive(minimum: 230), spacing: 18, alignment: .top)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Modelos").font(.system(size: 24, weight: .bold))
                    Text("Usam as fontes padrão do projeto. Depois é só trocar fonte, texto e cores.")
                        .font(.system(size: 12)).foregroundStyle(T.muted)
                }
                Spacer()
                Button("Fechar") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(24)
            Rectangle().fill(T.line).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !store.playground.userTemplates.isEmpty {
                        Text("Meus modelos").font(.system(size: 13, weight: .bold))
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                            ForEach(store.playground.userTemplates) { template in
                                card(template, name: template.name, summary: "Salvo por você")
                                    .contextMenu {
                                        Button("Excluir modelo", role: .destructive) {
                                            store.playground.userTemplates.removeAll { $0.id == template.id }
                                        }
                                    }
                            }
                        }
                    }
                    Text("Modelos prontos").font(.system(size: 13, weight: .bold))
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                        ForEach(Templates.all) { template in
                            card(template.make(), name: template.name, summary: template.summary)
                        }
                    }
                }.padding(24)
            }
        }
        .frame(width: 820, height: 640).background(T.bg).foregroundStyle(T.text).preferredColorScheme(.dark)
    }

    private func card(_ composition: Composition, name: String, summary: String) -> some View {
        Button { onUse(composition); dismiss() } label: {
            VStack(alignment: .leading, spacing: 8) {
                CompositionCanvas(composition: store.playground.resolved(composition), families: store.localFamilies)
                    .frame(width: 560, height: 330, alignment: .topLeading)
                    .scaleEffect(0.39, anchor: .topLeading)
                    .frame(width: 218, height: 129, alignment: .topLeading)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(T.line))
                Text(name).font(.system(size: 13, weight: .semibold))
                Text(summary).font(.system(size: 11)).foregroundStyle(T.muted)
                    .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
            }
            .padding(6).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
