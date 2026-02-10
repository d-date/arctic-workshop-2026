import SlideKit
import SwiftUI

@Slide
struct ArchitectureSlide: View {
    enum SlidePhase: Int, PhasedState {
        case initial, flow
    }

    @Phase var phase: SlidePhase

    var body: some View {
        HeaderSlide("System Architecture") {
            Item("Two-Device Verification System") {
                Item("Reader Phone (Verifier) — Requests and verifies identity")
                Item("Presentment Phone (Holder) — Presents credentials")
            }
            if phase.rawValue >= SlidePhase.flow.rawValue {
                Item("Communication Flow") {
                    Item("[1] Reader scans → Holder advertises (BLE)")
                    Item("[2] Devices establish BLE connection")
                    Item("[3] Reader sends DeviceRequest (CBOR)")
                    Item("[4] Holder shows disclosure UI + Face ID")
                    Item("[5] Holder sends DeviceResponse (CBOR)")
                    Item("[6] Reader decodes and displays attributes")
                }
            }
        }
    }

    var script: String {
        switch phase {
        case .initial: return "Our system uses two iPhones."
        case .flow: return "The communication flow uses BLE and CBOR."
        }
    }
}

#Preview {
    SlidePreview {
        ArchitectureSlide()
    }
}
