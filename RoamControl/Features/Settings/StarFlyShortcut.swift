import Foundation

enum StarFlyShortcut {
    static let defaultNetworkWorkflowName = "StarFly 網路流程"

    enum NetworkCommand: String {
        case turnCellularOff = "disable-cellular"
        case turnCellularOn = "enable-cellular"
    }

    static func runURL(named shortcutName: String, command: NetworkCommand) -> URL? {
        let name = shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "x-callback-url"
        components.path = "/run-shortcut"
        components.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "input", value: "text"),
            URLQueryItem(name: "text", value: command.rawValue),
            URLQueryItem(name: "x-success", value: "starfly://shortcut-complete"),
            URLQueryItem(name: "x-cancel", value: "starfly://shortcut-cancel")
        ]
        return components.url
    }

    static let createURL = URL(string: "shortcuts://create-shortcut")!
}
