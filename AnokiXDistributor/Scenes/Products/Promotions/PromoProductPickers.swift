import UIKit

/// Searchable product chooser for the promotion wizard — single- or multi-select.
/// Mirrors the Android `buildPickerDialog` (single product / combo deal).
final class PromoProductPickerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let titleText: String
    private let hint: String
    private let catalogue: [PromoProduct]
    private let multiSelect: Bool
    private let onDone: ([PromoProduct]) -> Void

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let searchBar = SearchBarView(placeholder: "Search products…")
    private var filtered: [PromoProduct] = []
    private var selected: [PromoProduct] = []

    init(title: String, hint: String, catalogue: [PromoProduct], multiSelect: Bool,
         onDone: @escaping ([PromoProduct]) -> Void) {
        self.titleText = title
        self.hint = hint
        self.catalogue = catalogue
        self.multiSelect = multiSelect
        self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = titleText
        view.backgroundColor = AppColors.surface
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: S.promoDone, style: .done, target: self, action: #selector(done))

        let hintLabel = UILabel.make(hint, font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 0)
        hintLabel.forAutoLayout()
        searchBar.forAutoLayout()
        searchBar.onChange = { [weak self] _ in self?.applyFilter() }

        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 64
        tableView.separatorInset = .zero
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "row")
        tableView.forAutoLayout()

        view.addSubviews(hintLabel, searchBar, tableView)
        NSLayoutConstraint.activate([
            hintLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchBar.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 12),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        filtered = catalogue
    }

    @objc private func cancel() { dismiss(animated: true) }
    @objc private func done() { dismiss(animated: true) { [weak self] in
        guard let self = self else { return }
        self.onDone(self.selected)
    } }

    private func applyFilter() {
        let q = (searchBar.textField.text ?? "").trimmingCharacters(in: .whitespaces)
        filtered = q.isEmpty ? catalogue : catalogue.filter { $0.matches(q) }
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { filtered.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
        let product = filtered[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = product.name
        content.textProperties.font = AppFonts.bold(14)
        content.secondaryText = [product.sku, product.categoryTitle].filter { !$0.isEmpty }.joined(separator: " • ")
        content.secondaryTextProperties.font = AppFonts.regular(12)
        content.secondaryTextProperties.color = AppColors.textSecondary
        content.image = UIImage(systemName: "shippingbox")
        content.imageProperties.tintColor = AppColors.textTertiary
        content.imageProperties.maximumSize = CGSize(width: 28, height: 28)
        cell.contentConfiguration = content
        cell.accessoryType = selected.contains(where: { $0.id == product.id }) ? .checkmark : .none
        cell.tintColor = AppColors.purplePrimary
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let product = filtered[indexPath.row]
        if multiSelect {
            if let idx = selected.firstIndex(where: { $0.id == product.id }) { selected.remove(at: idx) }
            else { selected.append(product) }
            tableView.reloadRows(at: [indexPath], with: .none)
        } else {
            selected = [product]
            dismiss(animated: true) { [weak self] in
                guard let self = self else { return }
                self.onDone(self.selected)
            }
        }
    }
}

/// Buy1Get1 picker — a Buy/Free segmented control over the same searchable catalogue.
/// Mirrors the Android `showB1g1Picker` dialog.
final class PromoB1G1PickerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let catalogue: [PromoProduct]
    private let onDone: (_ buy: [PromoProduct], _ free: [PromoProduct]) -> Void

    private let segmented = UISegmentedControl(items: [S.promoBuyProducts, S.promoFreeProducts])
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let searchBar = SearchBarView(placeholder: "Search products…")
    private var filtered: [PromoProduct] = []
    private var buy: [PromoProduct] = []
    private var free: [PromoProduct] = []

    private var selectingFree: Bool { segmented.selectedSegmentIndex == 1 }
    private var current: [PromoProduct] { selectingFree ? free : buy }

    init(catalogue: [PromoProduct], onDone: @escaping (_ buy: [PromoProduct], _ free: [PromoProduct]) -> Void) {
        self.catalogue = catalogue
        self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Buy1Get1 Free Deal"
        view.backgroundColor = AppColors.surface
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: S.promoDone, style: .done, target: self, action: #selector(done))

        let hintLabel = UILabel.make("Switch between Buy and Free, then tap products to add them. Each deal needs at least one of each.",
                                     font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 0)
        hintLabel.forAutoLayout()
        segmented.selectedSegmentIndex = 0
        segmented.selectedSegmentTintColor = AppColors.purplePrimary
        segmented.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmented.forAutoLayout()
        searchBar.forAutoLayout()
        searchBar.onChange = { [weak self] _ in self?.applyFilter() }

        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 56
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "row")
        tableView.forAutoLayout()

        view.addSubviews(hintLabel, segmented, searchBar, tableView)
        NSLayoutConstraint.activate([
            hintLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            segmented.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 12),
            segmented.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmented.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchBar.topAnchor.constraint(equalTo: segmented.bottomAnchor, constant: 12),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        filtered = catalogue
    }

    @objc private func cancel() { dismiss(animated: true) }

    @objc private func done() {
        guard !buy.isEmpty, !free.isEmpty else {
            let alert = UIAlertController(title: nil, message: "Add at least one buy and one free product.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.onDone(self.buy, self.free)
        }
    }

    @objc private func segmentChanged() { tableView.reloadData() }

    private func applyFilter() {
        let q = (searchBar.textField.text ?? "").trimmingCharacters(in: .whitespaces)
        filtered = q.isEmpty ? catalogue : catalogue.filter { $0.matches(q) }
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { filtered.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
        let product = filtered[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = product.name
        content.textProperties.font = AppFonts.regular(14)
        content.secondaryText = product.sku
        content.secondaryTextProperties.font = AppFonts.regular(11)
        content.secondaryTextProperties.color = AppColors.textSecondary
        cell.contentConfiguration = content
        cell.accessoryType = current.contains(where: { $0.id == product.id }) ? .checkmark : .none
        cell.tintColor = AppColors.purplePrimary
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let product = filtered[indexPath.row]
        if selectingFree {
            if let idx = free.firstIndex(where: { $0.id == product.id }) { free.remove(at: idx) } else { free.append(product) }
        } else {
            if let idx = buy.firstIndex(where: { $0.id == product.id }) { buy.remove(at: idx) } else { buy.append(product) }
        }
        tableView.reloadRows(at: [indexPath], with: .none)
    }
}
