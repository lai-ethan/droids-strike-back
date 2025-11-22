# OMI Arena - Quick Start Guide

## 🎮 What It Is
Real-time multiplayer tag game using OMI Dev Kit 2 wearables with Convex backend.

## 📱 Setup (iOS App)

### 1. Open in Xcode
- Open `OMIArena.xcodeproj` 
- Select physical iPhone (Bluetooth doesn't work in simulator)

### 2. Build & Run
- Connect iPhone via USB
- Select your device from dropdown
- Build and run

### 3. App Flow
1. **Enter Player Name** → Creates player profile
2. **Join/Create Room** → Use 6-digit code or create new room  
3. **Connect OMI Device** → Scan for device or use mock data
4. **Start Game** → Host starts when 2+ players join
5. **Play Tag** → Get close to other players and press TAG

## 🔧 Backend (Convex)

### Local Development
```bash
npm install
npm run dev  # Uses --typecheck=disable due to index warnings
```

### Production
- URL: `https://efficient-deer-600.convex.cloud`
- Functions: `/api/run/createPlayer`, `/api/run/createRoom`, etc.

## 🔌 OMI Dev Kit 2

- **Power**: USB-C (for charging only)
- **Connection**: Bluetooth LE to iPhone
- **Setup**: Power on, scan in app
- **Mock Data**: Available for testing without hardware

## 🐛 Known Issues

- **Simulator**: No Bluetooth support - use physical iPhone
- **Backend**: TypeScript warnings (functional despite warnings)
- **Convex API**: Use `/api/run/functionName` format, not REST

## 📁 Key Files

```
OMIArena/
├── OMIArenaApp.swift     # App entry point
├── AppState.swift        # Global state management
├── services/
│   ├── ConvexClient.swift    # Backend API client
│   └── OMIBluetoothManager.swift  # BLE device management
└── views/
    ├── LobbyView.swift       # Room join/create interface
    ├── GameView.swift        # Main game interface
    └── DeviceDebugView.swift # Device debugging tools

convex/
├── schema.ts            # Data model
├── functions/
│   ├── players.ts       # Player management
│   ├── rooms.ts         # Room management
│   └── game.ts          # Game logic
```

## 🎯 Game Rules

- **RSSI Threshold**: -65 dBm (~2-3 meters) for valid tags
- **Tag Cooldown**: 3 seconds between attempts  
- **Immunity**: 2 seconds after being tagged
- **Scoring**: Points for successful tags

## 🚀 Quick Test

1. Run app on physical iPhone
2. Enter player name
3. Create room (no backend needed for UI testing)
4. Use mock data if no OMI device available

Built for hackathon development with ❤️
