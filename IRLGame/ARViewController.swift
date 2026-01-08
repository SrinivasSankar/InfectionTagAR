//
//  ARViewController.swift
//  IRLGame
//
//  Created by Srinivas Sankaranarayanan on 12/20/25.
//
//  ARViewController deals with the AR mode in the game and its components.

import UIKit
import ARKit
import RealityKit

final class ARViewController: UIViewController {
    
    // MARK: - ARCore
    var arView: ARView!
    var worldOrigin: simd_float4x4?
    var positionTimer: Timer?
    
    var sessionStartCameraTransform: simd_float4x4?
    
    var sharedOriginTransform: simd_float4x4?
    var isSharedOriginSet = false
    
    // Remote Players
    var playerAnchors: [String: AnchorEntity] = [:]
    
    // Stable Tracking
    var isUsingStableTracking: Bool = false
    
    private var didStartSession = false
    private var pendingPositions: [String: SIMD3<Float>] = [:]

    
    // MARK: - Lifecyle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("AR viewDidLoad instance:", ObjectIdentifier(self))
        
        title = "AR"
        view.backgroundColor = .black
        
//        MultiplayerService.shared.onPlayerUpdated = { [weak self] player in
//            print("AR RECEIVED UPDATE:", player.id, player.position)
//            self?.spawnOrUpdatePlayer(
//                id: player.id,
//                position: player.position
//            )
//        }
        
        MultiplayerService.shared.onPlayerUpdated = { [weak self] player in
            guard let self else { return }
            self.pendingPositions[player.id] = player.position
            self.spawnOrUpdatePlayerIfReady(id: player.id)
        }
        
        MultiplayerService.shared.onPlayerRemoved = { [weak self] id in
                    self?.removeRemotePlayer(id)
        }
        
        setupBackButton()
        setupARView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        print("AR viewWillAppear instance:", ObjectIdentifier(self))

        guard !didStartSession else { return }

        startARSession()
        waitForStableTracking()
        didStartSession = true
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
//            self.lockWorldOrigin()
//            if self.worldOrigin != nil {
//                timer.invalidate()
////                self.startSendingPosition( )
//            }
//            
            guard let frame = self.arView.session.currentFrame,
                  case .normal = frame.camera.trackingState else { return }

            if self.sessionStartCameraTransform == nil {
                self.sessionStartCameraTransform = frame.camera.transform
                print("Session start camera captured")
                self.spawnAllPlayers()
                timer.invalidate()
            }
        }
    }
    
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

    
    // MARK: - User Position Sending
//    private func startSendingPosition() {
//        positionTimer?.invalidate()
//        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
//            guard self.isSharedOriginSet,
//            let pos = self.currentPositionRelativeToSharedOrigin() else { return }
//            
//            MultiplayerService.shared.sendPlayerMove(pos)
//            print("Location has started being sent to the server.")
//        }
//    }
//    
//    private func stopSendingPosition() {
//        positionTimer?.invalidate()
//        positionTimer = nil
//        print("Location has stopped being sent to the server.")
//    }
    
    
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
//        print("Position: ", position)
//        print("X(Lon):", position.x, "Y(Lat):", position.y, "Z(Alt):", position.z)
//
//        guard id != MultiplayerService.shared.playerID else { return }
//
//        // Must have shared origin
//        guard let sharedOrigin = sharedOriginTransform,
//              isSharedOriginSet else { return }
//
//        // Validate position
//        guard position.x.isFinite,
//              position.y.isFinite,
//              position.z.isFinite,
//              simd_length(position) > 0.001 else { return }
//        
//        let worldTransform =
//            simd_mul(sharedOrigin, simd_float4x4(translation: position))
//        
//        print("World Transform:", worldTransform)
//        let worldPos = SIMD3<Float>(
//            worldTransform.columns.3.x,
//            worldTransform.columns.3.y,
//            worldTransform.columns.3.z
//        )
//
//        guard let frame = arView.session.currentFrame else { return }
//
//        let camPos = SIMD3<Float>(
//            frame.camera.transform.columns.3.x,
//            frame.camera.transform.columns.3.y,
//            frame.camera.transform.columns.3.z
//        )
//
//        let distance = simd_length(worldPos - camPos)
//        print("Remote player distance:", distance)
//
//        DispatchQueue.main.async {
//            if let anchor = self.playerAnchors[id] {
//                anchor.transform.matrix = worldTransform
//                return
//            }
//
//            let anchor = AnchorEntity(world: worldTransform)
//            
//            let model = ModelEntity(
//                mesh: .generateSphere(radius: 0.2),
//                materials: [SimpleMaterial(color: .blue, isMetallic: false)]
//            )
//
//            anchor.addChild(model)
//            self.arView.scene.addAnchor(anchor)
//            self.playerAnchors[id] = anchor
//
//            print("Spawned remote player:", id)
//        }
//    }
//    
//    private func yawOnlyTransform(from t: simd_float4x4) -> simd_float4x4 {
//
//        // ARKit forward is -Z
//        let forward = SIMD3<Float>(-t.columns.2.x, 0, -t.columns.2.z)
//        let f = simd_normalize(forward)
//
//        let up = SIMD3<Float>(0, 1, 0)
//
//        // ✅ FIX: forward × up (not up × forward)
//        let right = simd_normalize(simd_cross(f, up))
//        let newUp = simd_cross(right, f)
//
//        var out = matrix_identity_float4x4
//
//        // Columns = basis vectors
//        out.columns.0 = SIMD4<Float>(right.x,  right.y,  right.z,  0) // +X right
//        out.columns.1 = SIMD4<Float>(newUp.x,  newUp.y,  newUp.z,  0) // +Y up
//        out.columns.2 = SIMD4<Float>(-f.x,     -f.y,     -f.z,     0) // -Z forward
//
//        // Preserve position
//        out.columns.3 = t.columns.3
//
//        return out
//    }
    
