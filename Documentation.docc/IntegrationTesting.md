# Integration Testing

Test the complete verification flow between two devices.

## Overview

Now that all components are implemented, let's test the end-to-end flow between two iPhones.

### Prerequisites

- Two iPhones running iOS 17+
- Both with Bluetooth enabled
- Face ID/Touch ID enrolled on the Holder device
- The app installed on both devices

### Test Scenario: Age Verification

We'll test the most common scenario: verifying someone is over 21.

### Step 1: Setup

**Device A (Reader/Verifier)**
1. Launch the app
2. Tap "Reader"
3. Select "Age 21+ Verification"

**Device B (Holder/Presentment)**
1. Launch the app
2. Tap "Presentment"
3. You should see the sample credential card

### Step 2: Initiate Connection

**On Device A (Reader)**
1. Tap "Start Reading"
2. The app shows "Ready to Read" with animated rings
3. Wait for connection

**On Device B (Holder)**
1. Tap "Present ID"
2. The app shows "Ready to Present" and starts BLE advertising
3. Wait for the Reader to connect

### Step 3: Handle Request

**On Device B (Holder)**
1. Once connected, you'll see the disclosure request:
   - "Age Over 21"
   - "Portrait" (if requested)
2. Review what's being requested
3. Tap "Approve with Face ID"
4. Complete Face ID authentication
5. See "Shared Successfully"

### Step 4: View Results

**On Device A (Reader)**
1. After the Holder approves, results appear
2. You should see:
   - "Age Over 21: Yes" with green checkmark
3. Tap "Done" to reset

### Expected Flow

```
Time    Reader Device                Holder Device
────────────────────────────────────────────────────
0:00    Select scenario              Show credential
0:05    Tap "Start Reading"
0:06    "Ready to Read"
0:10                                 Tap "Present ID"
0:11                                 "Ready to Present"
0:15    "Connecting..."
0:17    "Waiting for approval..."    Show request UI
0:20                                 Tap "Approve"
0:21                                 Face ID prompt
0:23                                 "Sending..."
0:25    Show results                 "Shared Successfully"
```

### Debugging Tips

#### Connection Issues

If devices don't connect:
1. Ensure Bluetooth is enabled on both
2. Try toggling Bluetooth off/on
3. Force quit and restart the app
4. Check for Bluetooth permission prompts

#### Data Not Received

If Reader doesn't show results:
1. Check console logs for CBOR encoding errors
2. Verify BLE characteristics are discovered
3. Ensure data chunking is working for large payloads

#### Authentication Fails

If Face ID doesn't work:
1. Verify Face ID is enrolled in Settings
2. Check for proper error handling
3. Test the passcode fallback

### Adding Console Logging

For debugging, add print statements:

```swift
// In BLEService
func centralManager(_ central: CBCentralManager,
                   didConnect peripheral: CBPeripheral) {
    print("BLE: Connected to \(peripheral.name ?? "unknown")")
    // ...
}

// In CBORService
func encode(mdoc: MDoc) -> Data {
    let data = // ... encoding
    print("CBOR: Encoded mdoc: \(data.count) bytes")
    return data
}
```

### Test Matrix

| Scenario | Expected Result |
|----------|----------------|
| Age 21+ | age_over_21: true |
| Age 18+ | age_over_18: true |
| Full Identity | name, DOB, doc# |
| User Denies | No data sent, Reader shows error |
| Cancel Face ID | Returns to request screen |
| BLE Disconnect | Both apps reset to idle |

### Performance Metrics

Typical timing for the complete flow:
- BLE connection: 2-5 seconds
- Request/Response: 1-2 seconds
- Total: 5-10 seconds

### Common Issues

1. **"Bluetooth Unavailable"**
   - Check iOS Settings → Bluetooth
   - Ensure Bluetooth permission is granted

2. **"Connection Timed Out"**
   - Move devices closer together
   - Restart Bluetooth on both devices

3. **"Invalid Response"**
   - Check CBOR encoding/decoding
   - Verify data structures match

4. **Face ID Not Appearing**
   - Check `NSFaceIDUsageDescription` in Info.plist
   - Ensure device has Face ID enrolled

### Next Steps

Congratulations! You've built a working pseudo ID verification system.

To extend this workshop:
- Add NFC handshake for device engagement
- Implement proper COSE signing
- Add issuer certificate verification
- Create a real credential issuance flow

## Summary

You've learned:
1. ISO 18013-5 mdoc structure
2. CBOR encoding/decoding
3. BLE communication patterns
4. Selective disclosure
5. Biometric authentication

These concepts apply directly to real mobile identity implementations.
