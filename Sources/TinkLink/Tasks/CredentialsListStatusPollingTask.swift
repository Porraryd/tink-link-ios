import Foundation
import GRPC

class CredentialsListStatusPollingTask {
    private var service: CredentialService
    var callRetryCancellable: RetryCancellable?
    private var retryInterval: TimeInterval = 1
    private(set) var credentialsToUpdate: [Credential]
    private(set) var updatedCredentials: [Credential] = []
    private var updateHandler: (Result<Credential, Error>) -> Void
    private var completion: (Result<[Credential], Error>) -> Void
    private let backoffStrategy: PollingBackoffStrategy
    private var hasPaused = false

    enum PollingBackoffStrategy {
        case none
        case linear
        case exponential

        func nextInterval(for retryinterval: TimeInterval) -> TimeInterval {
            switch self {
            case .none:
                return retryinterval
            case .linear:
                return retryinterval + 1
            case .exponential:
                return retryinterval * 2
            }
        }
    }

    init(credentialService: CredentialService, credentials: [Credential], backoffStrategy: PollingBackoffStrategy = .linear, updateHandler: @escaping (Result<Credential, Error>) -> Void, completion: @escaping (Result<[Credential], Error>) -> Void) {
        self.service = credentialService
        self.credentialsToUpdate = credentials
        self.backoffStrategy = backoffStrategy
        self.updateHandler = updateHandler
        self.completion = completion
    }

    func pausePolling() {
        retryInterval = 1
        hasPaused = true
    }

    func continuePolling() {
        hasPaused = false
        pollStatus()
    }

    func pollStatus() {
        // Check the ablility for update the credential, if not, call update handler immediately.
        // Remove the credentials that cannot be updated from the updating list.
        credentialsToUpdate = credentialsToUpdate.filter {
            let updatable = $0.isManuallyUpdatable
            if !updatable {
                updateHandler(.success($0))
            }
            return updatable
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + retryInterval) {
            self.callRetryCancellable = self.service.credentials { [weak self] result in
                guard let self = self else { return }
                do {
                    let credentials = try result.get()
                    self.credentialsToUpdate = self.checkCredentialsToUpdate(credentials)

                    if self.credentialsToUpdate.isEmpty {
                        self.completion(.success(self.updatedCredentials))
                    } else {
                        guard !self.hasPaused else { return }
                        self.retry()
                    }
                } catch {
                    self.completion(.failure(error))
                }
            }
        }
    }

    private func checkCredentialsToUpdate(_ fetchedCredentials: [Credential]) -> [Credential] {
        // Remove the credentials that have been updated
        return credentialsToUpdate.filter { credential -> Bool in
            if let updatedCredential = fetchedCredentials.first(where: { $0.id == credential.id }) {
                if credential.statusUpdated != updatedCredential.statusUpdated || credential.status != updatedCredential.status {
                    switch updatedCredential.status {
                    // When status is updated, or changed to error, move the credential to updated credential list
                    case .updated, .permanentError, .temporaryError, .authenticationError, .unknown, .disabled, .sessionExpired:
                        updateHandler(.success(updatedCredential))
                        updatedCredentials.append(updatedCredential)
                        return false
                    // Status has changed, but not finished updating.
                    default:
                        updateHandler(.success(updatedCredential))
                        return true
                    }
                }
                return true
            } else {
                fatalError("No such credential with " + credential.id.value)
            }
        }
    }

    private func retry() {
        DispatchQueue.main.asyncAfter(deadline: .now() + retryInterval) { [weak self] in
            self?.callRetryCancellable?.retry()
        }
        retryInterval = backoffStrategy.nextInterval(for: retryInterval)
    }
}