//    func spawnPlayer(id: String, position: SIMD3<Float>) {
//        print("Player Spawned: ", id)
//        guard let origin = sessionStartCameraTransform else {
//            print("Session start camera not set yet")
//            return
//        }
//        
//        //let yawOrigin = yawOnlyTransform(from: origin)
//        
//        // Local offset relative to session start camera
//        let localOffset = SIMD3<Float>(position.x, position.y, position.z) // 1 meter forward
//
//        // Convert local offset → world transform
//        let worldTransform =
//            simd_mul(origin, simd_float4x4(translation: localOffset))
//
//        let anchor = AnchorEntity(world: worldTransform)
//
//        let sphere = ModelEntity(
//            mesh: .generateSphere(radius: 0.15),
//            materials: [SimpleMaterial(color: .red, isMetallic: false)]
//        )
//
//        anchor.addChild(sphere)
//        arView.scene.addAnchor(anchor)
//
//        let p = worldTransform.columns.3
//        print("Spawned at x:\(p.x) y:\(p.y) z:\(p.z)")
//    }
    
    private func spawnOrUpdatePlayerIfReady(id: String) {
        guard let pos = pendingPositions[id],
              sessionStartCameraTransform != nil else { return }

        spawnOrUpdatePlayer(id: id, position: pos)
    }
    
    func spawnOrUpdatePlayer(id: String, position: SIMD3<Float>) {
        guard id != MultiplayerService.shared.playerID else { return }

        guard let origin = sessionStartCameraTransform else {
            print("Session start camera not set yet")
            return
        }

        print("RENDER:", id, position)

        // Convert server offset → world transform
        let worldTransform = simd_float4x4(translation: position)

        let t = Transform(matrix: worldTransform)

        DispatchQueue.main.async {
            if let anchor = self.playerAnchors[id] {
                // ✅ MOVE every update
                anchor.transform = t
                return
            }

            // ✅ SPAWN once
            let anchor = AnchorEntity(world: worldTransform)

            let model = ModelEntity(
                mesh: .generateSphere(radius: 0.15),
                materials: [SimpleMaterial(color: .red, isMetallic: false)]
            )

            anchor.addChild(model)
            self.arView.scene.addAnchor(anchor)
            self.playerAnchors[id] = anchor

            print("Spawned player:", id)
        }
    }
    
    private func spawnAllPlayers() {
        for player in MultiplayerService.shared.players.values {
            spawnOrUpdatePlayer(
                    id: player.id,
                    position: player.position
                )
            }
    }
    
    
    // MARK: - Manual Local Spawn (Debug)
    @IBAction func spawnPlayer(_ sender: UIButton) {
        print("Spawn button pressed")
        guard let origin = sessionStartCameraTransform else {
            print("Session start camera not set yet")
            return
        }
        
        
        // Local offset relative to session start camera
        let localOffset = SIMD3<Float>(1, 1, -1) // 1 meter forward

        // Convert local offset → world transform
        let worldTransform =
            simd_mul(origin, simd_float4x4(translation: localOffset))

        let anchor = AnchorEntity(world: worldTransform)

        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 0.15),
            materials: [SimpleMaterial(color: .red, isMetallic: false)]
        )

        anchor.addChild(sphere)
        arView.scene.addAnchor(anchor)

        let p = worldTransform.columns.3
        print("Spawned at x:\(p.x) y:\(p.y) z:\(p.z)")
    }
    
    @IBAction func setSharedOriginTapped(_ sender: UIButton) {
        guard let frame = arView.session.currentFrame,
              case .normal = frame.camera.trackingState else {
            print("Tracking not ready — cannot set origin")
            return
        }

        sharedOriginTransform = frame.camera.transform
        isSharedOriginSet = true

        print("Shared origin set")

        // Optional: visualize the origin
        let anchor = AnchorEntity(world: frame.camera.transform)
        let marker = ModelEntity(
            mesh: .generateSphere(radius: 0.05),
            materials: [SimpleMaterial(color: .green, isMetallic: false)]
        )
        anchor.addChild(marker)
        arView.scene.addAnchor(anchor)
    }
    
//    @IBAction func showPlayers(_ sender: UIButton) {
//        MultiplayerService.shared.playerLocation()
//    }
}

extension simd_float4x4 {
    init(translation: SIMD3<Float>) {
        self = matrix_identity_float4x4
        columns.3 = SIMD4<Float>(translation.x, translation.y, translation.z, 1)
    }
}
