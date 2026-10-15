import CoreServices
import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable final class LaunchAtLogin {
  static let shared = LaunchAtLogin()

  var isEnabled: Bool = false
  var requiresApproval: Bool = false
  var lastError: String?

  init() {
    refresh()
  }

  func refresh() {
    let currentStatus = SMAppService.mainApp.status
    isEnabled = (currentStatus == .enabled)
    requiresApproval = (currentStatus == .requiresApproval)
  }

  func setEnabled(_ enable: Bool) {
    lastError = nil
    do {
      if enable {
        if SMAppService.mainApp.status != .enabled {
          try SMAppService.mainApp.register()
        }
      } else {
        if SMAppService.mainApp.status != .notRegistered {
          try SMAppService.mainApp.unregister()
        }
      }
    } catch {
      lastError = error.localizedDescription
    }
    refresh()
  }

  func openSystemSettings() {
    SMAppService.openSystemSettingsLoginItems()
  }

  static var wasLaunchedAtLogin: Bool {
    guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
    return event.attributeDescriptor(forKeyword: AEKeyword(keyAELaunchedAsLogInItem))?.booleanValue ?? false
  }
}
