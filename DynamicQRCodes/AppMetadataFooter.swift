import Foundation
import SwiftUI

struct AppMetadataFooter: View {
    private let version: String
    private let build: String
    private let currentBuildDate: Date

    init(
        bundle: Bundle = .main,
        userDefaults: UserDefaults = .standard,
        now: Date = .now
    ) {
        version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        currentBuildDate = CurrentBuildStore.date(
            version: version,
            build: build,
            userDefaults: userDefaults,
            now: now
        )
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("Version \(version) • Build \(build)")
            Text("Updated: \(currentBuildDate.formatted(date: .abbreviated, time: .shortened))")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }
}

enum CurrentBuildStore {
    private static let buildIdentifierKey = "currentBuildIdentifier"
    private static let timestampKey = "currentBuildFirstLaunchTimestamp"
    private static let legacyTimestampKey = "firstLaunchTimestamp"

    static func date(
        version: String,
        build: String,
        userDefaults: UserDefaults = .standard,
        now: Date = .now
    ) -> Date {
        let buildIdentifier = "\(version)|\(build)"

        if userDefaults.string(forKey: buildIdentifierKey) == buildIdentifier,
           userDefaults.object(forKey: timestampKey) != nil {
            return Date(timeIntervalSince1970: userDefaults.double(forKey: timestampKey))
        }

        userDefaults.set(buildIdentifier, forKey: buildIdentifierKey)
        userDefaults.set(now.timeIntervalSince1970, forKey: timestampKey)
        userDefaults.removeObject(forKey: legacyTimestampKey)
        return now
    }
}
