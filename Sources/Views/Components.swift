import SwiftUI

/// Shared chapbook UI pieces: paper background, deckled card, ribbon bookmark,
/// mastery ring, hairline rule, and small typographic helpers.

/// Full-bleed warm paper background with a faint vignette + grain feel.
public struct PaperBackground: View {
    @Environment(\.palette) private var pal
    public init() {}
    public var body: some View {
        ZStack {
            pal.paper.ignoresSafeArea()
            // Soft radial warmth toward the top, like light on a page.
            RadialGradient(
                colors: [pal.cardField.opacity(0.55), .clear],
                center: .top, startRadius: 40, endRadius: 520
            )
            .ignoresSafeArea()
            .blendMode(.plusLighter)
            .opacity(0.6)
        }
    }
}

/// A raised "page card" with deckled edges and a soft shadow.
public struct PageCard<Content: View>: View {
    @Environment(\.palette) private var pal
    private let content: Content
    private let padding: CGFloat
    public init(padding: CGFloat = 22, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    public var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(pal.cardField)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(pal.rule.opacity(0.55), lineWidth: 1)
                    )
            )
            .shadow(color: pal.paperEdge.opacity(0.7), radius: 12, x: 0, y: 6)
    }
}

/// A small fabric ribbon-bookmark that drapes from the top of a card.
public struct RibbonBookmark: View {
    @Environment(\.palette) private var pal
    var height: CGFloat = 58
    public init(height: CGFloat = 58) { self.height = height }
    public var body: some View {
        ZStack(alignment: .top) {
            RibbonShape()
                .fill(pal.ribbon)
                .overlay(
                    RibbonShape().fill(pal.ribbonDim).frame(width: 5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                )
                .frame(width: 26, height: height)
                .shadow(color: pal.ribbonDim.opacity(0.5), radius: 2, x: 1, y: 2)
        }
    }
}

/// A ribbon with a swallow-tail notch at the bottom.
public struct RibbonShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.22))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Hairline rule with optional centered ornament.
public struct ChapbookRule: View {
    @Environment(\.palette) private var pal
    var ornament: String?
    public init(ornament: String? = "❧") { self.ornament = ornament }
    public var body: some View {
        HStack(spacing: 12) {
            line
            if let ornament {
                Text(ornament)
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(pal.gild)
            }
            line
        }
    }
    private var line: some View {
        Rectangle().fill(pal.rule.opacity(0.7)).frame(height: 1)
    }
}

/// A gilt mastery ring (0…1 fraction) with an inner glyph.
public struct MasteryRing: View {
    @Environment(\.palette) private var pal
    let fraction: Double
    let learned: Bool
    var size: CGFloat = 44
    public init(fraction: Double, learned: Bool, size: CGFloat = 44) {
        self.fraction = fraction; self.learned = learned; self.size = size
    }
    public var body: some View {
        ZStack {
            Circle().stroke(pal.rule.opacity(0.5), lineWidth: 3)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, fraction)))
                .stroke(pal.gild, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: learned ? "checkmark" : "book.closed")
                .font(.system(size: size * 0.32, weight: .semibold))
                .foregroundStyle(learned ? pal.gild : pal.inkSoft)
        }
        .frame(width: size, height: size)
    }
}

/// A small pill tag (language / era).
public struct Tag: View {
    @Environment(\.palette) private var pal
    let text: String
    var filled: Bool = false
    public init(_ text: String, filled: Bool = false) { self.text = text; self.filled = filled }
    public var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .serif))
            .tracking(0.5)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .foregroundStyle(filled ? pal.paper : pal.inkSoft)
            .background(
                Capsule().fill(filled ? pal.ribbon : pal.rule.opacity(0.22))
            )
    }
}

public extension View {
    /// Apply the current palette + mode into the environment for a subtree.
    func recitalChrome(_ settings: Settings) -> some View {
        self
            .environment(\.palette, settings.palette)
            .environment(\.themeMode, settings.mode)
    }
}
