//
//  MultiplayerService.swift
//  IRLGame
//
//  Created by Srinivas Sankaranarayanan on 12/22/25.
//
//  MultiplayerService deals with the calculations and updates to players status and locations.
import Foundation
import CoreLocation
import simd

struct RemotePlayer {
    let id: String
    var position: SIMD3<Float>
    var lastUpdated: Int
    var dx: Float
    var dy: Float
    var dz: Float
}

final class MultiplayerService {

    static let shared = MultiplayerService()
    private init() {}
    
    // Dictionary of players with their UUID as key and their RemotePlayer object as value.
    private(set) var players: [String: RemotePlayer] = [:]

    private let calibrationSamplesNeeded = 15
    private var calibrationSampleCount = 0
    private var calibrationSum = SIMD3<Float>(repeating: 0)
    private var isCalibrated = false
    private var lastOriginKey: String?
    
    // Set of intructions to do when specific event happens.
    var onPlayerUpdated: ((RemotePlayer) -> Void)?
    var onPlayerRemoved: ((String) -> Void)?
    
    // The UUID of the local player.
    let playerID: String = {
        if let id = UserDefaults.standard.string(forKey: "player_id") {
            return id
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "player_id")
        return id
    }()

    // Processes a PLAYERS_UPDATE payload from the server and routes each entry to
    // add/update logic. This function validates the payload shape, extracts the
    // local player's entry for relative positioning, and then iterates all players.
    // Existing players are updated via handleSinglePlayerEntry while new players
    // are initialized with addPlayer.
    func handlePlayer(_ json: [String: Any]) {
        guard let type = json["type"] as? String, type == "PLAYERS_UPDATE",
              let locations = json["locations"] as? [String: [String: Any]],
            let timestamp = json["timestamp"] as? Int else {
            print("Invalid PLAYERS_UPDATE payload")
            return
        }
        let myID = playerID
        guard let localPlayer = locations[myID] else {
            print("Local Player Not found in JSON")
            return
        }
        for (id, remotePlayer) in locations {
            if (players[id] != nil) {
                handleSinglePlayerEntry(remotePlayer, localPlayer, timestamp: timestamp)
            } else {
                addPlayer(remotePlayer, timestamp: timestamp)
            }
        }
    }
    
    // Initializes a RemotePlayer from a raw player payload. This computes a GPS-based
    // offset between the player's current location and their origin, which is used to
    // compensate for location drift. The resulting RemotePlayer is inserted into the
    // players dictionary with an initial position at the local origin.
    func addPlayer(_ player: [String: Any], timestamp: Int) {
        guard
            let id = player["playerID"] as? String,
            let location = player["location"] as? [String: Any],
            let lat = (location["lat"] as? NSNumber)?.floatValue,
            let lon = (location["lon"] as? NSNumber)?.floatValue,
            let alt = (location["alt"] as? NSNumber)?.floatValue,
            let origin = player["origin"] as? [String: Any],
            let originLat = (origin["lat"] as? NSNumber)?.floatValue,
            let originLon = (origin["lon"] as? NSNumber)?.floatValue,
            let originAlt = (origin["alt"] as? NSNumber)?.floatValue
        else {
            print("Invalid Player Data", player)
            return
        }
        
        let playerTimestamp = Date(timeIntervalSince1970: TimeInterval(timestamp))
        
        // Makes a CLLocation Object with the players current location and altitude
        let playerCoordinate = CLLocationCoordinate2D(latitude: CLLocationDegrees(lat), longitude: CLLocationDegrees(lon))
        let playerAltitude = CLLocationDistance(alt)
        let playerCurrentLocation = CLLocation(coordinate: playerCoordinate, altitude: playerAltitude, horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: playerTimestamp)
        
        // Makes a CLLocation Object with the players origin location and altitude
        let playerOriginCoordinate = CLLocationCoordinate2D(latitude: CLLocationDegrees(originLat), longitude: CLLocationDegrees(originLon))
        let playerOriginAltitude = CLLocationDistance(originAlt)
        let playerOriginLocation = CLLocation(coordinate: playerOriginCoordinate, altitude: playerOriginAltitude, horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: playerTimestamp)
        
        // Since this is function is called at the beginning of the game, player will physically be at the same spot so in an ideal world the postion should be zero is all axis(0,0,0) but due to hardware limitations and accuracy issues with using GPS data the position will be some number (x, y, z) so we uses this difference as the offset for that player.
        //Problem Area Right here.
        //lets implement averaging
        
        let playerOffset = geoToLocal(playerCurrentLocation, playerOriginLocation)
        let position = SIMD3<Float> (0,0,0)
        
        // Creates a RemotePlayer object for the player
        let player = RemotePlayer(
            id: id,
            position: position,
            lastUpdated: timestamp,
            dx: Float(playerOffset.x),
            dy: Float(playerOffset.y),
            dz: Float(playerOffset.z)
        )
        players[id] = player
    }
    
