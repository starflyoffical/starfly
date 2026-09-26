import Foundation

/// Local connection-health categories. They are displayed only on this iPhone
/// and may be included when the user explicitly shares a diagnostic report.
enum FailureStage: String, CaseIterable {
    case pairingRecord
    case discovery
    case vpnConnection
    case pairVerification
    case tunnelCreation
    case tunnelConnection
    case tunnelSecurity
    case serviceDirectory
    case serviceHandshake
    case locationService
    case locationInitialWrite
    case locationActiveWrite
    case locationEngine
    case schedulerRegistration
    case schedulerSubmission
    case pairingAdvertisement
    case pairingConnection
    case pairingAuthentication
    case pairingExpired
    case pairingEngine
    case pairingStorage
    case pairingImport
    case pairingRead
    case locationPreparation
    case locationRestore
    case pairingUnknown
    case locationUnknown

    static func classify(_ message: String, fallback: FailureStage) -> FailureStage {
        switch message {
        case "The iPhone did not confirm stopping location simulation in time.",
             "Roam Control could not confirm stopping location simulation.": return .locationRestore
        case "Roam Control could not securely store the new pairing.": return .pairingStorage
        case "The saved pairing record could not be read.",
             "The saved pairing record is missing its device identity.",
             "The discovered device did not match the paired iPhone.": return .pairingRecord
        case "Roam Control could not identify this iPhone's pairing service.",
             "Roam Control found an outdated device announcement. Toggle LocalDevVPN off and on, then try again.",
             "Roam Control could not find this iPhone through LocalDevVPN. Check that the tunnel is enabled and try again.",
             "Local Network access is required to find this iPhone.": return .discovery
        case "LocalDevVPN returned an invalid device address.",
             "LocalDevVPN did not make the iPhone connection available in time.",
             "Roam Control could not reach the iPhone through LocalDevVPN.",
             "Install LocalDevVPN before starting a location session.": return .vpnConnection
        case "The paired iPhone did not respond in time.",
             "The iPhone rejected the saved pairing session.",
             "Pairing verification took too long.",
             "The saved pairing is no longer valid. Reset Device Setup and pair again.": return .pairVerification
        case "The iPhone did not create its secure tunnel in time.",
             "The iPhone could not create its secure tunnel.": return .tunnelCreation
        case "LocalDevVPN did not open the secure tunnel in time.",
             "Roam Control could not open the secure device tunnel.": return .tunnelConnection
        case "The encrypted device tunnel took too long to start.",
             "Roam Control could not secure the device tunnel.",
             "The iPhone returned an invalid tunnel address.",
             "The iPhone returned an invalid service address.": return .tunnelSecurity
        case "The iPhone's service directory took too long to respond.",
             "Roam Control could not open the iPhone's service directory.": return .serviceDirectory
        case "The iPhone's service handshake took too long.",
             "Roam Control could not complete the iPhone service handshake.": return .serviceHandshake
        case "The location service took too long to open.",
             "The iPhone did not make its location service available.",
             "The location service did not become ready in time.",
             "The iPhone's location service did not become ready.",
             "The location controls took too long to open.",
             "Roam Control could not open the iPhone's location controls.": return .locationService
        case "The iPhone did not accept the selected location.": return .locationInitialWrite
        case "The iPhone ended the active location session.",
             "Roam Control could not update the active location.",
             "StarFly 無法更新目前位置。": return .locationActiveWrite
        case "Roam Control could not start its device session.",
             "The location session stopped unexpectedly.",
             "Roam Control could not start its location engine.": return .locationEngine
        case "iOS could not prepare the location session. Close Roam Control, reopen it, and try again.",
             "iOS could not register the secure pairing task. Close Roam Control, reopen it, and try again.": return .schedulerRegistration
        case "iOS could not keep pairing active in the background. Keep Roam Control open and try again.": return .schedulerSubmission
        case "Local Network access is required. Enable it in Settings › Apps › Roam Control, then try again.": return .pairingAdvertisement
        case "Roam Control could not open a local pairing connection.",
             "Roam Control could not determine its pairing port.",
             "The iPhone could not connect to Roam Control.",
             "The iPhone ended the pairing connection. Start pairing again when you are ready.": return .pairingConnection
        case "The code was not accepted. Start pairing again and enter the new code.": return .pairingAuthentication
        case "Pairing took too long. Return to Roam Control and try again.": return .pairingExpired
        case "Roam Control could not start its pairing engine.",
             "The pairing engine returned an empty record.": return .pairingEngine
        default: return fallback
        }
    }
}

enum FailureDisposition: String {
    case terminal, recoverable
}

enum SchedulerFailureReason: String {
    case unavailable, tooManyPendingRequests, notPermitted, immediateRunIneligible, unknown

    static func classify(_ error: Error) -> Self {
        let error = error as NSError
        guard error.domain == "BGTaskSchedulerErrorDomain" else { return .unknown }
        switch error.code {
        case 1: return .unavailable
        case 2: return .tooManyPendingRequests
        case 3: return .notPermitted
        case 4: return .immediateRunIneligible
        default: return .unknown
        }
    }

    var pairingGuidance: String {
        switch self {
        case .unavailable:
            "iOS background processing is unavailable. Check Background App Refresh for StarFly in Settings, then try again."
        case .tooManyPendingRequests:
            "iOS has too many pending background tasks. Let other tasks finish, then return to StarFly and try pairing again."
        case .notPermitted:
            "iOS did not permit the pairing background task. Check StarFly's Background App Refresh setting, then try again."
        case .immediateRunIneligible:
            "iOS could not start pairing immediately under current system conditions. Keep StarFly open and try again shortly."
        case .unknown:
            "iOS could not schedule pairing. Keep StarFly open and try again."
        }
    }
}
