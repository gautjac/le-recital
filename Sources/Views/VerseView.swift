import SwiftUI

/// Renders a poem's verse with elegant chapbook typesetting. Supports:
///  - a slow line-by-line reveal (`revealedLines` limits what's shown),
///  - progressive word-masking (`maskLevel`) for "apprendre par cœur",
///  - tap-to-reveal of individual masked words.
public struct VerseView: View {
    @Environment(\.palette) private var pal

    let poem: Poem
    /// How many spoken lines are revealed (nil = all). Stanza breaks don't count.
    var revealedSpokenLines: Int?
    /// Masking level (0 = none). When > 0, words are progressively hidden.
    var maskLevel: Int
    /// Words the learner has tapped to peek (global word indices).
    var peeked: Set<Int>
    /// Tap handler for a masked word (passes the global word index).
    var onTapMasked: ((Int) -> Void)?

    var fontSize: CGFloat = 22
    var lineSpacing: CGFloat = 9

    public init(poem: Poem,
                revealedSpokenLines: Int? = nil,
                maskLevel: Int = 0,
                peeked: Set<Int> = [],
                fontSize: CGFloat = 22,
                lineSpacing: CGFloat = 9,
                onTapMasked: ((Int) -> Void)? = nil) {
        self.poem = poem
        self.revealedSpokenLines = revealedSpokenLines
        self.maskLevel = maskLevel
        self.peeked = peeked
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.onTapMasked = onTapMasked
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: lineSpacing) {
            ForEach(Array(layout.enumerated()), id: \.offset) { _, item in
                switch item {
                case .stanzaBreak:
                    Spacer().frame(height: fontSize * 0.7)
                case let .line(tokens, start):
                    lineView(tokens, start: start)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Layout

    private enum LayoutItem {
        case line(tokens: [Masking.Token], startGlobalIndex: Int)
        case stanzaBreak
    }

    /// Build the display layout: walk every line, tracking the running global word
    /// index for masking, and respecting the reveal limit (counted in spoken lines).
    private var layout: [LayoutItem] {
        var out: [LayoutItem] = []
        var gIndex = 0
        var spokenShown = 0
        let limit = revealedSpokenLines

        for line in poem.lines {
            let isBlank = line.trimmingCharacters(in: .whitespaces).isEmpty
            if isBlank {
                // Only render a stanza break if we've shown something and haven't hit the cap.
                if let limit, spokenShown >= limit { break }
                out.append(.stanzaBreak)
                continue
            }
            if let limit, spokenShown >= limit { break }
            let start = gIndex
            let (tokens, next) = Masking.renderLine(line, poem: poem, level: maskLevel,
                                                    startingGlobalIndex: gIndex)
            gIndex = next
            out.append(.line(tokens: tokens, startGlobalIndex: start))
            spokenShown += 1
        }
        // Trim a trailing stanza break.
        if case .stanzaBreak = out.last { out.removeLast() }
        return out
    }

    /// One line of verse rendered as a wrapping run of tokens.
    @ViewBuilder
    private func lineView(_ tokens: [Masking.Token], start: Int) -> some View {
        FlowText(tokens: tokens, start: start, poem: poem, peeked: peeked, fontSize: fontSize,
                 onTapMasked: onTapMasked)
    }
}

/// A wrapping flow of styled verse tokens. We track each word's global index so a
/// tap maps back to the right masked slot.
private struct FlowText: View {
    @Environment(\.palette) private var pal
    let tokens: [Masking.Token]
    let start: Int
    let poem: Poem
    let peeked: Set<Int>
    let fontSize: CGFloat
    var onTapMasked: ((Int) -> Void)?

    /// A token paired with its global word index (nil for punctuation) and a
    /// stable identity for the flow layout.
    private struct TokenItem: Identifiable {
        let id: Int
        let token: Masking.Token
        let gIndex: Int?
    }

    private var items: [TokenItem] {
        var idx = start
        var out: [TokenItem] = []
        for (i, tk) in tokens.enumerated() {
            switch tk {
            case .visible(let s) where Poem.words(in: s).isEmpty:
                out.append(TokenItem(id: i, token: tk, gIndex: nil)) // punctuation/space
            default:
                out.append(TokenItem(id: i, token: tk, gIndex: idx)); idx += 1
            }
        }
        return out
    }

    var body: some View {
        FlowLayout(spacing: 0, lineSpacing: 3) {
            ForEach(items) { item in
                tokenView(item.token, gIndex: item.gIndex)
            }
        }
    }

    @ViewBuilder
    private func tokenView(_ token: Masking.Token, gIndex: Int?) -> some View {
        switch token {
        case .visible(let s):
            Text(s)
                .font(.verse(fontSize))
                .foregroundStyle(pal.ink)
        case let .hint(full, shown):
            if let g = gIndex, peeked.contains(g) {
                Text(full).font(.verse(fontSize)).foregroundStyle(pal.ribbon)
                    .onTapGesture { onTapMasked?(g) }
            } else {
                MaskSlot(hint: shown, length: full.count, fontSize: fontSize)
                    .onTapGesture { if let g = gIndex { onTapMasked?(g) } }
            }
        case let .blank(full, length):
            if let g = gIndex, peeked.contains(g) {
                Text(full).font(.verse(fontSize)).foregroundStyle(pal.ribbon)
                    .onTapGesture { onTapMasked?(g) }
            } else {
                MaskSlot(hint: nil, length: length, fontSize: fontSize)
                    .onTapGesture { if let g = gIndex { onTapMasked?(g) } }
            }
        }
    }
}

/// A blank slot standing in for a hidden word — an underlined gap sized to the
/// word, optionally showing a first-letter hint.
private struct MaskSlot: View {
    @Environment(\.palette) private var pal
    let hint: String?
    let length: Int
    let fontSize: CGFloat
    var body: some View {
        let width = max(fontSize * 0.7, CGFloat(length) * fontSize * 0.46)
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(pal.maskFill)
                .frame(width: width, height: fontSize * 1.05)
            if let hint {
                Text(hint)
                    .font(.verse(fontSize))
                    .foregroundStyle(pal.inkFaint)
                    .padding(.leading, 3)
            }
            RoundedRectangle(cornerRadius: 1)
                .fill(pal.inkFaint.opacity(0.55))
                .frame(width: width, height: 1.5)
                .offset(y: fontSize * 0.5)
        }
        .frame(width: width)
    }
}

/// A simple `Layout` that flows children left-to-right, wrapping to new rows.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 0
    var lineSpacing: CGFloat = 3

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + lineSpacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX; y += rowHeight + lineSpacing; rowHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
