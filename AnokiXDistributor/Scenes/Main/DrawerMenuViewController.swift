import UIKit

/// Port of drawer_content.xml + DrawerMenuAdapter. Dark 280pt panel with logo, portal badge,
/// menu items with purple selected pill, and logout.
final class DrawerMenuViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var onSelect: ((String) -> Void)?

    private let selectedKey: String
    private let scrim = UIView()
    private let panel = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let items = MockData.drawerMenuItems()
    private var panelLeading: NSLayoutConstraint!

    init(selectedKey: String = "home") {
        self.selectedKey = selectedKey
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.0)
        scrim.forAutoLayout()
        scrim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissDrawer)))
        view.addSubview(scrim)
        scrim.pinEdges(to: view)

        panel.backgroundColor = AppColors.drawerBg
        panel.forAutoLayout()
        view.addSubview(panel)
        panelLeading = panel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -AppMetrics.drawerWidth)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: view.topAnchor),
            panel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            panel.widthAnchor.constraint(equalToConstant: AppMetrics.drawerWidth),
            panelLeading
        ])

        buildPanelContent()
    }

    private func buildPanelContent() {
        let logo = UIImageView(image: BrandAssets.logoWhite)
        logo.contentMode = .scaleAspectFit
        logo.forAutoLayout()

        let badge = PaddingLabel(insets: UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12))
        badge.text = S.distributorPortal
        badge.font = AppFonts.regular(AppMetrics.textLabel)
        badge.textColor = AppColors.drawerBadgeText
        badge.backgroundColor = AppColors.drawerBadgeBg
        badge.layer.cornerRadius = 8
        badge.layer.masksToBounds = true

        let header = UIStackView.vertical(spacing: AppMetrics.spacingSM, alignment: .leading)
        header.addArrangedSubview(logo)
        header.addArrangedSubview(badge)
        header.forAutoLayout()
        panel.addSubview(header)

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = AppMetrics.drawerItemHeight
        tableView.registerNib(DrawerMenuCell.self)
        tableView.forAutoLayout()
        panel.addSubview(tableView)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: panel.safeAreaLayoutGuide.topAnchor, constant: 48),
            header.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: AppMetrics.spacingLG),
            header.trailingAnchor.constraint(lessThanOrEqualTo: panel.trailingAnchor, constant: -AppMetrics.spacingLG),
            logo.heightAnchor.constraint(lessThanOrEqualToConstant: 40),
            tableView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: AppMetrics.spacingXL),
            tableView.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: panel.safeAreaLayoutGuide.bottomAnchor, constant: -AppMetrics.spacingLG)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        panelLeading.constant = 0
        UIView.animate(withDuration: 0.25) {
            self.scrim.backgroundColor = UIColor.black.withAlphaComponent(0.4)
            self.view.layoutIfNeeded()
        }
    }

    @objc private func dismissDrawer() {
        panelLeading.constant = -AppMetrics.drawerWidth
        UIView.animate(withDuration: 0.2, animations: {
            self.scrim.backgroundColor = UIColor.black.withAlphaComponent(0.0)
            self.view.layoutIfNeeded()
        }, completion: { _ in self.dismiss(animated: false) })
    }

    // MARK: Table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeue(DrawerMenuCell.self, for: indexPath)
        let item = items[indexPath.row]
        cell.configure(item, selected: item.key == selectedKey)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let key = items[indexPath.row].key
        panelLeading.constant = -AppMetrics.drawerWidth
        UIView.animate(withDuration: 0.2, animations: {
            self.scrim.backgroundColor = UIColor.black.withAlphaComponent(0.0)
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.dismiss(animated: false) { self.onSelect?(key) }
        })
    }
}
