//
//  MultiplayerService.swift
//  IRLGame
//
//  Created by Srinivas Sankaranarayanan on 12/22/25.
//

import Foundation
import CoreLocation
import simd

struct RemotePlayer {
    let id: String
    var position: SIMD3<Float>
    var lastUpdated: Date
}

final class MultiplayerService {

    static let shared = MultiplayerService()
    private init() {}
    
    private(set) var players: [String: RemotePlayer] = [:]
    
    var onPlayerUpdated: ((RemotePlayer) -> Void)?
    var onPlayerRemoved: ((String) -> Void)?

    let playerID: String = {
        if let id = UserDefaults.standard.string(forKey: "player_id") {
            return id
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "player_id")
        return id
    }()

    
    // MARK: - Sending
    func sendLocation(_ location: CLLocation) {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        send([
            "playerID": playerID,
            "type": "LOCATION_UPDATE",
            "location": [
                "lat": location.coordinate.latitude,
                "lon": location.coordinate.longitude,
                "alt": location.altitude,
            ],
            "timestamp": timestamp
        ])
    }

    func sendPlayerMove(_ pos: SIMD3<Float>) {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        send([
            "id": playerID,
            "type": "player_move",
            "position": [
                        "x": pos.x,
                        "y": pos.y,
                        "z": pos.z
            ],
            "timestamp": timestamp
        ])
    }

    private func send(_ payload: [String: Any]) {
        print("Sending Payload: ", payload)
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }

        WebSocketManager.shared.send(text: json)
    }
}
