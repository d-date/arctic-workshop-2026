import SlideKit
import SwiftUI

@Slide
struct TransportSlide: View {
    enum SlidePhase: Int, PhasedState {
        case initial, mpc, ble
    }

    @Phase var phase: SlidePhase

    var body: some View {
        HeaderSlide("Transport Layer") {
            Item("Two approaches in this workshop") {
                Item("Start with MPC for quick prototyping")
                Item("Then implement BLE for ISO 18013-5 compliance")
            }
            if phase.rawValue >= SlidePhase.mpc.rawValue {
                Item("Multipeer Connectivity (MPC)") {
                    Item("Apple's high-level peer-to-peer framework")
                    Item("Quick to implement — browse and advertise")
                    Item("Limitation: No asymmetric roles")
                }
            }
            if phase.rawValue >= SlidePhase.ble.rawValue {
                Item("Bluetooth Low Energy (BLE)") {
                    Item("ISO 18013-5 specifies BLE as transport")
                    Item("Central (Reader) / Peripheral (Holder) roles")
                    Item("Requires data chunking for MTU limits")
                }
            }
        }
    }

    var script: String {
        switch phase {
        case .initial: return "Two transport approaches in this workshop."
        case .mpc: return "First, Multipeer Connectivity for quick prototyping."
        case .ble: return "Then BLE for ISO 18013-5 compliance."
        }
    }
}

#Preview {
    SlidePreview {
        TransportSlide()
    }
}
