import SwiftUI

struct PopoverView: View {
  @Bindable var viewModel: StatusViewModel
  var onToggleFloatingWindow: () -> Void
  @State private var showSettings = false
  @State private var tokenInput = ""

  var body: some View {
    VStack(spacing: 0) {
      if viewModel.prStatuses.isEmpty && !viewModel.isLoading {
        ContentUnavailableView(
          viewModel.token.isEmpty ? "No Token" : "No Open PRs",
          systemImage: viewModel.token.isEmpty ? "key" : "checkmark.seal",
          description: Text(
            viewModel.token.isEmpty
              ? "Add your GitHub token in settings"
              : "You have no open pull requests"
          )
        )
        .frame(height: 200)
      } else {
        List {
          ForEach(groupedByOrg, id: \.org) { group in
            Section(group.org) {
              ForEach(group.prs) { pr in
                PRStatusRow(pr: pr)
              }
            }
          }
        }
        .frame(minHeight: 200, maxHeight: 400)
      }

      Divider()

      HStack {
        if let date = viewModel.lastUpdated {
          Text("Updated \(date, style: .relative) ago")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        if viewModel.isLoading {
          ProgressView().controlSize(.small)
        }
        Button("Refresh") { viewModel.refresh() }
          .buttonStyle(.borderless)
          .disabled(viewModel.isLoading || viewModel.token.isEmpty)
      }
      .padding(8)

      if let error = viewModel.errorMessage {
        Text(error)
          .font(.caption)
          .foregroundStyle(.red)
          .padding(.horizontal, 8)
          .padding(.bottom, 4)
      }

      Divider()

      VStack(alignment: .leading, spacing: 0) {
        Button {
          showSettings.toggle()
        } label: {
          HStack {
            Text("Settings")
            Spacer()
            Image(systemName: "chevron.right")
              .rotationEffect(.degrees(showSettings ? 90 : 0))
              .font(.caption)
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)

        if showSettings {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              SecureField("GitHub Token", text: $tokenInput)
                .textFieldStyle(.roundedBorder)
              Button("Save") {
                viewModel.token = tokenInput
                viewModel.refresh()
              }
            }

            Picker("Poll every", selection: $viewModel.pollingInterval) {
              Text("30s").tag(30.0)
              Text("1min").tag(60.0)
              Text("10min").tag(600.0)
              Text("30min").tag(1800.0)
              Text("1h").tag(3600.0)
            }

            Toggle("Floating window", isOn: $viewModel.showFloatingWindow)
              .onChange(of: viewModel.showFloatingWindow) { _, _ in
                onToggleFloatingWindow()
              }
          }
          .padding(.top, 8)
        }
      }
      .padding(8)

      Divider()

      Button("Quit Kanshi") { NSApplication.shared.terminate(nil) }
        .buttonStyle(.borderless)
        .foregroundStyle(.red)
        .padding(8)
    }
    .frame(width: 340)
    .onAppear { tokenInput = viewModel.token }
  }

  private var groupedByOrg: [(org: String, prs: [PRStatus])] {
    let grouped = Dictionary(grouping: viewModel.prStatuses, by: \.org)
    return grouped.keys.sorted().map { org in
      (org: org, prs: grouped[org]!)
    }
  }
}

struct PRStatusRow: View {
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
        VStack(alignment: .leading) {
          Text(pr.repo.split(separator: "/").last.map(String.init) ?? pr.repo)
            .font(.caption).foregroundStyle(.secondary)
          Text(pr.title).lineLimit(1)
        }
        Spacer()
        Link(destination: pr.url) {
          Image(systemName: "arrow.up.right.square")
        }
        .buttonStyle(.borderless)
      }

      if expanded {
        ForEach(pr.jobs) { job in
          HStack {
            stateIcon(job.state)
            if let url = job.url {
              Link(job.name, destination: url).font(.caption)
            } else {
              Text(job.name).font(.caption)
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
