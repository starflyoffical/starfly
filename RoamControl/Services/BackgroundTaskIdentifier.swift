import Foundation

enum BackgroundTaskConfigurationStatus: String {
    case notChecked = "Not checked"
    case permitted = "Permitted identifier matched"
    case missingPermittedIdentifiers = "Permitted identifier list missing"
    case missingRuntimeBundleIdentifier = "Runtime bundle identifier missing"
    case runtimeIdentifierNotPermitted = "Runtime identifier wildcard not permitted"
}

enum BackgroundTaskRegistrationStatus: String {
    case notAttempted = "Not attempted"
    case accepted = "Accepted"
    case rejected = "Rejected"
}

enum BackgroundTaskIdentifier {
    static func prefix(
        for component: String,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) -> String? {
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else { return nil }
        return "\(bundleIdentifier).\(component)"
    }

    static func configurationStatus(
        for component: String,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        permittedIdentifiers: [String]? = Bundle.main.object(
            forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers"
        ) as? [String]
    ) -> BackgroundTaskConfigurationStatus {
        guard let prefix = prefix(for: component, bundleIdentifier: bundleIdentifier) else {
            return .missingRuntimeBundleIdentifier
        }
        guard let permittedIdentifiers, !permittedIdentifiers.isEmpty else {
            return .missingPermittedIdentifiers
        }
        return permittedIdentifiers.contains("\(prefix).*")
            ? .permitted : .runtimeIdentifierNotPermitted
    }
}
