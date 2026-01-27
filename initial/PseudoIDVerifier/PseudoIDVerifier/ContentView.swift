import SwiftUI

/// Main view for selecting between Reader and Presentment modes
struct ContentView: View {
    @State private var selectedMode: AppMode?

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Text("Pseudo ID Verifier")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Select your role")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 20) {
                    NavigationLink(value: AppMode.reader) {
                        ModeCard(
                            title: "Reader",
                            subtitle: "Verify someone's ID",
                            systemImage: "person.text.rectangle",
                            color: .blue
                        )
                    }

                    NavigationLink(value: AppMode.presentment) {
                        ModeCard(
                            title: "Presentment",
                            subtitle: "Present your ID",
                            systemImage: "wallet.pass",
                            color: .green
                        )
                    }
                }
                .padding(.horizontal)
            }
            .navigationDestination(for: AppMode.self) { mode in
                switch mode {
                case .reader:
                    ReaderView()
                case .presentment:
                    PresentmentView()
                }
            }
        }
    }
}

enum AppMode: Hashable {
    case reader
    case presentment
}

struct ModeCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(color)
                .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ContentView()
}
