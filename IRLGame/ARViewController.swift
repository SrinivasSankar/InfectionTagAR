//
//  ARViewController.swift
//  IRLGame
//
//  Created by Srinivas Sankaranarayanan on 12/20/25.
//

import UIKit
import ARKit
import RealityKit

final class ARViewController: UIViewController {

    // MARK: - ARCore
    var arView: ARView!
    var worldOrigin: simd_float4x4?
    var positionTimer: Timer?
    
    // Remote Players
    var playerAnchors: [String: AnchorEntity] = [:]
    
    
    // MARK: - Lifecyle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "AR"
        view.backgroundColor = .black
        
        MultiplayerService.shared.onPlayerUpdated = { [weak self] player in
            self?.updateRemotePlayer(
                id: player.id,
                position: player.position
            )
        }
        
        MultiplayerService.shared.onPlayerRemoved = { [weak self] id in
                    self?.removeRemotePlayer(id)
                }
        setupBackButton()
        setupARView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startARSession()
        waitForStableTracking()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // IMPORTANT: stop camera + tracking when leaving AR screen
        if self.isMovingFromParent {
            arView?.session.pause()
        }
    }
    
    func removeRemotePlayer(_ id: String) {
        guard let anchor = playerAnchors[id] else { return }
        anchor.removeFromParent()
        playerAnchors.removeValue(forKey: id)
    }
    
    
    // MARK: - Setup
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
    
    
    // MARK: - World Origin
    private func waitForStableTracking() {
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            guard let frame = self.arView.session.currentFrame,
                  case .normal = frame.camera.trackingState else { return }

            self.worldOrigin = frame.camera.transform
            print("World origin locked")
            timer.invalidate()
            self.startSendingPosition()
        }
    }
    
    private func currentPlayerPosition() -> SIMD3<Float>? {
            guard let frame = arView.session.currentFrame,
                  let origin = worldOrigin else { return nil }

            let relative = simd_mul(simd_inverse(origin), frame.camera.transform)
            return SIMD3(relative.columns.3.x,
                         relative.columns.3.y,
                         relative.columns.3.z)
        }

    
    // MARK: - Multiplayer Position Sending
    private func startSendingPosition() {
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let pos = self.currentPlayerPosition() else { return }
            MultiplayerService.shared.sendPlayerMove(pos)
        }
    }
    
    
    // MARK: - UI
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
        navigationController?.popViewController(animated: true)
    }

    
    // MARK: - Remote Players
    func updateRemotePlayer(id: String, position: SIMD3<Float>) {
        if let anchor = playerAnchors[id] {
            anchor.position = simd_mix(anchor.position, position, SIMD3<Float>(repeating: 0.15))
            return
        }

        let anchor = AnchorEntity(world: position)

        let model = ModelEntity(
            mesh: .generateSphere(radius: 0.2),
            materials: [SimpleMaterial(color: .blue, isMetallic: false)]
        )

        anchor.addChild(model)
        arView.scene.addAnchor(anchor)
        playerAnchors[id] = anchor

        print("Spawned remote player:", id)
    }
    
    // MARK: - Manual Local Spawn (Debug)
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
}
