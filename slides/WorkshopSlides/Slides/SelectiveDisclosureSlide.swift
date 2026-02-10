import SlideKit
import SwiftUI

@Slide
struct SelectiveDisclosureSlide: View {
    enum SlidePhase: Int, PhasedState {
        case initial, scenarios, privacy
    }

    @Phase var phase: SlidePhase

    var body: some View {
        HeaderSlide("Selective Disclosure") {
            Item("Only share what is requested") {
                Item("Verifier specifies needed attributes")
                Item("Holder chooses which to approve")
                Item("Response contains only approved attributes")
            }
            if phase.rawValue >= SlidePhase.scenarios.rawValue {
                Item("Verification Scenarios") {
                    Item("Age 21+ — Only age_over_21 boolean")
                    Item("Age 18+ — Only age_over_18 boolean")
                    Item("Full Identity — Name, DOB, address, portrait")
                }
            }
            if phase.rawValue >= SlidePhase.privacy.rawValue {
                Item("Privacy by Design") {
                    Item("Verifier learns minimum necessary")
                    Item("User consent required for every disclosure")
                    Item("Data minimization is core to ISO 18013-5")
                }
            }
        }
    }

    var script: String {
        switch phase {
        case .initial: return "Selective disclosure means sharing only what is needed."
        case .scenarios: return "Three verification scenarios."
        case .privacy: return "Privacy by design is core."
        }
    }
}

#Preview {
    SlidePreview {
        SelectiveDisclosureSlide()
    }
}
