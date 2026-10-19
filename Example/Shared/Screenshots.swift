import Foundation
import SwiftUI
import WikipediaKit
import WikipediaUI

/// Scenes used by CI to capture the README screenshots on an iPad simulator and on the Mac.
/// Launch with `-screenshot <scene>`; normal launches are unaffected.
///
/// Every scene loads real data from the live Wikipedia REST and Action APIs on en.wikipedia.org
/// and real images from upload.wikimedia.org. Nothing is bundled or faked; if a request or an
/// image fails, the scene never reports ready and CI fails.
enum ScreenshotScene: String, CaseIterable, Sendable {
    /// iPad and Mac: the Today page of a fixed day: featured article, picture of the day, most
    /// read and on this day.
    case today
    /// iPad: the summary of Apollo 11 with its lead image and related articles.
    case article
    /// Mac: a full-text search with each result's description and thumbnail.
    case search

    static var current: ScreenshotScene? {
        guard var name = argument(after: "-screenshot") else { return nil }
        for prefix in ["ipad-", "mac-"] where name.hasPrefix(prefix) {
            name.removeFirst(prefix.count)
        }
        return ScreenshotScene(rawValue: name)
    }

    /// The day the `today` scene shows. A fixed past day, so the featured article, the picture
    /// of the day and the most-read list are the same on every run.
    static let featuredDate = WikiFeedDate(year: 2026, month: 10, day: 1)
    /// The article the `article` scene opens.
    static let articleTitle = "Apollo 11"
    /// The text the `search` scene searches for.
    static let searchText = "Moon landing"

    /// Where to write the ready marker: `-screenshot-ready-file <path>` (the Mac script passes
    /// one), or `tmp/screenshot-ready` in the app's container (what the iPad script watches).
    static var readyMarkerURL: URL {
        if let path = argument(after: "-screenshot-ready-file") {
            return URL(fileURLWithPath: path)
        }
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("screenshot-ready")
    }

    static func argument(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    /// The image loader for the screenshot scenes: the client (with its User-Agent), retried a
    /// few times, and counted so the scene is only reported ready once every image on screen has
    /// loaded.
    static func imageLoader(client: WikipediaClient) -> WikiImageLoader {
        let base = WikiImageLoader.client(client)
        return WikiImageLoader { url in
            await ScreenshotImageTracker.shared.begin()
            var lastError: any Error = URLError(.unknown)
            for attempt in 0..<4 {
                if attempt > 0 {
                    try? await Task.sleep(for: .seconds(Double(attempt) * 2))
                }
                if Task.isCancelled { break }
                do {
                    let data = try await base.data(for: url)
                    await ScreenshotImageTracker.shared.end(failed: false)
                    return data
                } catch {
                    lastError = error
                    print("Screenshot image \(url) failed (attempt \(attempt + 1)): \(error)")
                }
            }
            // A view that went away cancels its load; that is not a failure.
            await ScreenshotImageTracker.shared.end(failed: !Task.isCancelled)
            throw lastError
        }
    }
}

/// Counts the image loads of a screenshot scene.
actor ScreenshotImageTracker {
    static let shared = ScreenshotImageTracker()

    struct Snapshot: Sendable {
        var started = 0
        var inFlight = 0
        var failed = 0
        var lastChange = Date()
    }

    private var state = Snapshot()

    func begin() {
        state.started += 1
        state.inFlight += 1
        state.lastChange = Date()
    }

    func end(failed: Bool) {
        state.inFlight -= 1
        if failed { state.failed += 1 }
        state.lastChange = Date()
    }

    func snapshot() -> Snapshot {
        state
    }

    /// Waits until no image load started or finished for `quiet` seconds and at least
    /// `minimumImages` images have loaded. Returns false, and the scene is never reported ready,
    /// when an image failed to load.
    static func waitUntilSettled(minimumImages: Int, quiet: TimeInterval = 3) async -> Bool {
        while !Task.isCancelled {
            let state = await shared.snapshot()
            if state.failed > 0 {
                print("Screenshot scene: \(state.failed) image(s) failed to load; not marking it ready")
                return false
            }
            if state.started - state.inFlight >= minimumImages,
               state.inFlight == 0,
               Date().timeIntervalSince(state.lastChange) >= quiet {
                return true
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return false
    }
}

/// Called once a screenshot scene is on screen with its images, on the Mac to capture the window.
@MainActor
enum ScreenshotReadiness {
    static var onReady: (@MainActor (ScreenshotScene) -> Void)?
}

extension View {
    /// Tells the screenshot scripts that the scene is on screen by writing the ready marker, once
    /// `isReady` is true (the data has loaded) and at least `minimumImages` images have loaded.
    /// Nothing is written when loading fails, so CI fails instead of committing a broken capture.
    func signalsScreenshotReady(_ scene: ScreenshotScene?, when isReady: Bool, minimumImages: Int = 1) -> some View {
        task(id: isReady) {
            guard let scene, isReady, ScreenshotScene.current == scene else { return }
            // Give the views a moment to start loading their images.
            try? await Task.sleep(for: .seconds(1.5))
            guard await ScreenshotImageTracker.waitUntilSettled(minimumImages: minimumImages), !Task.isCancelled else {
                return
            }
            do {
                try scene.rawValue.write(to: ScreenshotScene.readyMarkerURL, atomically: true, encoding: .utf8)
                print("Screenshot scene \(scene.rawValue) is ready")
            } catch {
                print("Could not write the ready marker: \(error)")
            }
            await MainActor.run {
                ScreenshotReadiness.onReady?(scene)
            }
        }
    }
}
