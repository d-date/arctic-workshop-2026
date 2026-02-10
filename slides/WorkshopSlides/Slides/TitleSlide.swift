import SlideKit
import SwiftUI

@Slide
struct TitleSlide: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            Text("Pseudo ID Verifier")
                .font(.system(size: 100, weight: .bold))
            Text("Building an ISO 18013-5 Mobile ID Verification System")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Spacer()
            Text("ARCTIC Conference 2026")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var shouldHideIndex: Bool { true }

    var script: String {
        "Welcome to the Pseudo ID Verifier workshop."
    }
}

#Preview {
    SlidePreview {
        TitleSlide()
    }
}
