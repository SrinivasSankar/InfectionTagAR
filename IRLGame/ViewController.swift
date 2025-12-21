//
//  ViewController.swift
//  IRLGame
//
//  Created by Srinivas Sankaranarayanan on 12/19/25.
//

import UIKit
import ARKit
import RealityKit
import CoreLocation

class ViewController: UIViewController {
    
    var arView: ARView!
    var locationManager: CLLocationManager?
    private var lastLocation: CLLocation?
    var players: [String: ModelEntity] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        WebSocketManager.shared.connect()
        
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.allowsBackgroundLocationUpdates = true
        locationManager?.showsBackgroundLocationIndicator = true
        
        locationManager?.requestWhenInUseAuthorization()
        
        requestLocationUpdate()
        
        setupARView()
        startARSession()
    }
    
    private func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)
    }

    private func startARSession() {
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        config.environmentTexturing = .automatic

        arView.session.run(config)
    }
    
    func updatePlayer(id: String, newPosition: SIMD3<Float>) {
        guard let player = players[id] else { return }
        let smoothing: Float = 0.1
        player.position = simd_mix(player.position, newPosition, SIMD3<Float>(repeating: smoothing))
    }
    
    func addPlayer(id: String, initialPosition: SIMD3<Float>) {
        if players[id] != nil { return }
        
        let anchor = AnchorEntity(world: initialPosition)
        
        let player = ModelEntity(
            mesh: .generateSphere(radius: 0.25),
            materials: [SimpleMaterial(color: .red, isMetallic: false)]
        )
        
        anchor.addChild(player)
        arView.scene.addAnchor(anchor)
        
        players[id] = player
        print("Added Player:", id)
    }
    
    
    @IBAction func spawnPlayer(_ sender: UIButton) {
        addPlayer(id: "TestPlayer", initialPosition: [0, 0, -3])
    }
    
    @IBAction func movePlayerLeft(_ sender: UIButton) {
        updatePlayer(id: "TestPlayer", newPosition: [-2, 0, -3])
    }
    
    @IBAction func movePlayerRight(_ sender: UIButton) {
        updatePlayer(id: "TestPlayer", newPosition: [2, 0, -3])
    }
    
    @IBAction func SendButton(_ sender: UIButton) {
        guard let location = lastLocation else { return }
        sendLocation(lat: location.coordinate.latitude,
                     lon: location.coordinate.longitude,
                     alt: location.altitude)
        print("Location Sent to WebSocket")
    }
    
    func gpsDeltaToAR(from a: CLLocation, to b: CLLocation
) -> SIMD3<Float> {
        let earthRadius = 6_371_000.0
        
        let dLat = (b.coordinate.latitude - a.coordinate.latitude) * .pi / 180
        let dlon = (b.coordinate.longitude - a.coordinate.longitude) * .pi / 180
        
        let x = cos(a.coordinate.latitude * .pi / 180) * dlon * earthRadius
        let y = dLat * earthRadius
        let z = b.altitude - a.altitude
        
        return SIMD3(Float(x), Float(y), Float(-z))
        
    }
    
    func sendLocation(lat: Double, lon: Double, alt: Double) {
        let location: [String: Any] = [
            "type": "location",
            "lat": lat,
            "lon": lon,
            "alt": alt
        ]

        if let data = try? JSONSerialization.data(withJSONObject: location),
           let json = String(data: data, encoding: .utf8) {
            WebSocketManager.shared.send(text: json)
        }
    }

    private let center = CLLocationCoordinate2D(latitude: 40.210557, longitude: -83.029300)
    private let radius: CLLocationDistance = 8
    
    private lazy var region: CLCircularRegion = {
        let region = CLCircularRegion(
            center: center,
            radius: radius,
            identifier: "Initial Circle"
        )
        
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }()
    
    private func startRegionMonitoringIfPossible() {
        guard let lm = locationManager else {
            print("Location manager is nil")
            return
        }

        switch lm.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            lm.startMonitoring(for: region)
            print("Started monitoring region")
        default:
            print("Not authorized for region monitoring yet")
        }
    }
    
    private func requestLocationUpdate() {
        locationManager?.startUpdatingLocation( )
    }
    
    private func stopLocationUpdate() {
        locationManager?.stopUpdatingLocation( )
    }
}

extension ViewController: ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let geoAnchor = anchor as? ARGeoAnchor else { continue }
            
            let anchorEntity = AnchorEntity(anchor: geoAnchor)
            
            let marker = ModelEntity(
                mesh: .generateSphere(radius: 0.25),
                materials: [SimpleMaterial(color: .red, isMetallic: false)]
            )
            
            anchorEntity.addChild(marker)
            arView.scene.addAnchor(anchorEntity)
            
            print("Rendered geo anchor:", geoAnchor.name ?? "unnamed")
        }
    }
}

extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("Entered region: \(region.identifier)")
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("Exited region: \(region.identifier)")
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastLocation = location
        
        if region.contains(location.coordinate) {
            print("INSIDE region (manual check)")
        } else {
            print("OUTSIDE region (manual check)")
        }
        print("Latitude: \(location.coordinate.latitude), Longtitude: \(location.coordinate.longitude), Altitude: \(location.altitude)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined:
            print("When user did not yet determined")
        case .restricted:
            print("Restricted by parental control")
        case .denied:
            print("When user select option Don't allow")
            
            
        case .authorizedWhenInUse:
            print("When user select option Allow While Using App or Allow Once")
            startRegionMonitoringIfPossible()
        case .authorizedAlways:
            print("When user select option Change to Always Allow")
            startRegionMonitoringIfPossible()
            
            locationManager?.requestAlwaysAuthorization()
        default:
            print("Default")
        }
    }
}

