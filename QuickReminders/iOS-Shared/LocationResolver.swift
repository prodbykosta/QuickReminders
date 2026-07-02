//
//  LocationResolver.swift
//  QuickReminders
//
//  Location resolution system for natural language parsing and UI picker
//

#if os(iOS) || os(watchOS)
import Foundation
import CoreLocation
import MapKit
import Combine

public class LocationResolver: NSObject, ObservableObject {
    @Published public var hasPermission = false

    private let locationManager = CLLocationManager()

    public override init() {
        super.init()
        locationManager.delegate = self
        checkPermission()
    }

    public func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    private func checkPermission() {
        let status = locationManager.authorizationStatus
        hasPermission = (status == .authorizedWhenInUse || status == .authorizedAlways)
    }

    // Parse location mentions from text
    public func findLocationMentions(in text: String) -> [(location: String, range: NSRange)] {
        var results: [(String, NSRange)] = []

        // Common patterns: "at Starbucks", "in Central Park", "on Main Street"
        let patterns = [
            "(?:at|in|on|near|by)\\s+([A-Z][a-zA-Z\\s]+(?:Street|Avenue|Road|Park|Cafe|Restaurant|Store|Building)?)",
            "meeting at\\s+([A-Z][a-zA-Z\\s]+)",
            "go to\\s+([A-Z][a-zA-Z\\s]+)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                for match in matches where match.numberOfRanges > 1 {
                    let locationRange = match.range(at: 1)
                    if let range = Range(locationRange, in: text) {
                        let location = String(text[range])
                        results.append((location, locationRange))
                    }
                }
            }
        }

        return results
    }

    // Search for locations using MapKit
    public func searchLocations(matching query: String) async -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            return response.mapItems
        } catch {
            return []
        }
    }

    // Geocode location name to coordinates
    public func geocode(locationName: String) async -> CLLocationCoordinate2D? {
        guard let request = MKGeocodingRequest(addressString: locationName) else { return nil }
        do {
            let mapItems = try await request.mapItems
            return mapItems.first?.location.coordinate
        } catch {
            return nil
        }
    }
}

extension LocationResolver: CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkPermission()
    }
}
#endif
