import AppKit
import UserNotifications

@Observable
class StatusViewModel {
  var prStatuses: [PRStatus] = []
  var isLoading = false
  var errorMessage: String?
  var lastUpdated: Date?
  var onStatusIconChange: ((NSImage) -> Void)?

  @ObservationIgnored private var suppressObservers = true

  var token: String = "" {
    didSet {
      guard !suppressObservers, token != oldValue else { return }
      saveToken(token)
    }
  }

  var showFloatingWindow: Bool = false {
    didSet {
      guard !suppressObservers, showFloatingWindow != oldValue else { return }
      UserDefaults.standard.set(showFloatingWindow, forKey: "showFloatingWindow")
    }
  }

  var pollingInterval: Double = 600 {
    didSet {
      guard !suppressObservers, pollingInterval != oldValue else { return }
      UserDefaults.standard.set(pollingInterval, forKey: "pollingInterval")
      rescheduleTimer()
    }
  }

  private var timer: Timer?
  private var previousStates: [Int: [Int: CheckState]] = [:]

  init() {
    token = loadToken() ?? ""
    let saved = UserDefaults.standard.double(forKey: "pollingInterval")
    if saved >= 30 { pollingInterval = saved }
    showFloatingWindow = UserDefaults.standard.bool(forKey: "showFloatingWindow")
    suppressObservers = false
    requestNotificationPermission()
  }

  func startPolling() {
    refresh()
    rescheduleTimer()
  }

  func refresh() {
    guard !token.isEmpty else { return }
    Task { @MainActor in
      isLoading = true
      errorMessage = nil
      do {
        let prs = try await GitHubService.fetchOpenPRs(token: token)
        let results = try await withThrowingTaskGroup(of: PRStatus.self) { group in
          for pr in prs {
            group.addTask { try await GitHubService.fetchChecks(pr: pr, token: self.token) }
          }
          var collected: [PRStatus] = []
          for try await result in group { collected.append(result) }
          return collected
        }

        let oldStates = previousStates
        previousStates = [:]
        for pr in results {
          var jobMap: [Int: CheckState] = [:]
          for job in pr.jobs {
            jobMap[job.id] = job.state
            if job.state == .failure,
              let oldPR = oldStates[pr.id],
              let oldState = oldPR[job.id],
              oldState != .failure
            {
              sendNotification(pr: pr, job: job)
            }
          }
          previousStates[pr.id] = jobMap
        }

        prStatuses = results.sorted { $0.createdAt > $1.createdAt }
        lastUpdated = Date()
        updateIcon()
      } catch {
        errorMessage = error.localizedDescription
      }
      isLoading = false
    }
  }

  private func rescheduleTimer() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) {
      [weak self] _ in
      self?.refresh()
    }
  }

  private func updateIcon() {
    let overall: CheckState
    if prStatuses.isEmpty {
      overall = .pending
    } else if prStatuses.contains(where: { $0.overallState == .failure }) {
      overall = .failure
    } else if prStatuses.contains(where: { $0.overallState == .pending }) {
      overall = .pending
    } else {
      overall = .success
    }

    let color: NSColor =
      switch overall {
      case .success: .systemGreen
      case .failure: .systemRed
      case .pending: .systemYellow
      case .skipped: .systemGray
      }

    let image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "CI Status")!
    let config = NSImage.SymbolConfiguration(paletteColors: [color])
      .applying(NSImage.SymbolConfiguration(pointSize: 16, weight: .regular))
    let colored = image.withSymbolConfiguration(config)!
    colored.isTemplate = false
    onStatusIconChange?(colored)
  }

  // MARK: - Token Storage

  private func saveToken(_ token: String) {
    UserDefaults.standard.set(token, forKey: "github-token")
  }

  private func loadToken() -> String? {
    UserDefaults.standard.string(forKey: "github-token")
  }

  // MARK: - Notifications

  private func requestNotificationPermission() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
  }

  private func sendNotification(pr: PRStatus, job: JobStatus) {
    let content = UNMutableNotificationContent()
    content.title = "CI Failed"
    content.body = "\(pr.title) — \(job.name) failed"
    content.sound = .default
    content.userInfo = ["url": pr.url.absoluteString]
    let request = UNNotificationRequest(
      identifier: "kanshi-\(pr.id)-\(job.id)",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }
}
