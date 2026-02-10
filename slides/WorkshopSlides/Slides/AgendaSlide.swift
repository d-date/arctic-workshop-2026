import SlideKit
import SwiftUI

@Slide
struct AgendaSlide: View {
    enum SlidePhase: Int, PhasedState {
        case initial, part2, part3, part4
    }

    @Phase var phase: SlidePhase

    var body: some View {
        HeaderSlide("Agenda") {
            Item("Part 1: Foundations", accessory: .number(1)) {
                Item("mDL (Mobile Document) & CBOR Encoding")
            }
            if phase.rawValue >= SlidePhase.part2.rawValue {
                Item("Part 2: Transport Layer", accessory: .number(2)) {
                    Item("MPC (Quick Prototype) → BLE (ISO 18013-5)")
                }
            }
            if phase.rawValue >= SlidePhase.part3.rawValue {
                Item("Part 3: Security & Privacy", accessory: .number(3)) {
                    Item("Selective Disclosure & Biometric Authentication")
                }
            }
            if phase.rawValue >= SlidePhase.part4.rawValue {
                Item("Part 4: Integration Testing", accessory: .number(4)) {
                    Item("End-to-End Flow on Two Devices")
                }
            }
        }
    }

    var script: String {
        switch phase {
        case .initial: return "Part 1 covers the foundations."
        case .part2: return "Part 2 covers the transport layer."
        case .part3: return "Part 3 focuses on security and privacy."
        case .part4: return "Part 4 is integration testing."
        }
    }
}

#Preview {
    SlidePreview {
        AgendaSlide()
    }
}
