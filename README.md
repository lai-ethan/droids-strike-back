# OMI Arena - Real-time Multiplayer Tag Game

A complete iOS app with Convex backend for playing real-time tag using OMI Dev Kit 2 wearables. Built for hackathon development with SwiftUI, CoreBluetooth, and TypeScript.

## 🎮 Game Overview

OMI Arena transforms the classic game of tag into a high-tech multiplayer experience using OMI Dev Kit 2 wearables. Players connect via Bluetooth LE, and the app uses RSSI signal strength to determine proximity for valid tags.

### Features
- **Real-time multiplayer** with server-authoritative game logic
- **BLE integration** with OMI Dev Kit 2 wearables
- **Mock data support** for testing without hardware
- **Live game state** updates via Convex subscriptions
- **Device debugging** interface for development
- **Cross-platform compatibility** (iOS + Convex backend)

## 🏗️ Architecture

### Backend (Convex + TypeScript)
- **Real-time game logic** with server-authoritative tag validation
- **RSSI-based distance estimation** for proximity detection
- **Live subscriptions** for real-time game state updates
- **Player and room management** with unique room codes

### Frontend (iOS + SwiftUI)
- **BLE integration** with OMI Dev Kit 2 using CoreBluetooth
- **Mock data support** for testing without hardware
- **Real-time UI updates** driven by Convex subscriptions
- **Debug interface** for device monitoring

## 🚀 Quick Start

### Prerequisites
- macOS with Xcode 15+
- iOS 15.0+ device or simulator
- Node.js 18+
- OMI Dev Kit 2 (optional - mock data available)

### Backend Setup

1. **Clone and install dependencies**:
   ```bash
   git clone <repository-url>
   cd droids-strike-back
   npm install
   ```

2. **Configure environment**:
   ```bash
   # Copy example environment file
   cp .env.local.example .env.local
   
   # Edit with your Convex deployment URL
   echo "CONVEX_URL=https://your-deployment.convex.cloud" > .env.local
   ```

3. **Generate types and start development**:
   ```bash
   npm run codegen
   npm run dev  # Uses --typecheck=disable due to index warnings
   ```

### iOS App Setup

1. **Open in Xcode**:
   - Open `OMIArena.xcodeproj`
   - Add all Swift files to the project if needed

2. **Configure permissions**:
   - Add Bluetooth permissions to `Info.plist`:
   ```xml
   <key>NSBluetoothAlwaysUsageDescription</key>
   <string>OMI Arena uses Bluetooth to connect to OMI wearables for real-time gameplay</string>
   ```

3. **Add dependencies**:
   - Convex Swift SDK via Swift Package Manager
   - iOS deployment target: iOS 15.0+

4. **Build and run**:
   - Select physical iPhone device (required for Bluetooth)
   - Build and run the app

## 🎯 How to Play

1. **Create Player**: Enter your name when app launches
2. **Join/Create Room**: Use 6-character room code or create new room
3. **Connect Device**: Scan for OMI Dev Kit 2 or use mock data
4. **Start Game**: Host starts game when 2+ players join
5. **Play Tag**: 
   - "IT" player tags others by getting close and pressing TAG
   - RSSI determines if players are close enough
   - Scores update in real-time

## 🔧 Technical Details

### Game Constants
- **RSSI Threshold**: -65 dBm for valid tags (~2-3 meters)
- **Tag Cooldown**: 3 seconds between attempts
- **Post-tag Immunity**: 2 seconds after being tagged
- **Distance Estimation**: Path loss model with TX power -59 dBm at 1m

### BLE Integration
- **OMI Dev Kit 2 UUIDs**:
  - Audio Service: `19B10000-E8F2-537E-4F6C-D104768A1214`
  - Audio Data: `19B10001-E8F2-537E-4F6C-D104768A1214`
  - Battery Service: `0x180F`
  - Device Info: `0x180A`

- **Data Streaming**:
  - Motion Data: `{ax, ay, az}` acceleration at 10Hz
  - RSSI: Signal strength for distance estimation
  - Battery: Periodic battery level updates

### API Endpoints
- **Players**: `/api/run/createPlayer`, `/api/run/updatePlayer`
- **Rooms**: `/api/run/createRoom`, `/api/run/getRoomByCode`
- **Game**: `/api/run/joinRoom`, `/api/run/startGame`, `/api/run/attemptTag`

## 📁 Project Structure

