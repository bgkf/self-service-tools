import SwiftUI

struct WorkingView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                BrandingImage(badge: .working)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Download One Item From Jamf Dev")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack {
                Spacer()
                ProgressView()
                    .controlSize(.small)
                Spacer()
            }

            Spacer()
        }
        .padding(20)
    }
}
