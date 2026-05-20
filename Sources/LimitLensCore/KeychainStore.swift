import Foundation
import Security

public protocol SecretStore {
    func readSecret(account: String) throws -> String?
    func saveSecret(_ secret: String, account: String) throws
    func deleteSecret(account: String) throws
}

public struct SystemKeychainStore: SecretStore {
    private let service: String

    public init(service: String = "com.limitlens.dashboard") {
        self.service = service
    }

    public func readSecret(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
        guard
            let data = item as? Data,
            let value = String(data: data, encoding: .utf8)
        else {
            throw KeychainError.invalidData
        }
        return value
    }

    public func saveSecret(_ secret: String, account: String) throws {
        let data = Data(secret.utf8)
        let query = baseQuery(account: account)
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(updateStatus)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.unhandledStatus(addStatus)
        }
    }

    public func deleteSecret(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }
        throw KeychainError.unhandledStatus(status)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

public enum KeychainError: Error, Equatable, Sendable {
    case unhandledStatus(OSStatus)
    case invalidData
    case commandTimedOut
    case commandFailed(Int32, String)
}

public protocol ClaudeOAuthStore {
    func readAccessToken() async throws -> String?
}

public struct ClaudeCodeKeychainOAuthStore: ClaudeOAuthStore {
    private let readRawSecret: () throws -> String?

    public init(
        account: String = ProcessInfo.processInfo.environment["USER"] ?? NSUserName(),
        service: String = "Claude Code-credentials",
        securityExecutable: URL = URL(fileURLWithPath: "/usr/bin/security"),
        timeout: TimeInterval = 2
    ) {
        self.readRawSecret = {
            try SecurityCommandReader(
                executable: securityExecutable,
                account: account,
                service: service,
                timeout: timeout
            ).readSecret()
        }
    }

    public init(secretStore: SecretStore, account: String) {
        self.readRawSecret = {
            try secretStore.readSecret(account: account)
        }
    }

    public func readAccessToken() async throws -> String? {
        let rawValue = try await Task.detached {
            try readRawSecret()
        }.value

        return try Self.accessToken(fromRawValue: rawValue)
    }

    private static func accessToken(fromRawValue rawValue: String?) throws -> String? {
        guard
            let rawValue,
            !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        let data = Data(rawValue.utf8)
        let credentials = try JSONDecoder().decode(ClaudeCodeKeychainCredentials.self, from: data)
        return credentials.claudeAiOauth.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

private struct SecurityCommandReader {
    let executable: URL
    let account: String
    let service: String
    let timeout: TimeInterval

    func readSecret() throws -> String? {
        let process = Process()
        process.executableURL = executable
        process.arguments = [
            "find-generic-password",
            "-a", account,
            "-w",
            "-s", service
        ]

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }

        if process.isRunning {
            process.terminate()
            throw KeychainError.commandTimedOut
        }

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: outputData, encoding: .utf8) ?? ""
        let stderr = String(data: errorData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            if stderr.localizedCaseInsensitiveContains("could not be found") {
                return nil
            }
            throw KeychainError.commandFailed(
                process.terminationStatus,
                stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ClaudeCodeKeychainCredentials: Decodable {
    let claudeAiOauth: OAuth

    struct OAuth: Decodable {
        let accessToken: String
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
