//
//  WebSocketManager.swift
//  IRLGame
//
//  Created by Srinivas Sankaranarayanan on 12/19/25.
//

import Foundation

final class WebSocketManager {
    
    static let shared = WebSocketManager()
    
    var onText: ((String) -> Void)?
    private var webSocketTask: URLSessionWebSocketTask!
    private let session = URLSession(configuration: .default)
    
    
    func connect() {
        guard let url = URL(string: "wss://domical-kasi-aguishly.ngrok-free.dev/socket") else { return }

        webSocketTask = session.webSocketTask(with: url)
        webSocketTask.resume()

        listen()
        print("WebSocket connected")
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        print("WebSocket disconnected")
    }
    
    func send(text: String) {
        let message = URLSessionWebSocketTask.Message.string(text)
        webSocketTask.resume()
        webSocketTask.send(message) { error in
            if let error = error {
                print("Error sending message: \(error.localizedDescription)")
            }
        }
    }
    
    private func listen() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    //print("Received:", text)
                    self?.onText?(text)
                    self?.handleMessage(text)
//                case .data(let data):
//                    print("Received data:", data)
                @unknown default:
                    break
                }
                self?.listen()

            case .failure(let error):
                print("WebSocket receive error:", error)
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            print("Invalid message format")
            return
        }
        
        switch type {
        case "GAME_STARTED":
            print("Server says game started")
            DispatchQueue.main.async {
                GameService.shared.onGameStarted()
            }
            
        case "GAME_ENDED":
            print("Server ended game")
            DispatchQueue.main.async {
                GameService.shared.onGameEnded()
            }
            
        case "PLAYERS_UPDATE":
            print("Player Location Update Recieved")
            MultiplayerService.shared.handlePlayersUpdate(json)
                        
        default:
            print("Unhandled event: ", type)
        }
    }
}


