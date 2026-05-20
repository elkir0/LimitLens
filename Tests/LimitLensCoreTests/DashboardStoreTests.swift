import XCTest
@testable import LimitLensCore

@MainActor
final class DashboardStoreTests: XCTestCase {
    func testMissingKeysProduceUnconfiguredSnapshots() async {
        let store = DashboardStore(
            secretStore: MemorySecretStore(),
            providerService: FakeProviderUsageService(),
            userDefaults: isolatedDefaults()
        )

        await store.refresh(now: Date(timeIntervalSince1970: 1_800_000_000))

        XCTAssertEqual(store.snapshot(for: .openAI).health, .unconfigured)
        XCTAssertEqual(store.snapshot(for: .anthropic).health, .unconfigured)
    }

    func testSuccessfulRefreshUpdatesBothProviders() async throws {
        let secrets = MemorySecretStore()
        try secrets.saveSecret("openai", account: DashboardStore.openAIKeyAccount)
        try secrets.saveSecret("anthropic", account: DashboardStore.anthropicKeyAccount)

        let service = FakeProviderUsageService()
        service.openAIResult = .success(ProviderUsageData(
            costUSD: Decimal(string: "12.34"),
            totalTokens: 1_000,
            requestCount: 3,
            limits: [LimitMetric(id: "gpt", title: "gpt-5.4", value: "1K RPM")]
        ))
        service.anthropicResult = .success(ProviderUsageData(
            costUSD: Decimal(string: "1.25"),
            totalTokens: 2_000,
            requestCount: nil,
            limits: [LimitMetric(id: "claude", title: "claude-sonnet-4", value: "50 RPM")]
        ))

        let store = DashboardStore(
            secretStore: secrets,
            providerService: service,
            userDefaults: isolatedDefaults()
        )

        await store.refresh(now: Date(timeIntervalSince1970: 1_800_000_000))

        XCTAssertEqual(store.snapshot(for: .openAI).health, .ok)
        XCTAssertEqual(store.snapshot(for: .openAI).costUSD, Decimal(string: "12.34"))
        XCTAssertEqual(store.snapshot(for: .anthropic).health, .ok)
        XCTAssertEqual(store.snapshot(for: .anthropic).totalTokens, 2_000)
    }

    func testRefreshErrorKeepsPreviousUsageValues() async throws {
        let secrets = MemorySecretStore()
        try secrets.saveSecret("openai", account: DashboardStore.openAIKeyAccount)
        try secrets.saveSecret("anthropic", account: DashboardStore.anthropicKeyAccount)

        let service = FakeProviderUsageService()
        service.openAIResult = .success(ProviderUsageData(costUSD: Decimal(string: "12.34"), totalTokens: 1_000, requestCount: 3, limits: []))
        service.anthropicResult = .success(ProviderUsageData(costUSD: Decimal(string: "1.25"), totalTokens: 2_000, requestCount: nil, limits: []))

        let store = DashboardStore(
            secretStore: secrets,
            providerService: service,
            userDefaults: isolatedDefaults()
        )
        await store.refresh(now: Date(timeIntervalSince1970: 1_800_000_000))

        service.openAIResult = .failure(ProviderClientError.unauthorized)
        await store.refresh(now: Date(timeIntervalSince1970: 1_800_000_060))

        let snapshot = store.snapshot(for: .openAI)
        XCTAssertEqual(snapshot.health, .error)
        XCTAssertEqual(snapshot.summary, "Invalid key")
        XCTAssertEqual(snapshot.costUSD, Decimal(string: "12.34"))
        XCTAssertEqual(snapshot.totalTokens, 1_000)
    }
}

private final class FakeProviderUsageService: ProviderUsageService {
    var openAIResult: Result<ProviderUsageData, Error> = .success(ProviderUsageData(costUSD: nil, totalTokens: nil, requestCount: nil, limits: []))
    var anthropicResult: Result<ProviderUsageData, Error> = .success(ProviderUsageData(costUSD: nil, totalTokens: nil, requestCount: nil, limits: []))

    func fetchOpenAI(configuration: OpenAIConfiguration, range: APIQueryRange) async throws -> ProviderUsageData {
        try openAIResult.get()
    }

    func fetchAnthropic(configuration: AnthropicConfiguration, range: APIQueryRange) async throws -> ProviderUsageData {
        try anthropicResult.get()
    }
}

private final class MemorySecretStore: SecretStore {
    private var storage: [String: String] = [:]

    func readSecret(account: String) throws -> String? {
        storage[account]
    }

    func saveSecret(_ secret: String, account: String) throws {
        storage[account] = secret
    }

    func deleteSecret(account: String) throws {
        storage.removeValue(forKey: account)
    }
}

private func isolatedDefaults() -> UserDefaults {
    let suiteName = "LimitLensTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
