//
//  LocationService.swift
//  IRLGame
//
//  Created by Srinivas Sankaranarayanan on 12/22/25.
//
//  LocationService deals with retrieving location and heading data from the phone and making the data accessable to other parts of the app.

import CoreLocation

final class LocationService: NSObject, CLLocationManagerDelegate {

    static let shared = LocationService()
    private let manager = CLLocationManager()
    
    private var onLocation: ((CLLocation) -> Void)?
    private var smoothedHeadingDeg: Double?
    private(set) var lastLocation: CLLocation?
    
    private(set) var lastHeadingDeg: Double?
    private(set) var lastHeadingAccuracy: Double?

    private override init() {
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 2.0
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        
        manager.headingFilter = 1
        manager.headingOrientation = .portrait
        
    }

    // MARK: - Start and  Stop Location and Heading Service
    
    // Function starts both location and heading updates
    func startLocationAndHeadingUpdates() {
        let status = manager.authorizationStatus

        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
            return
        }

        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
            print("Location and Heading Updates started")
        }
    }

    // Function stops only location updates
    func stopLocationUpdates() {
        manager.stopUpdatingLocation()
        print("Location Updates stopped")
    }
    
    // Function stops only heading updates
    func stopHeadingUpdates() {
        manager.stopUpdatingHeading()
        print("Heading Updates stopped")
    }
    
    
    // Function to refine heading reading from phone
    private func smoothHeading(_ deg: Double, alpha: Double = 0.15) -> Double {
        let rad = deg * .pi / 180
        let x = cos(rad)
        let y = sin(rad)

        if smoothedHeadingDeg == nil {
            smoothedHeadingDeg = deg
            return deg
        }

        let prevRad = (smoothedHeadingDeg! * .pi / 180)
        let px = cos(prevRad)
        let py = sin(prevRad)

        let sx = (1 - alpha) * px + alpha * x
        let sy = (1 - alpha) * py + alpha * y

        var out = atan2(sy, sx) * 180 / .pi
        if out < 0 { out += 360 }
        smoothedHeadingDeg = out
        return out
    }
    
    
    // MARK: - CLLocationManagerDelegates
    
    // Delegate deals with changes related to location authorization in the app
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
        }
    }

    // Delegate deals with changes to the location of player(phone)
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        lastLocation = loc
        
        if let callback = onLocation {
            callback(loc)
            onLocation = nil
        }
        
        guard GameService.shared.isGameActive else { return }
        print("Location update:", loc.coordinate.latitude, loc.coordinate.longitude, loc.altitude,
                      "heading:", lastHeadingDeg as Any, "±", lastHeadingAccuracy as Any)
    }
    
    // Delegate deals with changes to the heading of player(phone)
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let raw = newHeading.magneticHeading
        let acc = newHeading.headingAccuracy
        let filtered = smoothHeading(raw)
        lastHeadingDeg = filtered
        lastHeadingAccuracy = acc
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        return true
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error.localizedDescription)
    }
}
