import SwiftUI
import AgentHUDCore

/// Per-model breakdown of today's local Codex token spend at OpenAI API prices.
struct CodexCostDetails: View {
    let cost: CodexPricing.Estimate
    private let theme = Theme.island

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.text("今日消耗估算", "Today's est. cost")).font(.ui(12, .semibold))
                Spacer()
                Text(MoneyFormat.amount(cost.total, currency: "USD", estimated: true))
                    .font(.tabular(11, .semibold)).foregroundStyle(theme.text)
            }
            Text(L10n.text("模型 · Token · 折算", "Model · tokens · est. cost"))
                .font(.ui(10)).foregroundStyle(theme.secondary)
            VStack(spacing: 8) {
                ForEach(cost.byModel, id: \.model) { entry in
                    HStack {
                        Text(entry.model)
                            .foregroundStyle(theme.secondary)
                        Spacer()
                        Text("\(TokenFormat.short(entry.tokens)) tok · \(MoneyFormat.amount(entry.cost, currency: "USD", estimated: true))")
                            .font(.tabular(12))
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            if !cost.unpricedModels.isEmpty {
                Text(L10n.text("未定价（未计入）：", "Unpriced (not counted): ") + cost.unpricedModels.joined(separator: ", "))
                    .font(.ui(11)).foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(L10n.text("按 OpenAI API 定价估算，订阅不实际计费。价格核对于 ", "Estimated at OpenAI API prices; a subscription is not billed per token. Prices checked ")
                 + CodexPricing.checkedOn)
                .font(.ui(10)).foregroundStyle(theme.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.ui(11))
        .foregroundStyle(theme.text)
        .padding(12)
        .frame(width: 310)
        .background(RoundedRectangle(cornerRadius: 10).fill(theme.windowBackground))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(theme.cardBorder))
        .fixedSize(horizontal: false, vertical: true)
    }

    static func accessibilityText(_ cost: CodexPricing.Estimate) -> String {
        MoneyFormat.amount(cost.total, currency: "USD", estimated: true) + "\n" + cost.detailsText
    }
}
