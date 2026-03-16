import AppKit
import SwiftUI

class FloatingWindow: NSPanel {
  init(viewModel: StatusViewModel) {
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: 260, height: 400),
      styleMask: [.borderless, .nonactivatingPanel, .resizable],
      backing: .buffered,
      defer: false
    )
    level = .floating
    isOpaque = false
    backgroundColor = .clear
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    isMovableByWindowBackground = true
    setFrameAutosaveName("KanshiFloatingWindow")
    contentViewController = NSHostingController(
      rootView: FloatingWindowView(viewModel: viewModel)
    )
    center()
  }
}

struct FloatingWindowView: View {
  var viewModel: StatusViewModel

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Kanshi").font(.headline)
        Spacer()
        if viewModel.isLoading {
          ProgressView().controlSize(.small)
        }
      }
      .padding(8)

      Divider()

      if viewModel.prStatuses.isEmpty {
        Text("No open PRs")
          .foregroundStyle(.secondary)
          .frame(maxHeight: .infinity)
      } else {
        List {
          ForEach(groupedByOrg, id: \.org) { group in
            Section(group.org) {
              ForEach(group.prs) { pr in
                FloatingPRRow(pr: pr)
              }
            }
          }
        }
      }
    }
    .frame(width: 260, height: 400)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  private var groupedByOrg: [(org: String, prs: [PRStatus])] {
    let grouped = Dictionary(grouping: viewModel.prStatuses, by: \.org)
    return grouped.keys.sorted().map { org in
      (org: org, prs: grouped[org]!)
    }
  }

}

struct FloatingPRRow: View {
  let pr: PRStatus
  @State private var expanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Button {
          expanded.toggle()
        } label: {
          Image(systemName: "chevron.right")
            .rotationEffect(.degrees(expanded ? 90 : 0))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(width: 12)
        }
        .buttonStyle(.borderless)

        stateIcon(pr.overallState)
        Button {
          NSWorkspace.shared.open(pr.url)
        } label: {
          VStack(alignment: .leading) {
            Text(pr.repo.split(separator: "/").last.map(String.init) ?? pr.repo)
              .font(.caption2).foregroundStyle(.secondary)
            Text(pr.title).font(.caption).lineLimit(1)
          }
        }
        .buttonStyle(.plain)
      }

      if expanded {
        ForEach(pr.jobs) { job in
          HStack {
            stateIcon(job.state)
            if let url = job.url {
              Link(job.name, destination: url).font(.caption2).lineLimit(1)
            } else {
              Text(job.name).font(.caption2).lineLimit(1)
            }
          }
          .padding(.leading, 20)
        }
      }
    }
  }

  @ViewBuilder
  private func stateIcon(_ state: CheckState) -> some View {
    switch state {
    case .success: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
    case .failure: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
    case .pending: Image(systemName: "clock.circle.fill").foregroundStyle(.yellow)
    case .skipped: Image(systemName: "minus.circle.fill").foregroundStyle(.gray)
    }
  }
}
