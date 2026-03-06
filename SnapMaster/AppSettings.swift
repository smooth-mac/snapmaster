import AppKit
import ServiceManagement

// MARK: - AppSettings

/// A type-safe, UserDefaults-backed store for all SnapMaster user preferences.
///
/// All keys are prefixed with `"snapmaster."` to avoid collisions with other
/// frameworks or future system keys. Call `AppSettings.shared` from any thread;
/// `UserDefaults` itself is thread-safe for individual reads and writes.
///
/// Design contract:
/// - Setters write to `UserDefaults.standard` immediately.
/// - Consumers that need live updates (e.g. `SnapZoneDetector`) should read
///   from `AppSettings.shared` at the point of use rather than caching values.
final class AppSettings {

    // MARK: - Singleton

    static let shared = AppSettings()

    // MARK: - UserDefaults Keys

    private enum Key {
        static let edgeThreshold    = "snapmaster.edgeThreshold"
        static let cornerThreshold  = "snapmaster.cornerThreshold"
        static let overlayOpacity   = "snapmaster.overlayOpacity"
        static let excludedBundleIDs = "snapmaster.excludedBundleIDs"
        static let launchAtLogin    = "snapmaster.launchAtLogin"
    }

    // MARK: - Default Values

    private enum Default {
        static let edgeThreshold:   CGFloat = 24
        static let cornerThreshold: CGFloat = 120
        static let overlayOpacity:  Double  = 0.25
    }

    // MARK: - Valid Ranges

    enum Range {
        static let edgeThreshold:   ClosedRange<CGFloat> = 8...64
        static let cornerThreshold: ClosedRange<CGFloat> = 60...240
        static let overlayOpacity:  ClosedRange<Double>  = 0.1...0.6
    }

    // MARK: - Init

    private init() {
        registerDefaults()
    }

    // MARK: - Snap Sensitivity

    /// Distance in pixels from a screen edge that triggers a snap zone.
    /// Clamped to `Range.edgeThreshold` (8–64 px). Default: 24 px.
    var edgeThreshold: CGFloat {
        get {
            let stored = CGFloat(UserDefaults.standard.double(forKey: Key.edgeThreshold))
            return stored.clamped(to: Range.edgeThreshold)
        }
        set {
            UserDefaults.standard.set(
                Double(newValue.clamped(to: Range.edgeThreshold)),
                forKey: Key.edgeThreshold
            )
        }
    }

    /// Distance in pixels from a screen corner that triggers a diagonal zone.
    /// Clamped to `Range.cornerThreshold` (60–240 px). Default: 120 px.
    var cornerThreshold: CGFloat {
        get {
            let stored = CGFloat(UserDefaults.standard.double(forKey: Key.cornerThreshold))
            return stored.clamped(to: Range.cornerThreshold)
        }
        set {
            UserDefaults.standard.set(
                Double(newValue.clamped(to: Range.cornerThreshold)),
                forKey: Key.cornerThreshold
            )
        }
    }

    // MARK: - Overlay

    /// Alpha of the snap-zone preview overlay.
    /// Clamped to `Range.overlayOpacity` (0.1–0.6). Default: 0.25.
    var overlayOpacity: Double {
        get {
            let stored = UserDefaults.standard.double(forKey: Key.overlayOpacity)
            return stored.clamped(to: Range.overlayOpacity)
        }
        set {
            UserDefaults.standard.set(
                newValue.clamped(to: Range.overlayOpacity),
                forKey: Key.overlayOpacity
            )
        }
    }

    // MARK: - Excluded Apps

    /// Bundle identifiers of applications for which snap should be suppressed.
    /// Default: empty list.
    var excludedBundleIDs: [String] {
        get {
            return UserDefaults.standard.stringArray(forKey: Key.excludedBundleIDs) ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.excludedBundleIDs)
        }
    }

    // MARK: - Launch at Login

    /// Whether SnapMaster is registered to launch at login via `SMAppService`.
    ///
    /// Setting this to `true` calls `SMAppService.mainApp.register()`;
    /// setting it to `false` calls `unregister(completionHandler:)`.
    /// The stored UserDefaults value mirrors the service registration state
    /// so the menu bar item can reflect the correct checkmark synchronously.
    var launchAtLogin: Bool {
        get {
            return UserDefaults.standard.bool(forKey: Key.launchAtLogin)
        }
        set {
            applyLaunchAtLogin(newValue)
        }
    }

    // MARK: - Private Helpers

    /// Register factory defaults so that `UserDefaults.double(forKey:)` returns
    /// the intended value on first launch (before any explicit write).
    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.edgeThreshold:    Double(Default.edgeThreshold),
            Key.cornerThreshold:  Double(Default.cornerThreshold),
            Key.overlayOpacity:   Default.overlayOpacity,
            Key.excludedBundleIDs: [String](),
            Key.launchAtLogin:    false,
        ])
    }

    /// Applies the `SMAppService` registration state change and, on success,
    /// persists it to UserDefaults. On failure the stored value is left
    /// unchanged so the menu checkmark stays consistent with system state.
    private func applyLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            UserDefaults.standard.set(enabled, forKey: Key.launchAtLogin)
        } catch {
            print("[AppSettings] Launch-at-login toggle failed: \(error.localizedDescription)")
        }
    }

    // MARK: - State Sync

    /// Reads the actual `SMAppService` registration state and aligns the
    /// stored `launchAtLogin` value with it. Call this once at launch.
    func syncLaunchAtLoginState() {
        let isRegistered = SMAppService.mainApp.status == .enabled
        // Write directly to UserDefaults to avoid triggering another
        // SMAppService call (which applyLaunchAtLogin would do).
        UserDefaults.standard.set(isRegistered, forKey: Key.launchAtLogin)
    }
}

// MARK: - Comparable+clamped

private extension Comparable {
    /// Returns `self` clamped to the given closed range.
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
