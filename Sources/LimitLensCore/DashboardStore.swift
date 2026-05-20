import Combine
import Foundation

public protocol ProviderUsageService {
    func fetchOpenAI(configuration: OpenAIConfiguration, range: APIQueryRange) async throws -> ProviderUsageData
    func fetchAnthropic(configuration: AnthropicConfiguration, range: APIQueryRange) async throws -> ProviderUsageData
}

public struct LiveProviderUsageService: ProviderUsageService {
    private let openAIClient: OpenAIClient
    private let anthropicClient: AnthropicClient

    public init(openAIClient: OpenAIClient = OpenAIClient(), anthropicClient: AnthropicClient = AnthropicClient()) {
        self.openAIClient = openAIClient
        self.anthropicClient = anthropicClient
    }

    public func fetchOpenAI(configuration: OpenAIConfiguration, range: APIQueryRange) async throws -> ProviderUsageData {
        try await openAIClient.fetchUsage(configuration: configuration, range: range)
    }

    public func fetchAnthropic(configuration: AnthropicConfiguration, range: APIQueryRange) async throws -> ProviderUsageData {
        try await anthropicClient.fetchUsage(configuration: configuration, range: range)
    }
}

@MainActor
public final class DashboardStore: ObservableObject {
    public static let openAIKeyAccount = "openai-admin-key"
    public static let anthropicKeyAccount = "anthropic-admin-key"
    public static let openAIProjectIDDefaultsKey = "openai-project-id"

    @Published public private(set) var providerSnapshots: [ProviderSnapshot]
    @Published public private(set) var isRefreshing = false
    @Published public private(set) var lastRefresh: Date?
    @Published public var openAIProjectID: String {
        didSet {
            let trimmed = openAIProjectID.trimmingCharacters(in: .whitespacesAndNewlines)
            userDefaults.set(trimmed, forKey: Self.openAIProjectIDDefaultsKey)
        }
    }

    private let secretStore: SecretStore
    private let providerService: ProviderUsageService
    private let userDefaults: UserDefaults

    public init(
        secretStore: SecretStore = SystemKeychainStore(),
        providerService: ProviderUsageService = LiveProviderUsageService(),
        userDefaults: UserDefaults = .standard
    ) {
        self.secretStore = secretStore
        self.providerService = providerService
        self.userDefaults = userDefaults
        self.openAIProjectID = userDefaults.string(forKey: Self.openAIProjectIDDefaultsKey) ?? ""
        self.providerSnapshots = Provider.allCases.map { provider in
            StatusEvaluator.snapshot(
                provider: provider,
                credentialsPresent: false,
                costUSD: nil,
                totalTokens: nil,
                requestCount: nil,
                limits: [],
                error: nil,
                now: Date()
            )
        }
    }

    public func snapshot(for provider: Provider) -> ProviderSnapshot {
        providerSnapshots.first { $0.provider == provider } ?? StatusEvaluator.snapshot(
            provider: provider,
            credentialsPresent: false,
            costUSD: nil,
            totalTokens: nil,
            requestCount: nil,
            limits: [],
            error: nil,
            now: Date()
        )
    }

    public func refresh(now: Date = Date()) async {
        isRefreshing = true
        defer { isRefreshing = false }

        let range = APIQueryRange.monthToDate(now: now)
        await refreshOpenAI(range: range, now: now)
        await refreshAnthropic(range: range, now: now)
        lastRefresh = now
    }

    public func saveOpenAIKey(_ key: String) throws {
        try save(key, account: Self.openAIKeyAccount)
    }

    public func saveAnthropicKey(_ key: String) throws {
        try save(key, account: Self.anthropicKeyAccount)
    }

    public func clearOpenAIKey() throws {
        try secretStore.deleteSecret(account: Self.openAIKeyAccount)
    }

    public func clearAnthropicKey() throws {
        try secretStore.deleteSecret(account: Self.anthropicKeyAccount)
    }

    public func hasOpenAIKey() -> Bool {
        ((try? secretStore.readSecret(account: Self.openAIKeyAccount)) ?? nil)?.isEmpty == false
    }

    public func hasAnthropicKey() -> Bool {
        ((try? secretStore.readSecret(account: Self.anthropicKeyAccount)) ?? nil)?.isEmpty == false
    }

    private func save(_ key: String, account: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try secretStore.deleteSecret(account: account)
        } else {
            try secretStore.saveSecret(trimmed, account: account)
        }
    }

    private func refreshOpenAI(range: APIQueryRange, now: Date) async {
        guard let key = readKey(account: Self.openAIKeyAccount) else {
            replace(snapshot: StatusEvaluator.snapshot(
                provider: .openAI,
                credentialsPresent: false,
                costUSD: nil,
                totalTokens: nil,
                requestCount: nil,
                limits: [],
                error: nil,
                now: now
            ))
            return
        }

        do {
            let data = try await providerService.fetchOpenAI(
                configuration: OpenAIConfiguration(adminKey: key, projectID: openAIProjectID),
                range: range
            )
            replace(snapshot: StatusEvaluator.snapshot(
                provider: .openAI,
                credentialsPresent: true,
                costUSD: data.costUSD,
                totalTokens: data.totalTokens,
                requestCount: data.requestCount,
                limits: data.limits,
                error: nil,
                now: now
            ))
        } catch {
            replace(snapshot: errorSnapshot(provider: .openAI, error: error, now: now))
        }
    }

    private func refreshAnthropic(range: APIQueryRange, now: Date) async {
        guard let key = readKey(account: Self.anthropicKeyAccount) else {
            replace(snapshot: StatusEvaluator.snapshot(
                provider: .anthropic,
                credentialsPresent: false,
                costUSD: nil,
                totalTokens: nil,
                requestCount: nil,
                limits: [],
                error: nil,
                now: now
            ))
            return
        }

        do {
            let data = try await providerService.fetchAnthropic(
                configuration: AnthropicConfiguration(adminKey: key),
                range: range
            )
            replace(snapshot: StatusEvaluator.snapshot(
                provider: .anthropic,
                credentialsPresent: true,
                costUSD: data.costUSD,
                totalTokens: data.totalTokens,
                requestCount: data.requestCount,
                limits: data.limits,
                error: nil,
                now: now
            ))
        } catch {
            replace(snapshot: errorSnapshot(provider: .anthropic, error: error, now: now))
        }
    }

    private func errorSnapshot(provider: Provider, error: Error, now: Date) -> ProviderSnapshot {
        let previous = snapshot(for: provider)
        let providerError = (error as? ProviderClientError) ?? ProviderClientError.network(error.localizedDescription)
        return StatusEvaluator.snapshot(
            provider: provider,
            credentialsPresent: true,
            costUSD: previous.costUSD,
            totalTokens: previous.totalTokens,
            requestCount: previous.requestCount,
            limits: previous.limits,
            error: providerError,
            now: now
        )
    }

    private func readKey(account: String) -> String? {
        guard let key = try? secretStore.readSecret(account: account) else {
            return nil
        }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func replace(snapshot: ProviderSnapshot) {
        providerSnapshots = providerSnapshots.map { existing in
            existing.provider == snapshot.provider ? snapshot : existing
        }
    }
}
