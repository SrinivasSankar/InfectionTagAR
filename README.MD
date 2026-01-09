# InfectionTagAR

iOS AR multiplayer game prototype that uses GPS + heading to place remote players in AR. The app connects to a WebSocket server, exchanges player locations/origins, computes relative offsets, and renders remote players as RealityKit spheres.

## Quick start
- Open `IRLGame.xcodeproj` in Xcode.
- Select a physical device (ARKit + location + camera required).
- Ensure location and camera permissions are granted.
- Run the app, create/join a game, then start AR.

## Project layout
- `IRLGame/HomeViewController.swift`: Home screen UI actions (create/join/start/end game, start AR).
- `IRLGame/ARViewController.swift`: AR session management and remote player rendering.
- `IRLGame/GameService.swift`: Game lifecycle and outbound requests to server.
- `IRLGame/WebSocketManager.swift`: WebSocket connection and inbound message routing.
- `IRLGame/LocationService.swift`: GPS + heading collection, smoothing, and state.
- `IRLGame/MultiplayerService.swift`: Geo math, offsets, and per-player state.
- `IRLGame/Main.storyboard`: UI layout and connections.
- `IRLGame/Assets.xcassets`: App assets.
- `IRLGameTests`, `IRLGameUITests`: Default Xcode test stubs.

## Runtime flow
1) Home screen triggers `GameService` actions.
2) `WebSocketManager` connects and receives server events.
3) On `GAME_STARTED`, `LocationService` starts updates and `GameService` begins sending `LOCATION_UPDATE` every 0.5s.
4) Server sends `PLAYERS_UPDATE` with all players' locations + origins.
5) `MultiplayerService` converts GPS deltas into a local ENU frame, subtracts per-player offsets, and produces a relative vector from local to remote.
6) `ARViewController` spawns or updates RealityKit anchors for each remote player.

## Data protocol summary
Outbound (client -> server):
- `CREATE_GAME`, `JOIN_GAME`, `START_GAME`, `END_GAME`, `LEAVE_GAME`
- `LOCATION_UPDATE` with `lat`, `lon`, `alt`, and heading fields
- `START_AR`
- `LOCAL_POSITIONS` (currently sent after `PLAYERS_UPDATE`)

Inbound (server -> client):
- `GAME_STARTED`, `GAME_ENDED`, `GAMEID`
- `PLAYERS_UPDATE` (contains `locations` and `timestamp`)

## Location and math
- GPS coordinates are converted to ECEF, then to ENU via `geoToECEF` and `ecefToENU`.
- ENU is mapped to AR as `x = east`, `y = up`, `z = north`.
- Each `RemotePlayer` stores an offset (`dx`, `dy`, `dz`) derived from the player’s initial origin/location to reduce GPS noise.
- `rotatePosition` exists for heading correction but is not currently applied in `handleSinglePlayerEntry`.

## AR rendering
- `ARViewController` starts an ARWorldTracking session with gravity alignment.
- `sessionStartCameraTransform` is captured once tracking stabilizes.
- Remote players are spawned/updated as RealityKit `AnchorEntity` objects with simple sphere meshes.

## Configuration
- WebSocket endpoint is hard-coded in `IRLGame/WebSocketManager.swift`.
- Location updates are sent every 0.5s while the game is active.

## Known issues and risks
- `PLAYERS_UPDATE` handling is delayed by 5 seconds and also triggers `LOCAL_POSITIONS` sends for every remote player, which can cause latency and echo/stale data (`IRLGame/WebSocketManager.swift`).
- Heading is captured but never applied to the relative position vector, so remote placement will be rotated if the user is not facing north at AR start (`IRLGame/MultiplayerService.swift`).
- Remote anchors are created without applying `sessionStartCameraTransform`, so remote players are not transformed into the AR world frame (`IRLGame/ARViewController.swift`).
- `sharedOriginTransform` is set from a UI action but is not currently used to place remote players (`IRLGame/ARViewController.swift`).
- WebSocket URL is hard-coded and not environment-configurable (`IRLGame/WebSocketManager.swift`).
- There is no persistence or reconnection strategy for network drops.
- Tests are default stubs and do not cover the multiplayer flow or geo math.

## Notes for future work
- Clarify the authoritative origin/offset strategy (admin origin vs. per-player origin vs. AR session origin).
- Document the server payload contract and add versioning or feature flags.
- Add instrumentation for latency and drop rates in `PLAYERS_UPDATE`.
- Consider decoupling UI actions from networking for better testability.
