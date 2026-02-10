import SlideKit
import SwiftUI

@Slide
struct BiometricSlide: View {
    enum SlidePhase: Int, PhasedState {
        case initial, code
    }

    @Phase var phase: SlidePhase

    var body: some View {
        HeaderSlide("Biometric Authentication") {
            Item("User consent via Face ID / Touch ID") {
                Item("Required before disclosing personal data")
                Item("Uses LocalAuthentication framework")
                Item("Supports Face ID, Touch ID, Optic ID")
            }
            if phase.rawValue >= SlidePhase.code.rawValue {
                Code("""
                    class AuthenticationService {
                        func authenticate() async throws -> Bool {
                            let context = LAContext()
                            return try await context.evaluatePolicy(
                                .deviceOwnerAuthenticationWithBiometrics,
                                localizedReason: "Approve identity disclosure"
                            )
                        }
                    }
                    """
                )
                .lineSpacing(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }

    var script: String {
        switch phase {
        case .initial: return "Biometric authentication before disclosure."
        case .code: return "Using LocalAuthentication framework."
        }
    }
}

#Preview {
    SlidePreview {
        BiometricSlide()
    }
}
