import TinkLink
import UIKit

/// Example of how to use the provider grouped by credential type
final class CredentialKindPickerViewController: UITableViewController {
    typealias CompletionHandler = (Result<Credential, Error>) -> Void
    var onCompletion: CompletionHandler?
    var credentialKindNodes: [ProviderTree.CredentialKindNode] = []
    
    private let credentialContext: CredentialContext

    init(credentialContext: CredentialContext) {
        self.credentialContext = credentialContext

        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - View Lifecycle

extension CredentialKindPickerViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.prompt = "Choose Credential Type"
        navigationItem.title = credentialKindNodes.first?.provider.displayName
        navigationItem.largeTitleDisplayMode = .never

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }
}

// MARK: - UITableViewDataSource

extension CredentialKindPickerViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return credentialKindNodes.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = credentialKindNodes[indexPath.row].displayDescription
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let credentialKindNode = credentialKindNodes[indexPath.row]
        showAddCredential(for: credentialKindNode.provider)
    }
}

// MARK: - Navigation

extension CredentialKindPickerViewController {
    func showAddCredential(for provider: Provider) {
        let addCredentialViewController = AddCredentialViewController(provider: provider, credentialContext: credentialContext)
        addCredentialViewController.onCompletion = onCompletion
        show(addCredentialViewController, sender: nil)
    }
}
