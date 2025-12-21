//
//  ARViewController.swift
//  IRLGame
//
//  Created by Srinivas Sankaranarayanan on 12/20/25.
//

import UIKit
import ARKit
import RealityKit
import CoreLocation

final class ARViewController: UIViewController, CLLocationManagerDelegate {

    var arView: ARView!
    var locationManager: CLLocationManager?
    private var lastLocation: CLLocation?
    var players: [String: ModelEntity] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "AR"
        view.backgroundColor = .black

        setupBackButton()

        WebSocketManager.shared.connect()

        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.requestWhenInUseAuthorization()
        requestLocationUpdate()

        setupARView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startARSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // IMPORTANT: stop camera + tracking when leaving AR screen
        if self.isMovingFromParent {
            arView?.session.pause()
            locationManager?.stopUpdatingLocation()
        }
    }

    private func setupBackButton() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Back",
            style: .plain,
            target: self,
            action: #selector(backPressed)
        )
    }

    @objc private func backPressed() {
        arView.session.pause()
        locationManager?.stopUpdatingLocation()
        navigationController?.popViewController(animated: true)
    }

    private func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(arView, at: 0)
    }

    private func startARSession() {
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        config.environmentTexturing = .automatic
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        print("AR Session started")
    }

    // ------- Your existing player code -------
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
        print("Spawn button pressed")
        guard let frame = arView.session.currentFrame else {
            print("No ARFrame yet")
            return
        }

        // Ensure tracking is ready
        guard case .normal = frame.camera.trackingState else {
            print("Tracking not ready:", frame.camera.trackingState)
            return
        }

        // Create anchor 1 meter in front of camera
        let cameraTransform = frame.camera.transform
        let forward = -SIMD3<Float>(cameraTransform.columns.2.x,
                                    cameraTransform.columns.2.y,
                                    cameraTransform.columns.2.z)

        let position = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        ) + forward * 1.0

        let anchor = AnchorEntity(world: position)

        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 0.15),
            materials: [SimpleMaterial(color: .red, isMetallic: false)]
        )

        anchor.addChild(sphere)
        arView.scene.addAnchor(anchor)

        print("Spawned entity at", position)
    }

    @IBAction func movePlayerLeft(_ sender: UIButton) {
        updatePlayer(id: "TestPlayer", newPosition: [-2, 0, -3])
    }

    @IBAction func movePlayerRight(_ sender: UIButton) {
        updatePlayer(id: "TestPlayer", newPosition: [2, 0, -3])
    }

    @IBAction func sendButton(_ sender: UIButton) {
        guard let location = lastLocation else { return }
        sendLocation(lat: location.coordinate.latitude,
                     lon: location.coordinate.longitude,
                     alt: location.altitude)
        print("Location Sent to WebSocket")
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

    private func requestLocationUpdate() {
        locationManager?.startUpdatingLocation()
    }
}
