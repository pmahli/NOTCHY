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
/// Prompt behaviour: background polling must never open an authentication UI.
/// A signed + notarized build can read items it is already trusted for silently;
/// items that still require user interaction are treated as unavailable until
/// the user explicitly saves the credential again from Settings.
public final class KeychainStore {
    private let service: String

    /// In-memory cache of decrypted items, keyed by account. The first read of
    /// each credential hits the Keychain; every subsequent read in the same
    /// launch is served from memory. Writes/deletes keep the cache coherent.
    private var cache: [String: Data] = [:]
    /// Accounts that have already had a read attempt in this process. A
    /// cancelled/denied read must not be retried during background polling; an
    /// explicit write resets the account state.
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
        readAttempted.insert(account)
        lock.unlock()

        var query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        // This method is used by status checks and background usage polling.
        // Never let a failed ACL lookup turn into a password dialog every few
        // minutes. An explicit save from Settings recreates the item with the
        // current signed app identity.
        let authenticationContext = LAContext()
        authenticationContext.interactionNotAllowed = true
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
