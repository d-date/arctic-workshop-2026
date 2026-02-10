import SlideKit
import SwiftUI

@Slide
struct BLEDetailSlide: View {
    enum SlidePhase: Int, PhasedState {
        case initial, peripheral, chunking
    }

    @Phase var phase: SlidePhase

    var body: some View {
        HeaderSlide("BLE Implementation Details") {
            Item("Central Mode (Reader)") {
                Item("Scan for peripherals with mDL service UUID")
                Item("Connect → Discover services → Read/Write")
            }
            if phase.rawValue >= SlidePhase.peripheral.rawValue {
                Item("Peripheral Mode (Holder)") {
                    Item("Advertise mDL service UUID")
                    Item("Handle subscription and notify on changes")
                }
            }
            if phase.rawValue >= SlidePhase.chunking.rawValue {
                Item("Data Chunking & Backpressure") {
                    Item("BLE MTU is limited (~512 bytes)")
                    Item("Split large CBOR payloads into chunks")
                    Item("Wait for ready signal before next chunk")
                }
            }
        }
    }

    var script: String {
        switch phase {
        case .initial: return "Reader acts as BLE Central."
        case .peripheral: return "Holder acts as BLE Peripheral."
        case .chunking: return "Large payloads need chunking."
        }
    }
}

#Preview {
    SlidePreview {
        BLEDetailSlide()
    }
}
