//
//  GameService.swift
//  IRLGame
//
//  Created by Srinivas Sankaranarayanan on 12/22/25.
//

import Foundation

final class GameService {
    static let shared = GameService()
    private init() {}
    
    private(set) var isGameActive = false
    
    let playerID = MultiplayerService.shared.playerID
    
    // MARK: Client Requests
    func createGame() {
        print("Game Created")
        WebSocketManager.shared.connect()
        send([
            "type": "CREATE_GAME",
            "playerID": playerID
        ])
    }
    
    func startGame() {
        print("Game Started")
        send([
            "type": "START_GAME",
            "playerID": playerID
        ])
    }
    
    func joinGame(id: String) {
        print("Joining Game: ", id)
        WebSocketManager.shared.connect()
        send([
            "type": "JOIN_GAME",
            "playerID": playerID,
            "gameID": id
        ])
    }

    func leaveGame() {
        print("You have left the game")
        send([
            "type": "LEAVE_GAME",
            "playerID": playerID,
        ])
    }
    
    func endGame() {
        print("Game ended")
        send([
            "type": "END_GAME",
            "playerID": playerID,
        ])
    }
    
    func arViewStart() {
        print("AR View Started")
        WebSocketManager.shared.connect()
    }
    
    
    // MARK: Server Callbacks
    func onGameStarted() {
        print("Game ACTIVE - Starting location updates")
//        LocationService.shared.start()
    }
    
    func onGameEnded() {
        print("Game INACTIVE - Stopping location updates")
//        LocationService.shared.stop()
    }
    
    private func send(_ payload: [String: Any]) {
        print("Sending Payload: ", payload)
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }

        WebSocketManager.shared.send(text: json)
    }
}
