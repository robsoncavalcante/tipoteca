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
        CompositionTemplate(id: "marca", name: tr("Brand"), summary: tr("Name + descriptor. Add the symbol in the Symbol row.")) {
            composition(tr("Brand"), blocks: [
                block("Título", tr("Morning Brew!"), size: 84, weight: 700, tracking: -0.02, line: 1.0),
                block("Apoio", tr("NEIGHBORHOOD COFFEE SHOP"), size: 16, weight: 500, tracking: 0.28)
            ])
        },
        CompositionTemplate(id: "cartaz", name: tr("Poster"), summary: tr("Giant title, date and call to action.")) {
            composition(tr("Poster"), background: "111111", ink: "F4F1EA", blocks: [
                block("Título", tr("SUMMER FESTIVAL"), size: 88, weight: 900, tracking: -0.02, line: 0.95),
                block("Apoio", tr("Saturday, December 14 · Central Square"), size: 22, weight: 500),
                block("Corpo", tr("Free entry. Music, food and local art all day."), size: 15, line: 1.5)
            ])
        },
        CompositionTemplate(id: "instagram", name: tr("Instagram post"), summary: tr("Strong phrase on a colored background.")) {
            composition(tr("Instagram post"), dark: false, background: "C7FE83", ink: "0A0D0B", blocks: [
                block("Título", tr("Stop postponing.\nStart today."), size: 72, weight: 800, tracking: -0.02, line: 1.0),
                block("Apoio", tr("Three simple steps to organize your fonts"), size: 22, weight: 500),
                block("Corpo", tr("@yourbrand"), size: 15, weight: 600, tracking: 0.04)
            ])
        },
        CompositionTemplate(id: "editorial", name: "Editorial", summary: tr("Magazine: headline, standfirst and body text.")) {
            composition("Editorial", dark: false, background: "F6F1E7", ink: "1B1712", blocks: [
                block("Título", tr("Let the outside world fend for itself"), size: 60, weight: 700, tracking: -0.01, line: 1.05),
                block("Apoio", tr("In here the coffee is good and your peace is sacred."), size: 24, line: 1.25),
                block("Corpo", tr("At the café the rule is simple: the outside world can always wait fifteen minutes. Test how the headline talks to the paragraph, the rhythm of the lines and the hierarchy of the page."), size: 16, line: 1.6)
            ])
        },
        CompositionTemplate(id: "site", name: "Site (hero)", summary: tr("Headline, subtitle and price.")) {
            composition("Site (hero)", blocks: [
                block("Título", tr("Order specialty coffee"), size: 64, weight: 700, tracking: -0.02, line: 1.05),
                block("Apoio", tr("Roasted this week, delivered to your door."), size: 22),
                block("Corpo", tr("Subscriptions from $9.90 a month. Cancel anytime."), size: 16, line: 1.5)
            ])
        },
        CompositionTemplate(id: "citacao", name: tr("Quote"), summary: tr("Highlighted quote and author.")) {
            composition(tr("Quote"), background: "0B3D2E", ink: "F4F1EA", blocks: [
                block("Título", tr("“Design is thinking\nmade visible.”"), size: 56, weight: 600, tracking: -0.01, line: 1.12),
                block("Apoio", "— SAUL BASS", size: 15, weight: 600, tracking: 0.2)
            ])
        },
        CompositionTemplate(id: "convite", name: tr("Invitation"), summary: tr("Small lead-in, big name and details.")) {
            composition(tr("Invitation"), dark: false, background: "FBEFE6", ink: "3A1F14", blocks: [
                block("Apoio", tr("YOU ARE INVITED"), size: 14, weight: 600, tracking: 0.3),
                block("Título", tr("Zoe's Birthday"), size: 68, weight: 700, tracking: -0.01, line: 1.05),
                block("Corpo", tr("Saturday, 8 pm · 123 Flower Street\nRSVP by Thursday."), size: 17, line: 1.7)
            ])
        },
        CompositionTemplate(id: "cardapio", name: tr("Menu"), summary: tr("Section, items and prices.")) {
            composition(tr("Menu"), blocks: [
                block("Título", tr("Menu"), size: 60, weight: 700, tracking: -0.02, line: 1.0),
                block("Apoio", tr("COFFEES"), size: 15, weight: 600, tracking: 0.25),
                block("Corpo", tr("Espresso · $3\nCappuccino · $4\nLatte · $4.50\nDaily brew · $3"), size: 19, line: 1.8)
            ])
        },
        CompositionTemplate(id: "hierarquia", name: tr("Text hierarchy"), summary: tr("Title, support and body to test font pairings.")) {
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
                    Text(tr("Templates")).font(.system(size: 24, weight: .bold))
                    Text(tr("They use the project's default fonts. Then just change font, text and colors."))
                        .font(.system(size: 12)).foregroundStyle(T.muted)
                }
                Spacer()
                Button(tr("Close")) { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(24)
            Rectangle().fill(T.line).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !store.playground.userTemplates.isEmpty {
                        Text(tr("My templates")).font(.system(size: 13, weight: .bold))
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                            ForEach(store.playground.userTemplates) { template in
                                card(template, name: template.name, summary: tr("Saved by you"))
                                    .contextMenu {
                                        Button(tr("Delete template"), role: .destructive) {
                                            store.playground.userTemplates.removeAll { $0.id == template.id }
                                        }
                                    }
                            }
                        }
                    }
                    Text(tr("Ready-made templates")).font(.system(size: 13, weight: .bold))
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
