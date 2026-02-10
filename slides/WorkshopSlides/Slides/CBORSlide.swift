import SlideKit
import SwiftUI

@Slide
struct CBORSlide: View {
    enum SlidePhase: Int, PhasedState {
        case initial, code
    }

    @Phase var phase: SlidePhase

    var body: some View {
        HeaderSlide("CBOR Encoding & Decoding") {
            Item("Concise Binary Object Representation (RFC 8949)") {
                Item("Binary format — compact and efficient for BLE transfer")
                Item("Similar to JSON but smaller and faster to parse")
                Item("Used throughout ISO 18013-5 for data exchange")
            }
            if phase.rawValue >= SlidePhase.code.rawValue {
                Code("""
                    struct MDoc: Sendable {
                        let docType: String
                        let issuerSigned: IssuerSigned
                        let deviceSigned: DeviceSigned
                    }

                    let cbor = CBOR.map([
                        "docType": .utf8String(mdoc.docType),
                        "issuerSigned": encodeIssuerSigned(...),
                        "deviceSigned": encodeDeviceSigned(...)
                    ])
                    """
                )
                .lineSpacing(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }

    var script: String {
        switch phase {
        case .initial: return "CBOR is the binary encoding format used by ISO 18013-5."
        case .code: return "Here is how we define MDoc and encode it to CBOR."
        }
    }
}

#Preview {
    SlidePreview {
        CBORSlide()
    }
}
