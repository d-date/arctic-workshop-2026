# Project Setup

Create the Xcode project and configure required capabilities.

## Overview

In this chapter, you'll set up the Xcode project with all necessary dependencies and capabilities for NFC, Bluetooth, and biometric authentication.

### Step 1: Create the Project

1. Open Xcode and create a new iOS App
2. Name it `PseudoIDVerifier`
3. Select SwiftUI for the interface
4. Choose Swift as the language

### Step 2: Add SwiftCBOR Dependency

Add the SwiftCBOR package for CBOR encoding/decoding:

1. File → Add Package Dependencies
2. Enter: `https://github.com/unrelentingtech/SwiftCBOR.git`
3. Select version 0.4.7 or later
4. Add to your target

### Step 3: Configure Capabilities

#### NFC

1. Select your target → Signing & Capabilities
2. Click "+ Capability" → Near Field Communication Tag Reading
3. Add to Info.plist:

```xml
<key>NFCReaderUsageDescription</key>
<string>This app uses NFC to initiate secure connections for ID verification.</string>
<key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
<array>
    <string>A0000002471001</string>
</array>
```

#### Bluetooth

Add to Info.plist:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to transfer ID verification data between devices.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to transfer ID verification data between devices.</string>
```

#### Face ID

Add to Info.plist:

```xml
<key>NSFaceIDUsageDescription</key>
<string>This app uses Face ID to authorize sharing your identity information.</string>
```

### Step 4: Create Entitlements

Create `PseudoIDVerifier.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.nfc.readersession.formats</key>
    <array>
        <string>NDEF</string>
        <string>TAG</string>
    </array>
</dict>
</plist>
```

### Step 5: Create Folder Structure

Create the following groups in Xcode:

```
PseudoIDVerifier/
├── Models/
├── Services/
├── Views/
└── Resources/
```

### Step 6: Create the App Entry Point

```swift
// PseudoIDVerifierApp.swift
import SwiftUI

@main
struct PseudoIDVerifierApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Step 7: Create ContentView

```swift
// ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Text("Pseudo ID Verifier")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Select your role")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 20) {
                    NavigationLink(value: AppMode.reader) {
                        ModeCard(
                            title: "Reader",
                            subtitle: "Verify someone's ID",
                            systemImage: "person.text.rectangle",
                            color: .blue
                        )
                    }

                    NavigationLink(value: AppMode.presentment) {
                        ModeCard(
                            title: "Presentment",
                            subtitle: "Present your ID",
                            systemImage: "wallet.pass",
                            color: .green
                        )
                    }
                }
                .padding(.horizontal)
            }
            .navigationDestination(for: AppMode.self) { mode in
                switch mode {
                case .reader:
                    ReaderView()
                case .presentment:
                    PresentmentView()
                }
            }
        }
    }
}

enum AppMode: Hashable {
    case reader
    case presentment
}
```

### Verification

Build the project (⌘B) to ensure:
- SwiftCBOR is properly linked
- No capability errors
- All Info.plist entries are valid

## Next Steps

Continue to <doc:UnderstandingMDoc> to learn about the mdoc data structure.
