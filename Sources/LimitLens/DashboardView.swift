import AppKit
import LimitLensCore
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: LocalUsageStore
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            header

            VStack(spacing: 10) {
                ForEach(store.snapshots) { snapshot in
                    ProviderCardView(snapshot: snapshot)
                }
            }

            footer
        }
        .padding(16)
    }

    private var header: some View {
        HStack(spacing: 10) {
            statusDot

            VStack(alignment: .leading, spacing: 1) {
                Text("LimitLens")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            HStack(spacing: 6) {
                iconButton("arrow.clockwise", accessibilityLabel: "Actualiser") {
                    Task { await store.refresh() }
                }
                .rotationEffect(.degrees(store.isRefreshing ? 360 : 0))
                .animation(store.isRefreshing ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default, value: store.isRefreshing)

                iconButton("gearshape", accessibilityLabel: "Réglages", action: onOpenSettings)

                iconButton("power", accessibilityLabel: "Quitter") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(globalHealth.color)
            .frame(width: 12, height: 12)
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.55), lineWidth: 1)
            }
            .shadow(color: globalHealth.color.opacity(0.45), radius: 8, y: 1)
    }

    private var subtitle: String {
        if store.isRefreshing {
            return "Mise à jour..."
        }
        if let lastRefresh = store.lastRefresh {
            return "Vu à \(MetricFormatter.shortTime(lastRefresh))"
        }
        return "Claude Code + Codex"
    }

    private var globalHealth: CLIUsageHealth {
        store.snapshots.map(\.health).max { $0.severity < $1.severity } ?? .unavailable
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "externaldrive")
                .font(.system(size: 11, weight: .semibold))
            Text("Lecture locale + OAuth Claude Code")
                .font(.system(size: 11, weight: .medium, design: .rounded))
            Spacer()
            Text(store.refreshInterval.shortLabel)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.secondary)
    }

    private func iconButton(_ systemName: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.12))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}
