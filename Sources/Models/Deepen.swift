import Foundation

/// Optional "approfondir" — a deeper reading of a poem from Claude. The app is
/// fully functional WITHOUT this: the baked craft notes are the core. The button
/// only appears when a key is present.
///
/// Key resolution (never hardcoded): the `CLAUDE_API_KEY` environment variable,
/// else the first non-empty line of `~/.recital/config`.
public enum Deepen {

    public static var apiKey: String? {
        if let env = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"],
           !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return env.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let path = ("~/.recital/config" as NSString).expandingTildeInPath
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        let line = contents
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        return (line?.isEmpty == false) ? line : nil
    }

    public static var isAvailable: Bool { apiKey != nil }

    public enum DeepenError: Error { case noKey, badResponse, http(Int) }

    /// Ask Claude for a deeper reading of a poem, in the active UI language.
    /// We send only the poem's own metadata + verse (already public-domain).
    public static func reading(for poem: Poem, lang: Lang) async throws -> String {
        guard let key = apiKey else { throw DeepenError.noKey }

        let langName = lang == .fr ? "français" : "English"
        let system = lang == .fr
            ? "Tu es un lecteur de poésie sensible et érudit. Offre une lecture approfondie — images, sons, forme, sens — en français, en 2 à 3 courts paragraphes. Sois concret et évite le jargon."
            : "You are a sensitive, erudite reader of poetry. Offer a deeper reading — imagery, sound, form, meaning — in English, in 2 to 3 short paragraphs. Be concrete and avoid jargon."

        let verse = poem.spokenLines.joined(separator: "\n")
        let userText = """
        Poem: \"\(poem.title)\" by \(poem.author) (\(poem.year)).
        Language of the poem: \(poem.isFrench ? "French" : "English").
        Please answer in \(langName).

        \(verse)
        """

        let body: [String: Any] = [
            "model": "claude-opus-4-8",
            "max_tokens": 700,
            "system": system,
            "messages": [["role": "user", "content": userText]]
        ]

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 45

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw DeepenError.badResponse }
        guard (200..<300).contains(http.statusCode) else { throw DeepenError.http(http.statusCode) }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw DeepenError.badResponse
        }
        let text = content.compactMap { $0["text"] as? String }.joined()
        guard !text.isEmpty else { throw DeepenError.badResponse }
        return text
    }
}
