import Foundation

/// Official OpenAI API prices verified 2026-09-20. Codex plans are subscriptions, so this estimates what the
/// locally recorded tokens would have cost at API rates; it is not an invoice.
/// https://developers.openai.com/api/docs/pricing
public enum CodexPricing {
    public static let checkedOn = "2026-09-20"
    public static let sourceURL = URL(string: "https://developers.openai.com/api/docs/pricing")!

    /// One model's spend in a range.
    public struct ModelCost: Hashable, Sendable {
        public let model: String
        public let tokens: Int
        public let cost: Decimal
    }

    /// The sum over the priced buckets, each model's own row, and the models no price is known for.
    public struct Estimate: Sendable {
        public let total: Decimal
        public let byModel: [ModelCost]
        /// Sorted models that reported tokens but have no known price; their tokens are not in `total`.
        public let unpricedModels: [String]
        public let unpricedTokens: Int
        /// Tokens across priced and unpriced models.
        public var tokens: Int { byModel.reduce(0) { $0 + $1.tokens } + unpricedTokens }
    }

    /// USD per million tokens: input, cached input, output. Strings keep the decimals exact.
    private static let prices: [String: (String, String, String)] = [
        "gpt-6-astra": ("10", "1", "50"),
        "gpt-5.6-sol": ("4", "0.4", "20"),
        "gpt-5.6-terra": ("2", "0.2", "12"),
        "gpt-5.6-luna": ("0.2", "0.02", "1.2"),
        "gpt-5.5": ("5", "0.5", "30"),
        "gpt-5.4": ("2.5", "0.25", "15"),
        "gpt-5.4-mini": ("0.75", "0.075", "4.5"),
        "gpt-5.4-nano": ("0.2", "0.02", "1.25"),
        "gpt-5.3-codex": ("1.75", "0.175", "14"),
        "gpt-5.2-codex": ("1.75", "0.175", "14"),
        "gpt-5.1-codex": ("1.25", "0.125", "10"),
        "gpt-5.1-codex-max": ("1.25", "0.125", "10"),
        "gpt-5.1-codex-mini": ("0.25", "0.025", "2"),
        "gpt-5.1": ("1.25", "0.125", "10"),
        "gpt-5-codex": ("1.25", "0.125", "10"),
        "gpt-5": ("1.25", "0.125", "10"),
        "gpt-5-mini": ("0.25", "0.025", "2"),
        "gpt-5-nano": ("0.05", "0.005", "0.4"),
        "codex-mini-latest": ("1.5", "0.375", "6"),
        "codex-mini": ("1.5", "0.375", "6"),
        "o3": ("2", "0.5", "8"),
        "o4-mini": ("1.1", "0.275", "4.4"),
    ]

    /// Estimated API cost in USD of one usage sample; nil when the model has no known price.
    public static func estimate(model: String, input: Int, cachedInput: Int, output: Int) -> Decimal? {
        guard let prices = prices[model] else { return nil }
        return (Decimal(input) * Decimal(string: prices.0)!
            + Decimal(cachedInput) * Decimal(string: prices.1)!
            + Decimal(output) * Decimal(string: prices.2)!) / 1_000_000
    }

    /// Estimated API cost of the Codex buckets at or after `since`; nil when no Codex bucket is in the range.
    /// Cached input is already excluded from a bucket's input tokens, so each dimension prices on its own.
    public static func estimate(buckets: [UsageBucket], since: Date) -> Estimate? {
        var byModel: [String: (tokens: Int, cost: Decimal)] = [:]
        var unpriced: [String: Int] = [:]
        for bucket in buckets where bucket.start >= since && bucket.agentId.hasPrefix("codex-model:") {
            let model = String(bucket.agentId.dropFirst("codex-model:".count))
            guard let cost = estimate(model: model, input: bucket.tokensIn, cachedInput: bucket.cacheReadTokens, output: bucket.tokensOut)
            else { unpriced[model, default: 0] += bucket.total + bucket.cacheReadTokens; continue }
            let entry = byModel[model] ?? (0, 0)
            byModel[model] = (entry.tokens + bucket.total + bucket.cacheReadTokens, entry.cost + cost)
        }
        guard !byModel.isEmpty || !unpriced.isEmpty else { return nil }
        return Estimate(total: byModel.values.reduce(0) { $0 + $1.cost },
                        byModel: byModel.map { ModelCost(model: $0.key, tokens: $0.value.tokens, cost: $0.value.cost) }
                            .sorted { $0.cost != $1.cost ? $0.cost > $1.cost : $0.model < $1.model },
                        unpricedModels: unpriced.keys.sorted(),
                        unpricedTokens: unpriced.values.reduce(0, +))
    }
}

extension CodexPricing.Estimate {
    /// Per-model breakdown plus the unpriced names, for tooltips and accessibility text.
    public var detailsText: String {
        var lines = byModel.map {
            "\($0.model): \(TokenFormat.short($0.tokens)) tok ≈ \(MoneyFormat.amount($0.cost, currency: "USD", estimated: true))"
        }
        if !unpricedModels.isEmpty {
            lines.append(L10n.text("未定价（未计入）：", "Unpriced (not counted): ") + unpricedModels.joined(separator: ", "))
        }
        return lines.joined(separator: "\n")
    }
}
