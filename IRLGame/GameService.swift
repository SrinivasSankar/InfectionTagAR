//
//  GameService.swift
//  IRLGame
//
//  Created by Srinivas Sankaranarayanan on 12/22/25.
//
//  GameService deals with the settings and status of the current game in session.

import Foundation
import CoreLocation


final class GameService {
    static let shared = GameService()
    private init() {}
    
    private var locationSendTimer: Timer?
    
    var isGameActive = false
    
    var gameID: String?
    var origin: CLLocation?
    var currentLocation: CLLocation?

    
    var gameStartedHandler: (() -> Void)?
    var gameEndedHandler: (() -> Void)?
    
    let playerID = MultiplayerService.shared.playerID
    
    // MARK: Client Requests
    
    // Sends a create lobby request to server with host ID
    func createGame() {
        print("Game Created")
        WebSocketManager.shared.connect()
        
        send([
            "type": "CREATE_GAME",
            "playerID": playerID,
        ])
    }
    
    // Sends a start game request to the server with host ID
    func startGame() {
        print("Game Started")
        send([
            "type": "START_GAME",
            "playerID": playerID
        ])
    }
    
    // Sends a join game request with the player ID of person joining and game ID of game to join
    func joinGame(id: String) {
        print("Joining Game: ", id)
        WebSocketManager.shared.connect()
        send([
            "type": "JOIN_GAME",
            "playerID": playerID,
            "gameID": id
        ])
        
    }

    // Sends a request to the server to remove the current player
    func leaveGame() {
        print("You have left the game")
        send([
            "type": "LEAVE_GAME",
            "playerID": playerID,
        ])
        WebSocketManager.shared.disconnect()
    }
    
    // Sends a request to the server to end the game
    func endGame() {
        print("Game ended")
        send([
            "type": "END_GAME",
            "playerID": playerID,
        ])
        WebSocketManager.shared.disconnect()
    }
    
    func startSendingLocationEveryHalfSecond() {
        locationSendTimer?.invalidate()

        locationSendTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            guard
                self.isGameActive,
                let loc = LocationService.shared.lastLocation
            else { return }

            self.currentLocation = loc

            self.send([
                "type": "LOCATION_UPDATE",
                "playerID": self.playerID,
                "location": [
                    "lat": loc.coordinate.latitude,
                    "lon": loc.coordinate.longitude,
                    "alt": loc.altitude,
                    "heading": LocationService.shared.lastHeadingDeg,
                    "headingAccuracy": LocationService.shared.lastHeadingAccuracy
                ]
            ])
            print("Location Sent: ", self.playerID)
        }
        print("Started sending location every 0.5s")
    }
    
    func sendPosition() {
        let players = MultiplayerService.shared.players
        
        for player in players {
            if (player.key != playerID) {
                let player = MultiplayerService.shared.players[player.key]!
                send([
                    "type": "LOCAL_POSITIONS",
                    "playerID": player.id,
                    "location": [
                        "x": player.position.x,
                        "y": player.position.y,
                        "z": player.position.z
                    ],
                    "timestamp": player.lastUpdated
                ])
            }
        }
    }
    
    func startAR() {
        guard
            self.isGameActive,
            let loc = LocationService.shared.lastLocation
        else { return }

        self.currentLocation = loc

        self.send([
            "type": "START_AR",
            "playerID": self.playerID,
            "location": [
                "lat": loc.coordinate.latitude,
                "lon": loc.coordinate.longitude,
                "alt": loc.altitude,
                "heading": LocationService.shared.lastHeadingDeg,
                "headingAccuracy": LocationService.shared.lastHeadingAccuracy
            ]
        ])
    }
        
    func setOrigin(_ location: CLLocation) {
        print("setOrigin function called")
        origin = location
    }
    
    // MARK: Server Callbacks
    func onGameStarted() {
        isGameActive = true
        LocationService.shared.startLocationAndHeadingUpdates()
        startSendingLocationEveryHalfSecond()
        print("Game ACTIVE - Starting location updates")
    }
    
    func onGameEnded() {
        print("Game INACTIVE - Stopping location updates")
        isGameActive = false
        LocationService.shared.stopLocationUpdates()
        print("Handler exists:", gameEndedHandler != nil)
        gameEndedHandler?()
    }
    
    // Function used to send requests to the server through WebSocket
    private func send(_ payload: [String: Any]) {
        //print("Sending Payload: ", payload)
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }

        WebSocketManager.shared.send(text: json)
    }
}
