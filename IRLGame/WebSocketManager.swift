//
//  WebSocketManager.swift
//  IRLGame
//
//  Created by Srinivas Sankaranarayanan on 12/19/25.
//

import Foundation

final class WebSocketManager {
    
    static let shared = WebSocketManager()
    
    private var webSocketTask: URLSessionWebSocketTask!
    private var session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: .default)
    }
    
    func connect() {
        guard let url = URL(string: "wss://domical-kasi-aguishly.ngrok-free.dev/socket") else { return }

        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

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
                        print("Received:", text)
                    case .data(let data):
                        print("Received data:", data)
                    @unknown default:
                        break
                    }

                    // KEEP LISTENING (important)
                    self?.listen()

                case .failure(let error):
                    print("WebSocket receive error:", error)
                }
            }
        }
}