```
├── convex/                          # Backend
│   ├── schema.ts                    # Data model definition
│   ├── lib/
│   │   └── tagLogic.ts              # Game logic utilities
│   └── functions/
│       ├── rooms.ts                 # Room management
│       ├── players.ts               # Player management
│       └── game.ts                  # Core game functions
├── OMIArena/                        # iOS App
│   ├── OMIArenaApp.swift           # App entry point
│   ├── models/
│   │   ├── PlayerModel.swift        # Player data model
│   │   └── RoomModel.swift          # Room data model
│   ├── state/
│   │   └── AppState.swift           # Global state management
│   ├── services/
│   │   ├── OMIBluetoothManager.swift # BLE device management
│   │   └── ConvexClient.swift       # Backend API client
│   └── views/
│       ├── LobbyView.swift          # Room join/create interface
│       ├── GameView.swift           # Main game interface
│       └── DeviceDebugView.swift    # Device debugging tools
├── package.json                     # Node.js dependencies
└── README.md                        # This file
```

## 🧪 Testing

### Backend Testing
```bash
# Run with mock data
npm run dev

# Test API endpoints
curl https://your-deployment.convex.cloud/api/version
```

### iOS Testing
- Use simulator for UI testing with mock data
- Test with real OMI device for BLE integration
- Use debug view to monitor connection state

## 🐛 Troubleshooting

### Common Issues

1. **Bluetooth not connecting**
   - Use physical iPhone device (simulator doesn't support Bluetooth)
   - Check iOS permissions in Settings
   - Ensure device is powered on and advertising

2. **Convex connection failed**
   - Verify backend is running (`npm run dev`)
   - Check CONVEX_URL in configuration
   - Ensure network connectivity

3. **Build errors**
   - Clean build folder (Cmd+Shift+K)
   - Verify all Swift files are added to Xcode project
   - Check iOS deployment target is 15.0+

### Debug Tools
- **Device Debug View**: Monitor BLE connection and data
- **Console Logs**: Check Xcode console for errors
- **Network Inspector**: Monitor Convex API calls

## 🚀 Deployment

### Backend Deployment
```bash
# Deploy to Convex
npx convex deploy

# Update iOS app with production URL
# Edit ConvexClient.swift or .env.local
```

### iOS App Deployment
1. Archive app in Xcode
2. Upload to App Store Connect
3. Submit for review

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Convex** - Real-time backend platform
- **OMI Dev Kit 2** - Hardware platform
- **SwiftUI** - Modern iOS UI framework
- **CoreBluetooth** - iOS Bluetooth LE framework

## 🔗 Links

- [Convex Documentation](https://docs.convex.dev/)
- [OMI Developer Resources](https://github.com/omi-ai/omi)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui/)

## 🚧 Next Steps for Contributors

This project was developed for a hackathon and has some incomplete areas that need attention:

### High Priority Issues

1. **Fix Convex API Integration**
   - Player creation returns 400 errors - investigate payload format
   - Update all API endpoints to use proper Convex function routing
   - Test and verify backend deployment functionality

2. **Complete Xcode Project Setup**
   - Ensure all Swift files are properly added to Xcode project
   - Fix any missing imports or dependencies
   - Resolve build warnings and errors
   - Test on physical iPhone device for Bluetooth functionality

3. **Backend Deployment**
   - Deploy latest Convex functions to production
   - Verify all database indexes are properly configured
   - Test API endpoints in production environment

### Medium Priority Enhancements

4. **Improve Error Handling**
   - Add better error messages for Convex connection failures
   - Implement retry logic for network requests
   - Add user-friendly error dialogs

5. **UI/UX Improvements**
   - Fix SwiftUI layout constraints (see console warnings)
   - Add loading states for async operations
   - Improve onboarding flow for new users

6. **Testing & Documentation**
   - Add unit tests for Convex client functions
   - Add UI tests for critical user flows
   - Document API response formats and error codes

### Low Priority Features

7. **Game Enhancements**
   - Implement different game modes (freeze tag, team tag)
   - Add spectator mode for watching games
   - Create leaderboards and persistent scoring

8. **Platform Expansion**
   - Add Android support using Kotlin Multiplatform
   - Implement web dashboard for game management
   - Add push notifications for game events

### Technical Debt

9. **Code Quality**
   - Resolve TypeScript compilation warnings in Convex functions
   - Add proper error logging and monitoring
   - Implement proper state management patterns

10. **Performance Optimization**
    - Optimize Bluetooth connection handling
    - Implement efficient data synchronization
    - Add caching for frequently accessed data

### Getting Started

To contribute:
1. Clone the repository and follow the setup instructions above
2. Focus on high priority issues first
3. Test changes on both simulator and physical device
4. Submit pull requests with clear descriptions of changes

**Note**: The project currently works in the simulator with mock data, but full functionality requires a physical iPhone device and properly deployed Convex backend.

---

Built with ❤️ for hackathon development using Swift, SwiftUI, Convex, and CoreBluetooth.
