//
//  LocationService.swift
//  IRLGame
//
//  Created by Srinivas Sankaranarayanan on 12/22/25.
//

import CoreLocation

final class LocationService: NSObject, CLLocationManagerDelegate {

    static let shared = LocationService()

    private let manager = CLLocationManager()
    private(set) var lastLocation: CLLocation?

    // Throttle network sends
    private var lastSentTime: Date = .distantPast
    private let sendInterval: TimeInterval = 1.0

    private override init() {
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 2.0
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
    }

    func start() {
        let status = manager.authorizationStatus

        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
            return
        }

        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
            print("LocationService started")
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        print("LocationService stopped")
    }

    
    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        lastLocation = loc
        
        print("Location update:", loc.coordinate.latitude, loc.coordinate.longitude, loc.altitude)

        // Throttle network sends
        let now = Date()
        guard now.timeIntervalSince(lastSentTime) >= sendInterval else { return }
        lastSentTime = now

        MultiplayerService.shared.sendLocation(loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error.localizedDescription)
    }
}
