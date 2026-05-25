import SwiftUI

struct BrandingImage: View {
    var badge: BadgeType = .none

    enum BadgeType {
        case none
        case working
        case success
        case error
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: "square.and.arrow.down")
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.yellow)
                .frame(width: 48, height: 48)

            switch badge {
            case .none:
                EmptyView()
            case .working:
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                    .symbolEffect(.pulse)
                    .offset(x: 4, y: 4)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
                    .offset(x: 4, y: 4)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)
                    .offset(x: 4, y: 4)
            }
        }
    }
}
