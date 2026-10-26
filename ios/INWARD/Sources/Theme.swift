import SwiftUI
import CoreImage.CIFilterBuiltins

enum INLayout {
    static var contentColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 155, maximum: 225), spacing: 12, alignment: .top)]
    }
    static let maximumContentWidth: CGFloat = 1100
}

enum INTheme {
    static let paper = Color(red: 0.965, green: 0.965, blue: 0.945)
    static let white = Color.white
    static let ink = Color(red: 0.075, green: 0.12, blue: 0.10)
    static let muted = Color(red: 0.43, green: 0.48, blue: 0.45)
    static let green = Color(red: 0.04, green: 0.39, blue: 0.28)
    static let mint = Color(red: 0.72, green: 0.95, blue: 0.81)
    static let navy = Color(red: 0.043, green: 0.13, blue: 0.22)
    static let line = Color.black.opacity(0.07)
}

struct INCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(14).background(INTheme.white).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(INTheme.line))
            .shadow(color: .black.opacity(0.025), radius: 8, y: 3)
    }
}
struct INSectionTitle: View {
    let title: String; var subtitle: String = ""
    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 21, weight: .heavy, design: .rounded)).foregroundStyle(INTheme.ink)
                if !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundStyle(INTheme.muted) }
            }
            Spacer()
        }
    }
}
struct INPill: View {
    let text: String; var mint = false
    var body: some View {
        Text(text).font(.caption2.weight(.bold)).padding(.horizontal, 9).padding(.vertical, 5)
            .background(mint ? INTheme.mint : INTheme.paper).clipShape(Capsule()).lineLimit(1)
    }
}
struct RemoteImage: View {
    let path: String; let base: URL?; var height: CGFloat = 145
    private var url: URL? {
        if let direct = URL(string: path), direct.scheme != nil { return direct }
        guard let base else { return nil }
        return URL(string: path.hasPrefix("/") ? String(path.dropFirst()) : path, relativeTo: base)?.absoluteURL
    }
    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFill()
            case .failure: placeholder("photo")
            case .empty: ZStack { INTheme.paper; ProgressView().tint(INTheme.green) }
            @unknown default: placeholder("photo")
            }
        }.frame(maxWidth: .infinity).frame(height: height).clipped().background(INTheme.paper)
    }
    private func placeholder(_ symbol: String) -> some View {
        ZStack { INTheme.paper; Image(systemName: symbol).font(.title2).foregroundStyle(INTheme.muted) }
    }
}
struct EmptyState: View {
    let text: String; var systemImage = "tray"
    var body: some View {
        VStack(spacing: 10) { Image(systemName: systemImage).font(.largeTitle); Text(text).font(.subheadline) }
            .foregroundStyle(INTheme.muted).frame(maxWidth: .infinity).padding(.vertical, 44)
    }
}
struct QRCodeView: View {
    let value: String
    private var image: UIImage? {
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(value.utf8); filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        return UIImage(ciImage: scaled)
    }
    var body: some View {
        if let image { Image(uiImage: image).interpolation(.none).resizable().scaledToFit().frame(width: 190, height: 190).padding(12).background(Color.white) }
        else { EmptyState(text: "二维码暂不可用") }
    }
}
struct LoadingOverlay: View {
    var body: some View {
        ZStack { Color.black.opacity(0.08).ignoresSafeArea(); ProgressView().padding(22).background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 16)) }
    }
}
