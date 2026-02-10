import SlideKit
import SwiftUI

@Slide
struct WhatIsMDLSlide: View {
    enum SlidePhase: Int, PhasedState {
        case initial, structure, selective
    }

    @Phase var phase: SlidePhase

    var body: some View {
        HeaderSlide("What is mDL? (ISO 18013-5)") {
            Item("Mobile Driver's License standard for digital identity") {
                Item("Internationally recognized specification")
                Item("Used by Apple Wallet, Google Wallet, etc.")
            }
            if phase.rawValue >= SlidePhase.structure.rawValue {
                Item("Core Data Structure: mdoc") {
                    Item("docType — e.g. \"org.iso.18013.5.1.mDL\"")
                    Item("issuerSigned — Issuer-authenticated data elements")
                    Item("deviceSigned — Device-authenticated signature")
                }
            }
            if phase.rawValue >= SlidePhase.selective.rawValue {
                Item("Key Principle: Selective Disclosure") {
                    Item("Share only the attributes requested by the verifier")
                    Item("e.g. Prove age >= 21 without revealing full birthdate")
                }
            }
        }
    }

    var script: String {
        switch phase {
        case .initial: return "ISO 18013-5 defines the Mobile Driver's License standard."
        case .structure: return "The core data structure is called mdoc."
        case .selective: return "A key principle is selective disclosure."
        }
    }
}

#Preview {
    SlidePreview {
        WhatIsMDLSlide()
    }
}
