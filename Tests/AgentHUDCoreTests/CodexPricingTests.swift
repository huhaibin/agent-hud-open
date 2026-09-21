import XCTest
@testable import AgentHUDCore

final class CodexPricingTests: XCTestCase {
    func testEstimatePricesEachDimensionPerMillionTokens() {
        // gpt-5.3-codex: $1.75 in, $0.175 cached, $14 out per million.
        let cost = CodexPricing.estimate(model: "gpt-5.3-codex", input: 1_000_000, cachedInput: 2_000_000, output: 500_000)
        XCTAssertEqual(cost, Decimal(string: "9.1"))
    }

    func testEstimateCoversOlderCodexModels() {
        XCTAssertEqual(CodexPricing.estimate(model: "gpt-5.1-codex-mini", input: 2_000_000, cachedInput: 0, output: 100_000),
                       Decimal(string: "0.7"))
        XCTAssertEqual(CodexPricing.estimate(model: "codex-mini-latest", input: 0, cachedInput: 1_000_000, output: 0),
                       Decimal(string: "0.375"))
    }

    func testEstimateRejectsUnknownModels() {
        XCTAssertNil(CodexPricing.estimate(model: "gpt-5.3-codex-spark", input: 1, cachedInput: 0, output: 1))
        XCTAssertNil(CodexPricing.estimate(model: "", input: 1, cachedInput: 0, output: 1))
    }

    func testBucketEstimateSumsPerModelAndReportsUnpriced() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let buckets = [
            UsageBucket(start: start, agentId: "codex-model:gpt-5.3-codex", tokensIn: 1_000_000, tokensOut: 500_000, cacheReadTokens: 2_000_000),
            UsageBucket(start: start, agentId: "codex-model:gpt-5.3-codex", tokensIn: 1_000_000, tokensOut: 0),
            UsageBucket(start: start, agentId: "codex-model:gpt-5.3-codex-spark", tokensIn: 10, tokensOut: 10),
            UsageBucket(start: start, agentId: "claude-model:opus", tokensIn: 9_000_000, tokensOut: 9_000_000),
            UsageBucket(start: start.addingTimeInterval(-900), agentId: "codex-model:gpt-5.3-codex", tokensIn: 9_000_000, tokensOut: 0),
        ]
        let estimate = CodexPricing.estimate(buckets: buckets, since: start)
        XCTAssertEqual(estimate?.total, Decimal(string: "10.85"))
        XCTAssertEqual(estimate?.byModel.count, 1)
        XCTAssertEqual(estimate?.byModel.first?.tokens, 4_500_000)
        XCTAssertEqual(estimate?.unpricedModels, ["gpt-5.3-codex-spark"])
        XCTAssertEqual(estimate?.unpricedTokens, 20)
        XCTAssertEqual(estimate?.tokens, 4_500_020)
    }

    func testBucketEstimateIsNilWithoutCodexUsage() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertNil(CodexPricing.estimate(buckets: [], since: start))
        XCTAssertNil(CodexPricing.estimate(buckets: [
            UsageBucket(start: start, agentId: "deepseek-model:deepseek-v4-pro", tokensIn: 5, tokensOut: 5),
        ], since: start))
    }
}
