import SlideKit
import SwiftUI

@Slide
struct SummarySlide: View {
    enum SlidePhase: Int, PhasedState {
        case initial, takeaways
    }

    @Phase var phase: SlidePhase

    var body: some View {
        HeaderSlide("Summary") {
            Item("What We Built") {
                Item("ISO 18013-5 compliant mobile ID verification")
                Item("CBOR encoding/decoding for data exchange")
                Item("BLE transport with Central/Peripheral roles")
                Item("Selective disclosure with user consent")
                Item("Biometric authentication for privacy")
            }
            if phase.rawValue >= SlidePhase.takeaways.rawValue {
                Item("Key Takeaways") {
                    Item("mDL is the future of digital identity")
                    Item("Privacy by design: share only what is needed")
                    Item("BLE provides proper device role abstraction")
                    Item("iOS has strong support for these technologies")
                }
            }
        }
    }

    var script: String {
        switch phase {
        case .initial: return "Let's review what we built."
        case .takeaways: return "mDL enables privacy-preserving identity verification."
        }
    }
}

#Preview {
    SlidePreview {
        SummarySlide()
    }
}