    // Updates a single remote player using a pair of payloads: the remote player's
    // data and the local player's data from the same PLAYERS_UPDATE message. The
    // function converts GPS coordinates to local ENU space, applies each player's
    // stored offset, and computes a relative vector from local to remote. It also
    // runs a local calibration pass by averaging local ENU samples after origin
    // changes, then persists the resulting offset. The remote player's position
    // is updated and the update callback is invoked.
    func handleSinglePlayerEntry(_ remotePlayer: [String: Any],_ localPlayer: [String: Any], timestamp: Int) {
        // Breaks down the JSON of localPlayer and remotePlayer
        guard
            // Gets the id, current location, and origin location for the remotePlayer
            let id = remotePlayer["playerID"] as? String,
            var remotePlayerObject = players[id],
            let location = remotePlayer["location"] as? [String: Any],
            let lat = (location["lat"] as? NSNumber)?.floatValue,
            let lon = (location["lon"] as? NSNumber)?.floatValue,
            let alt = (location["alt"] as? NSNumber)?.floatValue,
            let origin = remotePlayer["origin"] as? [String: Any],
            let originLat = (origin["lat"] as? NSNumber)?.floatValue,
            let originLon = (origin["lon"] as? NSNumber)?.floatValue,
            let originAlt = (origin["alt"] as? NSNumber)?.floatValue,
            
            // Gets the current location, and origin location for the localPlayer
            let localPlayerID = localPlayer["playerID"] as? String,
            var localPlayerObject = players[localPlayerID],
            let localPlayerLocation = localPlayer["location"] as? [String: Any],
            let localPlayerLat = (localPlayerLocation["lat"] as? NSNumber)?.floatValue,
            let localPlayerLon = (localPlayerLocation["lon"] as? NSNumber)?.floatValue,
            let localPlayerAlt = (localPlayerLocation["alt"] as? NSNumber)?.floatValue,
            let localPlayerOrigin = localPlayer["origin"] as? [String: Any],
            let localPlayerOriginLat = (localPlayerOrigin["lat"] as? NSNumber)?.floatValue,
            let localPlayerOriginLon = (localPlayerOrigin["lon"] as? NSNumber)?.floatValue,
            let localPlayerOriginAlt = (localPlayerOrigin["alt"] as? NSNumber)?.floatValue
        else {
            print("Invalid Player Position entry:", remotePlayer, localPlayer)
            return
        }

        let currentOriginKey = originKey(lat: localPlayerOriginLat, lon: localPlayerOriginLon, alt: localPlayerOriginAlt)
        if currentOriginKey != lastOriginKey {
            resetCalibration()
            lastOriginKey = currentOriginKey
            localPlayerObject.dx = 0
            localPlayerObject.dy = 0
            localPlayerObject.dz = 0
        }
        
        // localPlayer Current Location Object Creation
        let localPlayerCurrentCoordinate = CLLocationCoordinate2D(latitude: CLLocationDegrees(localPlayerLat), longitude: CLLocationDegrees(localPlayerLon))
        let localPlayerCurrentAltitude = CLLocationDistance(localPlayerAlt)
        let localPlayerCurrentTimestamp = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let localPlayerCurrentLocationObject = CLLocation(coordinate: localPlayerCurrentCoordinate, altitude: localPlayerCurrentAltitude, horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: localPlayerCurrentTimestamp)
        
        // localPlayer Origin Location Object Creation
        let locatPlayerOriginCoordinate = CLLocationCoordinate2D(latitude: CLLocationDegrees(localPlayerOriginLat), longitude: CLLocationDegrees(localPlayerOriginLon))
        let localPlayerOriginAltitude = CLLocationDistance(localPlayerOriginAlt)
        let localPlayerOriginTimestamp = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let localPlayerOriginLocationObject = CLLocation(coordinate: locatPlayerOriginCoordinate, altitude: localPlayerOriginAltitude, horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: localPlayerOriginTimestamp)
        
        // remotePlayer Current Location Object Creation
        let remotePlayerCurrentCoordinate = CLLocationCoordinate2D(latitude: CLLocationDegrees(lat), longitude: CLLocationDegrees(lon))
        let remotePlayerCurrentAltitude = CLLocationDistance(alt)
        let remotePlayerCurrentTimestamp = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let remotePlayerCurrentLocationObject = CLLocation(coordinate: remotePlayerCurrentCoordinate, altitude: remotePlayerCurrentAltitude, horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: remotePlayerCurrentTimestamp)
        
        // remotePlayer Origin Location Object Creation
        let remotePlayerOriginCoordinate = CLLocationCoordinate2D(latitude: CLLocationDegrees(originLat), longitude: CLLocationDegrees(originLon))
        let remotePlayerOriginAltitude = CLLocationDistance(originAlt)
        let remotePlayerOriginTimestamp = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let remotePlayerOriginLocationObject = CLLocation(coordinate: remotePlayerOriginCoordinate, altitude: remotePlayerOriginAltitude,horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: remotePlayerOriginTimestamp)
        
        
        // Stores a SIMD3<Float> (x, y, z) position from localPlayer origin to their current location
        let localPlayerPoint = geoToLocal(localPlayerCurrentLocationObject, localPlayerOriginLocationObject)
        if !isCalibrated {
            calibrationSum += localPlayerPoint
            calibrationSampleCount += 1
            if calibrationSampleCount >= calibrationSamplesNeeded {
                let sampleCount = Float(calibrationSampleCount)
                let average = calibrationSum / sampleCount
                localPlayerObject.dx = average.x
                localPlayerObject.dy = average.y
                localPlayerObject.dz = average.z
                isCalibrated = true
            }
        }
        players[localPlayerID] = localPlayerObject
        // Applies localPlayer offset to their position
        let localPlayerPointWithOffset = SIMD3<Float> (localPlayerPoint.x - localPlayerObject.dx, localPlayerPoint.y - localPlayerObject.dy, localPlayerPoint.z - localPlayerObject.dz)
        
        // Stores a SIMD3<Float> (x, y, z) position from remotePlayer origin to their current location
        let remotePlayerPoint = geoToLocal(remotePlayerCurrentLocationObject, remotePlayerOriginLocationObject)
        // Applies remotePlayer offset to their position
        let remotePlayerPointWithOffset = SIMD3<Float> (remotePlayerPoint.x - remotePlayerObject.dx, remotePlayerPoint.y - remotePlayerObject.dy, remotePlayerPoint.z - remotePlayerObject.dz)
        
        // Gets the localPlayer heading and makes sure it's not null.
        guard let localPlayerHeading = LocationService.shared.lastHeadingDeg else {
            print("Local player heading is nil")
            return
        }
        
        let positionFromLocalPlayerToRemotePlayer = SIMD3<Float> (remotePlayerPointWithOffset.x - localPlayerPointWithOffset.x, remotePlayerPointWithOffset.y - localPlayerPointWithOffset.y, remotePlayerPointWithOffset.z - localPlayerPointWithOffset.z)
        
        remotePlayerObject.position = positionFromLocalPlayerToRemotePlayer
        
        players[id] = remotePlayerObject
        onPlayerUpdated?(remotePlayerObject)
        
        print("Remote Player Location Updated:", id, positionFromLocalPlayerToRemotePlayer)
    }
    
    
    // Converts a geodetic location (lat/lon/alt) into ECEF coordinates. The ECEF
    // frame is Earth-centered, Earth-fixed and is used as an intermediate step
    // for computing local tangent plane vectors (ENU).
    func geoToECEF(_ location: CLLocation) -> SIMD3<Float> {
        let a = 6378137.0;
        let e2 = 6.69437999014e-3;

        let latRad = location.coordinate.latitude * Double.pi / 180
        let lonRad = location.coordinate.longitude * Double.pi / 180
        let alt = location.altitude
        
        let sinLat = sin(latRad)
        let cosLat = cos(latRad)
        let sinLon = sin(lonRad)
        let cosLon = cos(lonRad)

        let N = a / sqrt(1 - e2 * sinLat * sinLat)

        let x = Float((N + alt) * cosLat * cosLon)
        let y = Float((N + alt) * cosLat * sinLon)
        let z = Float((N * (1 - e2) + alt) * sinLat)

        let position = SIMD3<Float>(x, y, z)
        
        return position
    }
    
