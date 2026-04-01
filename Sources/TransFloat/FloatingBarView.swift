import SwiftUI

// MARK: - View Model

class FloatingBarViewModel: ObservableObject {
    @Published var original: String = ""
    @Published var translation: String = ""
    @Published var isVisible: Bool = false
}

// MARK: - Floating Bar View

struct FloatingBarView: View {
    @ObservedObject var viewModel: FloatingBarViewModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.black.opacity(0.75))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.translation)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)

                    Text(viewModel.original)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 16)
                .padding(.trailing, 30)
            }
        }
    }
}
