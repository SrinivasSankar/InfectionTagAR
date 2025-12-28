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
    
    var sharedOriginTransform: simd_float4x4?
    var isSharedOriginSet = false
    
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
        
        if self.isMovingFromParent {
                positionTimer?.invalidate()
                positionTimer = nil
                arView?.session.pause()
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
    func lockWorldOrigin() {
        guard worldOrigin == nil,
              let frame = arView.session.currentFrame,
              case .normal = frame.camera.trackingState else { return }
        worldOrigin = frame.camera.transform
        print("World Origin Locked")
    }
    
    private func waitForStableTracking() {
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            self.lockWorldOrigin()
            if self.worldOrigin != nil {
                timer.invalidate()
                self.startSendingPosition()
            }
        }
    }
    
//    private func currentPlayerPosition() -> SIMD3<Float>? {
//        guard let frame = arView.session.currentFrame,
//              let origin = worldOrigin else { return nil }
//
//        let cameraTransform = frame.camera.transform
//        let relative = simd_mul(simd_inverse(origin), cameraTransform)
//        return SIMD3(relative.columns.3.x,
//                     relative.columns.3.y,
//                     relative.columns.3.z)
//    }
    
    func currentPositionRelativeToSharedOrigin() -> SIMD3<Float>? {
        guard let frame = arView.session.currentFrame,
              let origin = sharedOriginTransform,
              isSharedOriginSet else {
            return nil
        }

        let camTransform = frame.camera.transform
        let relative = simd_mul(simd_inverse(origin), camTransform)

        return SIMD3<Float>(
            relative.columns.3.x,
            relative.columns.3.y,
            relative.columns.3.z
        )
    }

    
    // MARK: - Multiplayer Position Sending
    private func startSendingPosition() {
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let pos = self.currentPositionRelativeToSharedOrigin() else { return }
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
//    func updateRemotePlayer(id: String, position: SIMD3<Float>) {
//        if let anchor = playerAnchors[id] {
//            anchor.position = simd_mix(anchor.position, position, SIMD3<Float>(repeating: 0.15))
//            return
//        }
//
//        let anchor = AnchorEntity(world: position)
//
//        let model = ModelEntity(
//            mesh: .generateSphere(radius: 0.2),
//            materials: [SimpleMaterial(color: .blue, isMetallic: false)]
//        )
//
//        anchor.addChild(model)
//        arView.scene.addAnchor(anchor)
//        playerAnchors[id] = anchor
//
//        print("Spawned remote player:", id)
//    }
    func updateRemotePlayer(id: String, position: SIMD3<Float>) {
        print("Position: ", position)
        print("X(Lon):", position.x, "Y(Lat):", position.y, "Z(Alt):", position.z)
        // Never render yourself
        guard id != MultiplayerService.shared.playerID else { return }

        // Must have shared origin
        guard let sharedOrigin = sharedOriginTransform,
              isSharedOriginSet else { return }

        // Validate position
        guard position.x.isFinite,
              position.y.isFinite,
              position.z.isFinite,
              simd_length(position) > 0.001 else { return }

        DispatchQueue.main.async {

            // Convert shared-origin space → AR world space
            let worldTransform =
                simd_mul(sharedOrigin, simd_float4x4(translation: position))

            if let anchor = self.playerAnchors[id] {
                anchor.transform.matrix = worldTransform
                return
            }

            let anchor = AnchorEntity(world: worldTransform)

            let model = ModelEntity(
                mesh: .generateSphere(radius: 0.2),
                materials: [SimpleMaterial(color: .blue, isMetallic: false)]
            )

            anchor.addChild(model)
            self.arView.scene.addAnchor(anchor)
            self.playerAnchors[id] = anchor

            print("Spawned remote player:", id)
        }
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
    
    @IBAction func setSharedOriginTapped(_ sender: UIButton) {
        guard let frame = arView.session.currentFrame,
              case .normal = frame.camera.trackingState else {
            print("Tracking not ready — cannot set origin")
            return
        }

//        var origin = frame.camera.transform
//
//        // Remove rotation — keep translation only
//        origin.columns.0 = SIMD4(1, 0, 0, 0)
//        origin.columns.1 = SIMD4(0, 1, 0, 0)
//        origin.columns.2 = SIMD4(0, 0, 1, 0)

        sharedOriginTransform = frame.camera.transform
        isSharedOriginSet = true

        print("✅ Shared origin set")

        // Optional: visualize the origin
        let anchor = AnchorEntity(world: frame.camera.transform)
        let marker = ModelEntity(
            mesh: .generateSphere(radius: 0.05),
            materials: [SimpleMaterial(color: .green, isMetallic: false)]
        )
        anchor.addChild(marker)
        arView.scene.addAnchor(anchor)
    }
    
    @IBAction func showPlayers(_ sender: UIButton) {
        MultiplayerService.shared.playerLocation()
    }
    
//    @IBAction func setSharedOriginTapped(_ sender: UIButton) {
//        guard let frame = arView.session.currentFrame,
//              case .normal = frame.camera.trackingState else {
//            print("Tracking not ready — cannot set origin")
//            return
//        }
//
//        sharedOriginTransform = frame.camera.transform
//        isSharedOriginSet = true
//
//        print("✅ Shared origin set")
//
//        // Optional: visualize the origin
//        let anchor = AnchorEntity(world: frame.camera.transform)
//        let marker = ModelEntity(
//            mesh: .generateSphere(radius: 0.05),
//            materials: [SimpleMaterial(color: .green, isMetallic: false)]
//        )
//        anchor.addChild(marker)
//        arView.scene.addAnchor(anchor)
//    }
}

extension simd_float4x4 {
    init(translation: SIMD3<Float>) {
        self = matrix_identity_float4x4
        columns.3 = SIMD4<Float>(translation.x, translation.y, translation.z, 1)
    }
}