    // Converts an ECEF position to a local ENU vector relative to a given origin.
    // This uses the origin's latitude and longitude to build the local tangent
    // frame and returns a vector where x = east, y = up, z = north.
    func ecefToENU(_ currentLocationECEF: SIMD3<Float>, _ originECEF: SIMD3<Float>, _ origin: CLLocation) -> SIMD3<Float> {
        let lat0 = origin.coordinate.latitude * Double.pi / 180
        let lon0 = origin.coordinate.longitude * Double.pi / 180
        
        let dx = Double(currentLocationECEF.x - originECEF.x)
        let dy = Double(currentLocationECEF.y - originECEF.y)
        let dz = Double(currentLocationECEF.z - originECEF.z)

        let sinLat = sin(lat0)
        let cosLat = cos(lat0)
        let sinLon = sin(lon0)
        let cosLon = cos(lon0)

        let east = (-sinLon * dx) + (cosLon * dy)
        let north = (-sinLat * cosLon * dx) - (sinLat * sinLon * dy) + (cosLat * dz)
        let up = (cosLat * cosLon * dx) + (cosLat * sinLon * dy) + (sinLat * dz)

        let position = SIMD3<Float>(Float(east), Float(up), Float(north))
        return position
    }
    
    // Computes a local ENU vector from a world location to an origin using a
    // geo -> ECEF -> ENU conversion pipeline. This is the primary helper used
    // to translate GPS coordinates into the game's local coordinate frame.
    func geoToLocal(_ playerLocation: CLLocation, _ playerOrigin: CLLocation) -> SIMD3<Float> {
        let originECEF = geoToECEF(playerOrigin)
        let pointECRF = geoToECEF(playerLocation)
        
        let position = ecefToENU(pointECRF, originECEF, playerOrigin)
        return position
    }
    
