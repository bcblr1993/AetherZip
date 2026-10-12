import SwiftUI

enum AZ {
  static let accent = Color(red: 0.40, green: 0.43, blue: 0.87)
  static let violet = Color(red: 0.58, green: 0.48, blue: 0.84)
  static let gradient = LinearGradient(
    colors: [accent, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
  static let motion = Animation.spring(response: 0.34, dampingFraction: 0.83)
}
struct PrimaryButton: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reducedMotion
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 12, weight: .medium)).padding(.horizontal, 15).padding(
      .vertical, 10
    ).foregroundStyle(.white).background(AZ.gradient, in: RoundedRectangle(cornerRadius: 9))
      .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.white.opacity(0.18))).shadow(
        color: AZ.accent.opacity(0.2), radius: 5, y: 3
      ).scaleEffect(configuration.isPressed && !reducedMotion ? 0.97 : 1).animation(
        reducedMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
  }
}
struct FileBadge: View {
  var symbol = "doc.zipper"
  var size: CGFloat = 38
  var body: some View {
    Image(systemName: symbol).font(.system(size: size * 0.48, weight: .light)).foregroundStyle(
      AZ.accent
    ).frame(width: size, height: size * 1.1).background(
      AZ.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
  }
}
struct ArchiveArtwork: View {
  @Environment(\.accessibilityReduceMotion) private var reducedMotion
  @State private var hover = false
  var body: some View {
    ZStack {
      Image(systemName: "photo").font(.system(size: 21, weight: .light)).foregroundStyle(AZ.violet)
        .frame(width: 49, height: 60).background(.background, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.09), radius: 8, y: 4).rotationEffect(
          .degrees(hover ? -24 : -16)
        ).offset(x: -19, y: -12)
      Image(systemName: "doc.text").font(.system(size: 21, weight: .light)).foregroundStyle(
        AZ.violet
      ).frame(width: 49, height: 60).background(.background, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.09), radius: 8, y: 4).rotationEffect(
          .degrees(hover ? 21 : 13)
        ).offset(x: 18, y: -15)
      Image(systemName: "archivebox").font(.system(size: 32, weight: .ultraLight)).foregroundStyle(
        .white
      ).frame(width: 80, height: 60).background(
        AZ.gradient.opacity(0.8), in: RoundedRectangle(cornerRadius: 13)
      ).glassEffect(.regular, in: .rect(cornerRadius: 13)).offset(y: 16)
      Image(systemName: "plus").font(.system(size: 12, weight: .medium)).foregroundStyle(AZ.accent)
        .frame(width: 23, height: 23).background(.background, in: Circle()).shadow(
          color: .black.opacity(0.1), radius: 4, y: 2
        ).offset(x: 42, y: 40)
    }.frame(width: 135, height: 100).onHover { v in
      withAnimation(reducedMotion ? nil : AZ.motion) { hover = v && !reducedMotion }
    }
  }
}
