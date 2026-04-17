import SwiftUI

struct LabeledFieldHelp<Content: View>: View {
    let title: String
    let key: String
    let showsKey: Bool
    let content: Content

    init(
        title: String,
        key: String,
        showsKey: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.key = key
        self.showsKey = showsKey
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if showsKey {
                    Spacer(minLength: 12)
                    Text(key)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            content
        }
    }
}
