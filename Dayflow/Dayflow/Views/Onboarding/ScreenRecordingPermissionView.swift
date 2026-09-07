//
//  ScreenRecordingPermissionView.swift
//  Dayflow
//

import AppKit
import CoreGraphics
import ScreenCaptureKit
import SwiftUI

struct ScreenRecordingPermissionView: View {
  var onBack: () -> Void
  var onNext: () -> Void

  @State private var phase: Phase = .ready
  @State private var didAdvance = false

  private enum Phase {
    case ready
    case requesting
    case granted
    case deferred
  }

  private let brownAccent = Color(hex: "492304")
  private let privacyTextColor = Color(hex: "89380E")

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      VStack(alignment: .leading, spacing: 12) {
        Text("Almost there")
          .font(.custom("Figtree-Bold", size: 16))
          .foregroundColor(Color(hex: "F96E00"))

        Text("Screen Recording")
          .font(.custom("InstrumentSerif-Regular", size: 32))
          .foregroundColor(.black)

        Text("PIP takes screenshots on this Mac so it can build your timeline. Nothing is uploaded.")
          .font(.custom("Figtree-Medium", size: 15))
          .foregroundColor(Color(hex: "5B5B5B"))
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: 520, alignment: .leading)

        VStack(alignment: .leading, spacing: 10) {
          HStack(alignment: .top, spacing: 8) {
            Image(systemName: "shield.fill")
              .font(.system(size: 14))
              .foregroundColor(privacyTextColor)
            Text("Local only. Qwen 3.5 reads frames here. Agents get a briefing, never the video.")
              .font(.custom("Figtree-Medium", size: 14))
              .foregroundColor(privacyTextColor)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .padding(16)
        .frame(maxWidth: 520, alignment: .leading)
        .background(Color.white.opacity(0.3))
        .cornerRadius(5)
        .overlay(
          RoundedRectangle(cornerRadius: 5)
            .stroke(Color(red: 0.8, green: 0.278, blue: 0).opacity(0.15), lineWidth: 1)
        )

        statusText
        actionButtons
        Spacer()
      }
      .frame(maxWidth: 560, alignment: .leading)

      HStack(spacing: 15) {
        DayflowSurfaceButton(
          action: onBack,
          content: { Text("Back").font(.custom("Figtree-Medium", size: 12)).tracking(-0.48) },
          background: .white,
          foreground: Color(hex: "B6B6B6"),
          borderColor: Color(hex: "B6B6B6"),
          cornerRadius: 4,
          horizontalPadding: 40,
          verticalPadding: 12,
          isSecondaryStyle: true
        )
        DayflowSurfaceButton(
          action: advanceOnce,
          content: {
            Text("Continue")
              .font(.custom("Figtree-Medium", size: 12))
              .tracking(-0.48)
          },
          background: Color(hex: "402B00"),
          foreground: .white,
          borderColor: .clear,
          cornerRadius: 4,
          horizontalPadding: 40,
          verticalPadding: 12,
          showOverlayStroke: true
        )
      }
    }
    .padding(.leading, 105)
    .padding(.trailing, 60)
    .padding(.top, 40)
    .padding(.bottom, 40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear {
      Task { @MainActor in AppDelegate.allowTermination = true }
      if ScreenRecordingPermissionNotice.isGranted {
        phase = .granted
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    { _ in
      if ScreenRecordingPermissionNotice.isGranted {
        phase = .granted
      }
    }
    .onDisappear {
      Task { @MainActor in AppDelegate.allowTermination = false }
    }
  }

  @ViewBuilder
  private var statusText: some View {
    switch phase {
    case .ready:
      EmptyView()
    case .requesting:
      Text("macOS should show a permission dialog. Click Allow.")
        .font(.custom("Figtree", size: 14))
        .foregroundColor(Color(hex: "5B5B5B"))
    case .granted:
      Text("Screen Recording is on. Continue.")
        .font(.custom("Figtree", size: 14))
        .foregroundColor(.green)
    case .deferred:
      Text("You can continue and allow this later. Timeline cards need it.")
        .font(.custom("Figtree", size: 14))
        .foregroundColor(.orange)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  @ViewBuilder
  private var actionButtons: some View {
    switch phase {
    case .ready, .deferred:
      Button(action: requestPermission) {
        Text("Allow Screen Recording")
          .font(.custom("Figtree-SemiBold", size: 12))
          .tracking(-0.48)
          .foregroundColor(brownAccent)
          .padding(12)
      }
      .buttonStyle(.plain)
      .background(actionBackground)
      .cornerRadius(6)
      .overlay(
        RoundedRectangle(cornerRadius: 6)
          .stroke(Color(hex: "FFBC80"), lineWidth: 1)
      )
    case .requesting:
      HStack(spacing: 8) {
        ProgressView()
          .scaleEffect(0.7)
          .progressViewStyle(CircularProgressViewStyle())
        Text("Waiting for macOS…")
          .font(.custom("Figtree-SemiBold", size: 12))
          .foregroundColor(brownAccent)
      }
      .padding(12)
    case .granted:
      EmptyView()
    }
  }

  private var actionBackground: some View {
    LinearGradient(
      stops: [
        .init(
          color: Color(red: 1, green: 0.773, blue: 0.341).opacity(0.7), location: 0.73),
        .init(
          color: Color(red: 1, green: 0.98, blue: 0.945).opacity(0), location: 0.99),
      ],
      startPoint: UnitPoint(x: 0.7, y: 1),
      endPoint: UnitPoint(x: 0.3, y: 0)
    )
    .background(Color.white.opacity(0.69))
  }

  private func requestPermission() {
    guard phase != .requesting else { return }
    phase = .requesting
    AnalyticsService.shared.capture("screen_permission_requested")

    Task {
      let granted = await probeScreenCapture(timeoutSeconds: 12)
      await MainActor.run {
        if granted || ScreenRecordingPermissionNotice.isGranted {
          phase = .granted
          AnalyticsService.shared.capture("screen_permission_granted")
        } else {
          phase = .deferred
          AnalyticsService.shared.capture("screen_permission_deferred")
        }
      }
    }
  }

  private func probeScreenCapture(timeoutSeconds: Double) async -> Bool {
    await withTaskGroup(of: Bool.self) { group in
      group.addTask {
        do {
          _ = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
          )
          return true
        } catch {
          return CGPreflightScreenCaptureAccess()
        }
      }
      group.addTask {
        let nanos = UInt64(timeoutSeconds * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanos)
        return false
      }
      let first = await group.next() ?? false
      group.cancelAll()
      return first
    }
  }

  private func advanceOnce() {
    guard !didAdvance else { return }
    didAdvance = true
    onNext()
  }
}
