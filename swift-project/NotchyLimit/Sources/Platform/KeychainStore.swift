import Foundation
import LocalAuthentication
import Security
import os.log

private let logger = Logger(subsystem: "com.notchylimit.NotchyLimit", category: "Keychain")

/// Tiny Keychain wrapper for `kSecClassGenericPassword` items.
/// Used to store provider credentials (e.g. Claude session cookie).
///
/// Security posture:
///  - `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — readable only while
///    the screen is unlocked; never leaves the device via iCloud backup.
///  - Access is governed by the default ACL: the app that created an item can
///    read it back without a prompt **once it has a stable code signature**.
///
/// Prompt behaviour: macOS keys keychain access to the app's code-signing
/// identity. A signed + notarized build reads its own items silently (and any
/// one-time "Always Allow" sticks). Unsigned/ad-hoc dev builds present a
/// changing identity, so macOS may still prompt — but the in-memory cache below
/// collapses that to at most one prompt per credential per launch instead of
/// one on every usage poll.
public final class KeychainStore {
    private let service: String

    /// In-memory cache of decrypted items, keyed by account. The first read of
    /// each credential hits the Keychain (and may prompt on unsigned builds);
    /// every subsequent read in the same launch is served from memory, so the
    /// 5-minute usage poll never re-triggers a Keychain prompt. Writes/deletes
    /// keep the cache coherent.
    private var cache: [String: Data] = [:]
    /// Accounts that have already had their one interactive read attempt in
    /// this process. A cancelled/denied read must not prompt again during a
    /// background poll; an explicit write resets the account state.
    private var readAttempted: Set<String> = []
    private let lock = NSLock()

    public init(service: String) { self.service = service }

    public func set(account: String, data: Data) {
        let label = "\(service) — \(account)"
        var query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrLabel as String:   label,
        ]
        SecItemDelete(query as CFDictionary)

        query[kSecValueData as String]      = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        // No custom `SecAccessCreate` ACL: the legacy trusted-application ACL
        // (deprecated since macOS 10.10) is the path most sensitive to a
        // changing code identity, so it actively *worsened* re-prompting on
        // ad-hoc builds. The default ACL ties the item to the creating app's
        // signature, which is what we want for a signed release.

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            lock.lock()
            cache[account] = data
            readAttempted.remove(account)
            lock.unlock()
        } else {
            logger.error("Keychain write failed: OSStatus \(status, privacy: .public)")
        }
    }

    public func get(account: String) -> Data? {
        lock.lock()
        if let cached = cache[account] {
            lock.unlock()
            return cached
        }
        let allowPrompt = !readAttempted.contains(account)
        readAttempted.insert(account)
        lock.unlock()

        var query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        let authenticationContext = LAContext()
        if allowPrompt {
            authenticationContext.localizedReason =
                "Notchy wants to read a saved provider credential from Keychain."
        } else {
            authenticationContext.interactionNotAllowed = true
        }
        query[kSecUseAuthenticationContext as String] = authenticationContext

        var item: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }

        lock.lock(); cache[account] = data; lock.unlock()
        return data
    }

    @discardableResult
    public func delete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        lock.lock()
        cache[account] = nil
        readAttempted.remove(account)
        lock.unlock()
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
