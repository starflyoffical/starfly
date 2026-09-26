import CoreLocation
import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let starFlyGPX = UTType(importedAs: "com.topografix.gpx", conformingTo: .xml)
}

enum GPXRouteError: LocalizedError {
    case invalidDocument
    case tooFewPoints
    case invalidCoordinate

    var errorDescription: String? {
        switch self {
        case .invalidDocument:
            "無法讀取 GPX 檔案，請確認檔案格式正確。"
        case .tooFewPoints:
            "GPX 路徑至少需要兩個軌跡點。"
        case .invalidCoordinate:
            "GPX 檔案包含無效的經緯度座標。"
        }
    }
}

enum GPXRouteCodec {
    static func decode(_ data: Data) throws -> [RoutePoint] {
        let parser = XMLParser(data: data)
        let delegate = GPXParserDelegate()
        parser.delegate = delegate

        guard parser.parse(), let points = delegate.selectedPoints else {
            throw delegate.error ?? GPXRouteError.invalidDocument
        }
        guard points.count >= 2 else { throw GPXRouteError.tooFewPoints }
        return points
    }

    static func encode(points: [RoutePoint], name: String) -> Data {
        let safeName = escapeXML(name)
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="StarFly" xmlns="http://www.topografix.com/GPX/1/1">
          <metadata><name>\(safeName)</name></metadata>
          <trk><name>\(safeName)</name><trkseg>
        """

        for point in points {
            let latitude = String(format: "%.8f", locale: Locale(identifier: "en_US_POSIX"), point.latitude)
            let longitude = String(format: "%.8f", locale: Locale(identifier: "en_US_POSIX"), point.longitude)
            xml += "\n    <trkpt lat=\"\(latitude)\" lon=\"\(longitude)\"></trkpt>"
        }

        xml += "\n  </trkseg></trk>\n</gpx>\n"
        return Data(xml.utf8)
    }

    static func suggestedFilename(for name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r")
        let safeName = name
            .components(separatedBy: invalidCharacters)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return safeName.isEmpty ? "StarFly-Route" : safeName
    }

    private static func escapeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

private final class GPXParserDelegate: NSObject, XMLParserDelegate {
    private(set) var trackPoints: [RoutePoint] = []
    private(set) var routePoints: [RoutePoint] = []
    private(set) var error: GPXRouteError?

    var selectedPoints: [RoutePoint]? {
        if !trackPoints.isEmpty { return trackPoints }
        if !routePoints.isEmpty { return routePoints }
        return nil
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let localName = elementName.split(separator: ":").last?.lowercased()
        guard localName == "trkpt" || localName == "rtept" else { return }

        guard
            let latitudeText = attributeDict["lat"],
            let longitudeText = attributeDict["lon"],
            let latitude = Double(latitudeText),
            let longitude = Double(longitudeText),
            (-90...90).contains(latitude),
            (-180...180).contains(longitude)
        else {
            error = .invalidCoordinate
            parser.abortParsing()
            return
        }

        let point = RoutePoint(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        if localName == "trkpt" {
            trackPoints.append(point)
        } else {
            routePoints.append(point)
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        if error == nil { error = .invalidDocument }
    }
}

struct GPXRouteDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.starFlyGPX]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw GPXRouteError.invalidDocument
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
