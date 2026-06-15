import UIKit

/// Searchable list of all dialling countries (Create Trader phone fields).
final class CountryPickerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating {

    var onSelect: ((Country) -> Void)?

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let searchController = UISearchController(searchResultsController: nil)
    private let all = Countries.all
    private var filtered = Countries.all

    override func viewDidLoad() {
        super.viewDidLoad()
        title = S.mobileNumber
        view.backgroundColor = AppColors.surface

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(close))

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search country"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true

        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 52
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "country")
        tableView.forAutoLayout()
        view.addSubview(tableView)
        tableView.pinEdges(to: view)
    }

    @objc private func close() { dismiss(animated: true) }

    func updateSearchResults(for searchController: UISearchController) {
        let q = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespaces)
        if q.isEmpty {
            filtered = all
        } else {
            filtered = all.filter {
                $0.name.localizedCaseInsensitiveContains(q) || $0.dialCode.contains(q)
            }
        }
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { filtered.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "country", for: indexPath)
        let country = filtered[indexPath.row]
        cell.textLabel?.text = "\(country.flag)  \(country.name)"
        cell.textLabel?.font = AppFonts.regular(15)
        cell.detailTextLabel?.text = country.dialCode
        let code = UILabel.make(country.dialCode, font: AppFonts.regular(14), color: AppColors.textSecondary)
        code.sizeToFit()
        cell.accessoryView = code
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let country = filtered[indexPath.row]
        dismiss(animated: true) { [weak self] in self?.onSelect?(country) }
    }
}

/// Generic checklist used for multi-select fields (product categories, distributors).
final class MultiSelectViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let titleText: String
    private let options: [String]
    private var selected: Set<Int>
    private let onDone: (Set<Int>) -> Void
    private let tableView = UITableView(frame: .zero, style: .plain)

    init(title: String, options: [String], selected: Set<Int>, onDone: @escaping (Set<Int>) -> Void) {
        self.titleText = title
        self.options = options
        self.selected = selected
        self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = titleText
        view.backgroundColor = AppColors.surface
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(done))

        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 48
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "opt")
        tableView.forAutoLayout()
        view.addSubview(tableView)
        tableView.pinEdges(to: view)
    }

    @objc private func cancel() { dismiss(animated: true) }
    @objc private func done() { dismiss(animated: true) { [weak self] in
        guard let self = self else { return }
        self.onDone(self.selected)
    } }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { options.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "opt", for: indexPath)
        cell.textLabel?.text = options[indexPath.row]
        cell.textLabel?.font = AppFonts.regular(15)
        cell.accessoryType = selected.contains(indexPath.row) ? .checkmark : .none
        cell.tintColor = AppColors.purplePrimary
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if selected.contains(indexPath.row) { selected.remove(indexPath.row) }
        else { selected.insert(indexPath.row) }
        tableView.reloadRows(at: [indexPath], with: .none)
    }
}