    // Rotates a local ENU vector by a heading angle in degrees. This converts
    // the world-aligned ENU frame into a device-aligned AR frame by rotating
    // around the vertical axis (Y).
    func rotatePosition(_ position: SIMD3<Float>, _ headingDeg: Double) -> SIMD3<Float> {
        let psi = headingDeg * Double.pi / 180
        let theta = -psi

        let cosT = cos(theta)
        let sinT = sin(theta)

        let x2 = position.x * Float(cosT) + position.z * Float(sinT)
        let y2 = position.y
        let z2 = -position.x * Float(sinT) + position.z * Float(cosT)

        let ARPosition = SIMD3<Float>(x2, y2, z2)
        return ARPosition
    }

    // Produces a stable string key for an origin location. This is used to detect
    // when the shared origin changes so calibration can be reset and recomputed.
    private func originKey(lat: Float, lon: Float, alt: Float) -> String {
        return String(format: "%.6f|%.6f|%.2f", lat, lon, alt)
    }

    // Clears calibration state so a new averaged offset can be collected.
    private func resetCalibration() {
        calibrationSampleCount = 0
        calibrationSum = SIMD3<Float>(repeating: 0)
        isCalibrated = false
    }
    
//    func handleARPositions(_ json: [String: Any]) {
//        guard
//            let locations = json["locations"] as? [[String: Any]]
//        else {
//            print("Invalid AR_POSITIONS payload")
//            return
//        }
//
//        let myID = MultiplayerService.shared.playerID
//
//        for entry in locations {
//            guard let id = entry["playerID"] as? String,
//                    id != myID,
//                    let timestamp = json["timestamp"] as? Int else {
//                continue
//            }
//            //print("Single Entry", entry)
//            handleSingleARPlayerEntry(entry, timestamp: timestamp)
//        }
//    }
//    
//    func handleSingleARPlayerEntry(_ entry: [String: Any], timestamp: Int) {
//        guard
//            let id = entry["playerID"] as? String,
//            let location = entry["location"] as? [String: Any],
//            let x = (location["x"] as? NSNumber)?.floatValue,
//            let y = (location["y"] as? NSNumber)?.floatValue,
//            let z = (location["z"] as? NSNumber)?.floatValue
//        else {
//            print("Invalid AR player entry:", entry)
//            return
//        }
//
//        let position = SIMD3<Float>(x, y, z)
//        let player = RemotePlayer(
//            id: id,
//            position: position,
//            lastUpdated: timestamp
//        )
//
//        players[id] = player
//        onPlayerUpdated?(player)
//
//        print("Remote Player:", id, position)
//    }
    
    private func send(_ payload: [String: Any]) {
        //print("Sending Payload: ", payload)
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }

        WebSocketManager.shared.send(text: json)
    }
}
