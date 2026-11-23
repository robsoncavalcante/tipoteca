import Foundation

// Textos da interface: o código usa inglês como chave e Resources/pt.lproj/Localizable.strings traz o português.
// Idiomas sem tradução caem no inglês. Para adicionar um idioma, crie Resources/<código>.lproj/Localizable.strings.

/// Busca o texto traduzido e aplica `String(format:)` quando há argumentos (%@ para texto, %ld para Int).
func tr(_ key: String, _ args: CVarArg...) -> String {
    trv(key, args)
}

func trv(_ key: String, _ args: [CVarArg]) -> String {
    let format = NSLocalizedString(key, bundle: .main, comment: "")
    return args.isEmpty ? format : String(format: format, locale: Locale.current, arguments: args)
}

/// Singular/plural: o primeiro argumento do formato é sempre a contagem (`%ld`).
func trPlural(_ count: Int, _ one: String, _ other: String, _ extra: CVarArg...) -> String {
    trv(count == 1 ? one : other, [count] + extra)
}

/// Os blocos de texto guardam "Título", "Apoio" e "Corpo" nos arquivos (identificadores); aqui vira o texto exibido.
func blockLabel(_ label: String) -> String {
    switch label {
    case "Título": return tr("Title")
    case "Apoio": return tr("Support")
    case "Corpo": return tr("Body")
    default: return label
    }
}
