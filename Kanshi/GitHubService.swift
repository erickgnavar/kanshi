import Foundation

enum CheckState: String, Codable {
  case success, failure, pending, skipped
}

struct JobStatus: Identifiable {
  let id: Int
  let name: String
  let state: CheckState
  let url: URL?
}

struct PRStatus: Identifiable {
  let id: Int
  let title: String
  let repo: String
  let url: URL
  let number: Int
  let createdAt: Date
  var jobs: [JobStatus]

  var org: String {
    String(repo.split(separator: "/").first ?? "")
  }

  var overallState: CheckState {
    if jobs.isEmpty { return .pending }
    if jobs.contains(where: { $0.state == .failure }) { return .failure }
    if jobs.contains(where: { $0.state == .pending }) { return .pending }
    return .success
  }
}

struct GitHubService {
  private static let baseURL = "https://api.github.com"

  static func fetchOpenPRs(token: String) async throws -> [PRStatus] {
    let url = URL(string: "\(baseURL)/search/issues?q=is:pr+is:open+author:@me&per_page=50")!
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

    let (data, _) = try await URLSession.shared.data(for: request)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let result = try decoder.decode(SearchResult.self, from: data)

    return result.items.map { item in
      let parts = item.repositoryUrl.split(separator: "/")
      let repo = "\(parts[parts.count - 2])/\(parts[parts.count - 1])"
      let date = ISO8601DateFormatter().date(from: item.createdAt) ?? .distantPast
      return PRStatus(
        id: item.id,
        title: item.title,
        repo: String(repo),
        url: URL(string: item.htmlUrl)!,
        number: item.number,
        createdAt: date,
        jobs: []
      )
    }
  }

  static func fetchChecks(pr: PRStatus, token: String) async throws -> PRStatus {
    let prURL = URL(string: "\(baseURL)/repos/\(pr.repo)/pulls/\(pr.number)")!
    var prRequest = URLRequest(url: prURL)
    prRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    prRequest.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

    let (prData, _) = try await URLSession.shared.data(for: prRequest)
    let prDetail = try JSONDecoder().decode(PRDetail.self, from: prData)
    let sha = prDetail.head.sha

    let checksURL = URL(
      string: "\(baseURL)/repos/\(pr.repo)/commits/\(sha)/check-runs?per_page=100")!
    var checksRequest = URLRequest(url: checksURL)
    checksRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    checksRequest.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

    let (checksData, _) = try await URLSession.shared.data(for: checksRequest)
    let checksResult = try JSONDecoder().decode(CheckRunsResult.self, from: checksData)

    let jobs = checksResult.checkRuns.map { run in
      let state: CheckState =
        switch run.conclusion {
        case "success": .success
        case "failure", "timed_out", "cancelled", "action_required": .failure
        case "skipped", "neutral": .skipped
        default: run.status == "completed" ? .skipped : .pending
        }
      return JobStatus(
        id: run.id, name: run.name, state: state, url: run.htmlUrl.flatMap(URL.init))
    }

    var updated = pr
    updated.jobs = jobs
    return updated
  }

  // MARK: - API Response Models

  private struct SearchResult: Decodable {
    let items: [SearchItem]
  }

  private struct SearchItem: Decodable {
    let id: Int
    let title: String
    let number: Int
    let htmlUrl: String
    let repositoryUrl: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
      case id, title, number
      case htmlUrl = "html_url"
      case repositoryUrl = "repository_url"
      case createdAt = "created_at"
    }
  }

  private struct PRDetail: Decodable {
    let head: Head
    struct Head: Decodable { let sha: String }
  }

  private struct CheckRunsResult: Decodable {
    let checkRuns: [CheckRun]

    enum CodingKeys: String, CodingKey {
      case checkRuns = "check_runs"
    }
  }

  private struct CheckRun: Decodable {
    let id: Int
    let name: String
    let status: String
    let conclusion: String?
    let htmlUrl: String?

    enum CodingKeys: String, CodingKey {
      case id, name, status, conclusion
      case htmlUrl = "html_url"
    }
  }
}
