import Foundation
import LocalAuthentication
import Security

enum PasswordStore {
  static let service = "com.aethernative.AetherZip.archive-password"
  static func save(_ password: String, for url: URL) throws {
    let account = url.standardizedFileURL.path
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    var error: Unmanaged<CFError>?
    guard
      let access = SecAccessControlCreateWithFlags(
        nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, .userPresence, &error)
    else {
      throw NSError(
        domain: "Keychain", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法创建钥匙串保护。"])
    }
    var item = query
    item[kSecValueData as String] = Data(password.utf8)
    item[kSecAttrAccessControl as String] = access
    let status = SecItemAdd(item as CFDictionary, nil)
    if status == errSecDuplicateItem {
      let result = SecItemUpdate(
        query as CFDictionary, [kSecValueData as String: Data(password.utf8)] as CFDictionary)
      guard result == errSecSuccess else { throw failure(result) }
    } else if status != errSecSuccess {
      throw failure(status)
    }
  }
  static func read(for url: URL) throws -> String {
    let context = LAContext()
    context.localizedReason = "读取此归档保存在钥匙串中的密码"
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
      kSecAttrAccount as String: url.standardizedFileURL.path, kSecReturnData as String: true,
      kSecUseAuthenticationContext as String: context, kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var data: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &data)
    guard status == errSecSuccess, let d = data as? Data,
      let value = String(data: d, encoding: .utf8)
    else { throw failure(status) }
    return value
  }
  static func failure(_ status: OSStatus) -> NSError {
    NSError(
      domain: NSOSStatusErrorDomain, code: Int(status),
      userInfo: [
        NSLocalizedDescriptionKey: status == errSecItemNotFound
          ? "没有为此归档保存密码。" : (SecCopyErrorMessageString(status, nil) as String? ?? "钥匙串操作失败。")
      ])
  }
}
