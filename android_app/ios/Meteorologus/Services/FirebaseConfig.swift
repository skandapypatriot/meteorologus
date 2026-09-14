import Foundation

/// Firebase project configuration.
///
/// Values mirror `android_app/lib/config/firebase_options.dart`. The app talks to
/// Firebase through its public REST APIs, so no `GoogleService-Info.plist` is needed.
enum FirebaseConfig {
    static let apiKey = "AIzaSyDwj9XVfQ5UNBbeVEbPc6JXfVmiASvlxVk"
    static let databaseURL = "https://weather-monitor-f4248-default-rtdb.asia-southeast1.firebasedatabase.app"
    static let projectID = "weather-monitor-f4248"

    static let identityToolkitURL = "https://identitytoolkit.googleapis.com/v1"
}