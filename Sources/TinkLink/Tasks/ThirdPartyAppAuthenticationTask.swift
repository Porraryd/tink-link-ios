import Foundation
#if os(iOS)
    import UIKit
#endif

/// A task that handles opening third party apps.
///
/// This task is provided when an `AddCredentialTask`'s status changes to `awaitingThirdPartyAppAuthentication`.
///
/// When a credential's status is `awaitingThirdPartyAppAuthentication` the user needs to authenticate in a third party app to finish adding the credential.
///
/// - Note: If the app couldn't be opened you need to handle the `AddCredentialTask` completion result and check for a `ThirdPartyAppAuthenticationTask.Error`.
/// This error can tell you if the user needs to download the app.
public class ThirdPartyAppAuthenticationTask: Identifiable {
    /// Error associated with the `ThirdPartyAppAuthenticationTask`.
    public enum Error: Swift.Error, LocalizedError {
        /// The `ThirdPartyAppAuthenticationTask` have no deep link URL.
        case deeplinkURLNotFound
        /// The `UIApplication` could not open the application. It is most likely missing and needs to be downloaded.
        case downloadRequired(title: String, message: String, appStoreURL: URL?)

        public var errorDescription: String? {
            switch self {
            case .deeplinkURLNotFound:
                return nil
            case .downloadRequired(let title, _, _):
                return title
            }
        }

        public var failureReason: String? {
            switch self {
            case .deeplinkURLNotFound:
                return nil
            case .downloadRequired(_, let message, _):
                return message
            }
        }

        public var appStoreURL: URL? {
            switch self {
            case .deeplinkURLNotFound:
                return nil
            case .downloadRequired(_, _, let url):
                return url
            }
        }
    }

    /// Information about how to open or download the third party application app.
    public private(set) var thirdPartyAppAuthentication: Credential.ThirdPartyAppAuthentication

    private let completionHandler: (Result<Void, Swift.Error>) -> Void

    init(thirdPartyAppAuthentication: Credential.ThirdPartyAppAuthentication, completionHandler: @escaping (Result<Void, Swift.Error>) -> Void) {
        self.thirdPartyAppAuthentication = thirdPartyAppAuthentication
        self.completionHandler = completionHandler
    }

    // MARK: - Opening an App

    #if os(iOS)
        /// Tries to open the third party app.
        ///
        /// - Parameter application: The object that controls and coordinates your app. Defaults to the shared instance.
        public func openThirdPartyApp(with application: UIApplication = .shared) {
            guard let url = thirdPartyAppAuthentication.deepLinkURL else {
                completionHandler(.failure(Error.deeplinkURLNotFound))
                return
            }

            let downloadRequiredError = Error.downloadRequired(
                title: thirdPartyAppAuthentication.downloadTitle,
                message: thirdPartyAppAuthentication.downloadMessage,
                appStoreURL: thirdPartyAppAuthentication.appStoreURL
            )

            DispatchQueue.main.async {
                application.open(url, options: [.universalLinksOnly: NSNumber(value: true)]) { didOpenUniversalLink in
                    if didOpenUniversalLink {
                        self.completionHandler(.success(()))
                    } else {
                        application.open(url, options: [:], completionHandler: { didOpen in
                            if didOpen {
                                self.completionHandler(.success(()))
                            } else {
                                self.completionHandler(.failure(downloadRequiredError))
                            }
                        })
                    }
                }
            }
        }
    #endif

    // MARK: - Controlling the Task

    /// Tells the task to stop waiting for third party app authentication.
    ///
    /// Call this method if you have a UI that lets the user choose to open the third party app and the user cancels.
    public func cancel() {
        completionHandler(.failure(CocoaError(.userCancelled)))
    }
}
