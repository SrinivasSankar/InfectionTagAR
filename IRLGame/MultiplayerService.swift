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
    var lastUpdated: Int
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
//    func sendLocation(_ location: CLLocation) {
//        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
//        send([
//            "playerID": playerID,
//            "type": "LOCATION_UPDATE",
//            "location": [
//                "lat": location.coordinate.latitude,
//                "lon": location.coordinate.longitude,
//                "alt": location.altitude,
//            ],
//            "timestamp": timestamp
//        ])
//    }
    
    func handlePlayersUpdate(_ json: [String: Any]) {
        //print("Player Location Update Received")

        guard let locations = json["locations"] as? [[String: Any]],
              let timestamp = json["timestamp"] as? Int else {
            print("Invalid PLAYERS_UPDATE payload")
            return
        }
        
        let myID = MultiplayerService.shared.playerID

        for entry in locations {
            guard let id = entry["playerID"] as? String,
                  id != myID else {
                continue
            }
            handleSinglePlayerEntry(entry, timestamp: timestamp)
        }
    }
    
    func handleSinglePlayerEntry(_ entry: [String: Any], timestamp: Int) {
        guard let id = entry["playerID"] as? String,
              let location = entry["location"] as? [String: Any],
              // Lon - Up/Down, Lat - Left/Right, Alt - Forward/Backward
              let x = (location["x"] as? NSNumber)?.floatValue,
              let y = (location["y"] as? NSNumber)?.floatValue,
              let z = (location["z"] as? NSNumber)?.floatValue else {
            print("Invalid player entry in PLAYERS_UPDATE:", entry)
            return
        }

        // If you truly want to treat lat/lon/alt as x/y/z:
        let position = SIMD3<Float>(x, y, z)

        let player = RemotePlayer(
            id: id,
            position: position,
            lastUpdated: timestamp
        )

        players[id] = player
        onPlayerUpdated?(player)

        print("Player ID:", id)
        //print("Player position:", position)
    }
    
//    func handlePlayerMove(_ json: [String: Any]) {
//        print("Handle Player Move Called")
//        guard let id = json["playerID"] as? String,
//                  let positionDict = json["location"] as? [String: Any],
//                  let x = positionDict["x"] as? Float,
//                  let y = positionDict["y"] as? Float,
//                  let z = positionDict["z"] as? Float,
//                  let time = json["timestamp"] as? Int else {
//                print("Invalid LOCATION_UPDATE payload")
//                return
//        }
//        let position = SIMD3<Float>(x, y, z)
//        let player = RemotePlayer(
//            id: id,
//            position: position,
//            lastUpdated: time
//        )
//
//        players[id] = player
//        DispatchQueue.main.async {
//                self.onPlayerUpdated?(player)
//            }
//        print("Player ID: ", id)
//        //print("Player position: ", position)
//    }


    func sendPlayerMove(_ pos: SIMD3<Float>) {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        send([
            "playerID": playerID,
            "type": "LOCATION_UPDATE",
            "location": [
                        "x": pos.x,
                        "y": pos.y,
                        "z": pos.z
            ],
            "timestamp": timestamp
        ])
    }
    
    func playerLocation() {
        print("Single Player location request")
        send([
            "type": "SHOW_PLAYERS",
            "playerID": playerID
        ])
    }
    
    
    private func send(_ payload: [String: Any]) {
        //print("Sending Payload: ", payload)
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }

        WebSocketManager.shared.send(text: json)
    }
}
