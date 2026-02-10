import SwiftUI
import SlideKit

@main
struct WorkshopSlidesApp: App {

    @Environment(\.openWindow) var openWindow

    private static let configuration = SlideConfiguration()

    var presentationContentView: some View {
        SlideRouterView(slideIndexController: Self.configuration.slideIndexController)
            .slideTheme(Self.configuration.theme)
            .foregroundColor(.black)
            .background(.white)
    }

    var body: some Scene {
        WindowGroup {
            PresentationView(slideSize: Self.configuration.size) {
                presentationContentView
            }
        }
        .setupAsPresentationWindow(Self.configuration.slideIndexController) {
            openWindow(id: "presenter")
        }
        .addPDFExportCommands(for: presentationContentView, with: Self.configuration.slideIndexController, size: Self.configuration.size)

        WindowGroup(id: "presenter") {
            macOSPresenterView(
                slideSize: Self.configuration.size,
                slideIndexController: Self.configuration.slideIndexController
            ) {
                presentationContentView
            }
        }
        .setupAsPresenterWindow()
    }
}
