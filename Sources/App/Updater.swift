import Combine
import Foundation
import Sparkle

@MainActor
final class Updater: NSObject, ObservableObject, SPUUpdaterDelegate {
  private var updaterController: SPUStandardUpdaterController?
  private var cancellables = Set<AnyCancellable>()

  @Published var canCheckForUpdates = false
  @Published var automaticallyChecksForUpdates = true {
    didSet {
      updaterController?.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
    }
  }

  override init() {
    super.init()
    let controller = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: self,
      userDriverDelegate: nil
    )
    self.updaterController = controller
    self.automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
    controller.updater.publisher(for: \.canCheckForUpdates)
      .receive(on: RunLoop.main)
      .sink { [weak self] canCheck in
        self?.canCheckForUpdates = canCheck
      }
      .store(in: &cancellables)
  }

  func checkForUpdates() {
    updaterController?.checkForUpdates(nil)
  }
}
