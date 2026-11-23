import Foundation
import ServiceManagement

/// "Abrir ao ligar o Mac" usando o mecanismo oficial (Ajustes do Sistema > Geral > Itens de Início de Sessão).
enum LoginItem {
    enum State: Equatable {
        case enabled, disabled, needsApproval, unavailable
    }

    static var state: State {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .needsApproval
        case .notRegistered: return .disabled
        default: return .unavailable
        }
    }

    /// Devolve uma mensagem de erro legível, ou nil se deu certo.
    static func set(enabled: Bool) -> String? {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return nil
        } catch {
            return "Não foi possível alterar: \(error.localizedDescription)"
        }
    }

    static func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
