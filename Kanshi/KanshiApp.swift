import AppKit
import SwiftUI
import UserNotifications

@main
struct KanshiApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    Settings { EmptyView() }
  }
}

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
  private var statusItem: NSStatusItem!
  private let popover = NSPopover()
  private var eventMonitor: Any?
  let viewModel = StatusViewModel()
  var floatingWindow: FloatingWindow?

  func applicationDidFinishLaunching(_ notification: Notification) {
    UNUserNotificationCenter.current().delegate = self

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    if let button = statusItem.button {
      let icon = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "CI Status")
      icon?.isTemplate = false
      button.image = icon
      button.action = #selector(togglePopover)
      button.target = self
    }

    viewModel.onStatusIconChange = { [weak self] image in
      self?.statusItem.button?.image = image
    }

    popover.contentViewController = NSHostingController(
      rootView: PopoverView(
        viewModel: viewModel,
        onToggleFloatingWindow: { [weak self] in
          self?.toggleFloatingWindow()
        })
    )
    popover.contentSize = NSSize(width: 340, height: 500)
    popover.behavior = .applicationDefined

    viewModel.startPolling()

    if viewModel.showFloatingWindow {
      floatingWindow = FloatingWindow(viewModel: viewModel)
      floatingWindow?.orderFront(nil)
    }
  }

  @objc private func togglePopover() {
    if popover.isShown {
      closePopover()
    } else {
      showPopover()
    }
  }

  private func showPopover() {
    guard let button = statusItem.button else { return }
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    popover.contentViewController?.view.window?.makeKey()
    eventMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown]
    ) { [weak self] _ in
      guard let self, self.popover.isShown else { return }
      // Check if click is on the status item — if so, let togglePopover handle it
      if let button = self.statusItem.button,
        let buttonWindow = button.window
      {
        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)
        if screenRect.contains(NSEvent.mouseLocation) {
          return
        }
      }
      self.closePopover()
    }
  }

  private func closePopover() {
    popover.performClose(nil)
    if let monitor = eventMonitor {
      NSEvent.removeMonitor(monitor)
      eventMonitor = nil
    }
  }

  func toggleFloatingWindow() {
    if let window = floatingWindow {
      window.close()
      floatingWindow = nil
    } else {
      floatingWindow = FloatingWindow(viewModel: viewModel)
      floatingWindow?.orderFront(nil)
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
  ) async {
    if let urlString = response.notification.request.content.userInfo["url"] as? String,
      let url = URL(string: urlString)
    {
      NSWorkspace.shared.open(url)
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .sound]
  }
}
