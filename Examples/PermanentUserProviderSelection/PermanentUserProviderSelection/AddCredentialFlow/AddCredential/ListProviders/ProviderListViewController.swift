import TinkLink
import UIKit

/// Example of how to use the provider grouped by names
final class ProviderListViewController: UITableViewController {
    typealias CompletionHandler = (Result<Credential, Error>) -> Void
    var onCompletion: CompletionHandler?

    private let searchController = UISearchController(searchResultsController: nil)
    private var providers: [Provider]
    private var credentialContext: CredentialContext
    private var originalFinancialInstitutionGroupNodes: [ProviderTree.FinancialInstitutionGroupNode]
    private var financialInstitutionGroupNodes: [ProviderTree.FinancialInstitutionGroupNode] {
        didSet {
            self.tableView.reloadData()
        }
    }

    init(providers: [Provider], credentialContext: CredentialContext, style: UITableView.Style) {
        self.providers = providers
        self.credentialContext = credentialContext
        self.financialInstitutionGroupNodes = ProviderTree(providers: providers).financialInstitutionGroups
        self.originalFinancialInstitutionGroupNodes = ProviderTree(providers: providers).financialInstitutionGroups
        super.init(style: style)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - View Lifecycle

extension ProviderListViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search"
        searchController.searchResultsUpdater = self

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        definesPresentationContext = true

        title = "Choose Bank"

        tableView.register(FixedImageSizeTableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(TextFieldCell.self, forCellReuseIdentifier: TextFieldCell.reuseIdentifier)

        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource

extension ProviderListViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return financialInstitutionGroupNodes.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let node = financialInstitutionGroupNodes[indexPath.row]
        if let imageTableViewCell = cell as? FixedImageSizeTableViewCell {
            if let url = node.imageURL {
                imageTableViewCell.setImage(url: url)
            }
            imageTableViewCell.setTitle(text: node.displayName)
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let financialInstitutionGroupNode = financialInstitutionGroupNodes[indexPath.row]
        switch financialInstitutionGroupNode {
        case .financialInstitutions(let financialInstitutionGroups):
            showFinancialInstitution(for: financialInstitutionGroups, title: financialInstitutionGroupNode.displayName)
        case .accessTypes(let accessTypeGroups):
            showAccessTypePicker(for: accessTypeGroups, title: financialInstitutionGroupNode.displayName)
        case .credentialKinds(let groups):
            showCredentialKindPicker(for: groups)
        case .provider(let provider):
            showAddCredential(for: provider)
        }
    }
}

// MARK: - Navigation

extension ProviderListViewController {
    func showFinancialInstitution(for financialInstitutionNodes: [ProviderTree.FinancialInstitutionNode], title: String?) {
        let viewController = FinancialInstitutionPickerViewController(credentialContext: credentialContext)
        viewController.onCompletion = onCompletion
        viewController.title = title
        viewController.financialInstitutionNodes = financialInstitutionNodes
        show(viewController, sender: nil)
    }

    func showAccessTypePicker(for accessTypeNodes: [ProviderTree.AccessTypeNode], title: String?) {
        let viewController = AccessTypePickerViewController(credentialContext: credentialContext)
        viewController.onCompletion = onCompletion
        viewController.title = title
        viewController.accessTypeNodes = accessTypeNodes
        show(viewController, sender: nil)
    }

    func showCredentialKindPicker(for credentialKindNodes: [ProviderTree.CredentialKindNode]) {
        let viewController = CredentialKindPickerViewController(credentialContext: credentialContext)
        viewController.onCompletion = onCompletion
        viewController.credentialKindNodes = credentialKindNodes
        show(viewController, sender: nil)
    }

    func showAddCredential(for provider: Provider) {
        let addCredentialViewController = AddCredentialViewController(provider: provider, credentialContext: credentialContext)
        addCredentialViewController.onCompletion = onCompletion
        show(addCredentialViewController, sender: nil)
    }
}

// MARK: - UISearchResultsUpdating

extension ProviderListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        if let text = searchController.searchBar.text, !text.isEmpty {
            financialInstitutionGroupNodes = originalFinancialInstitutionGroupNodes.filter { $0.displayName.localizedCaseInsensitiveContains(text) }
        } else {
            financialInstitutionGroupNodes = originalFinancialInstitutionGroupNodes
        }
    }
}
