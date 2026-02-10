import SlideKit
import SwiftUI

@Slide
struct IntegrationSlide: View {
    enum SlidePhase: Int, PhasedState {
        case initial, testing, timing
    }

    @Phase var phase: SlidePhase

    var body: some View {
        HeaderSlide("Integration Testing") {
            Item("Prerequisites") {
                Item("Two iOS 17+ devices with Bluetooth enabled")
                Item("Face ID / Touch ID enrolled on Holder device")
                Item("Both devices on same network (for MPC)")
            }
            if phase.rawValue >= SlidePhase.testing.rawValue {
                Item("Test Scenarios") {
                    Item("Age Verification (21+ and 18+)")
                    Item("Full Identity Check")
                    Item("User Denial — graceful handling")
                    Item("BLE Disconnect — reconnection")
                }
            }
            if phase.rawValue >= SlidePhase.timing.rawValue {
                Item("Expected Flow: ~5-10 seconds total") {
                    Item("BLE discovery + connection: 1-3s")
                    Item("Request/Response exchange: 1-2s")
                    Item("Biometric auth: 1-2s")
                }
            }
        }
    }

    var script: String {
        switch phase {
        case .initial: return "Two physical iOS devices required."
        case .testing: return "Several test scenarios."
        case .timing: return "5 to 10 seconds total."
        }
    }
}

#Preview {
    SlidePreview {
        IntegrationSlide()
    }
}
