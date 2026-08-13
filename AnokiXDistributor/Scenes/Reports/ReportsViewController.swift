import UIKit
import QuickLook

/// Reports (New-Design/Report/1.Dashboard.png).
///
/// `GET /reports` answers with everything at once — the catalogue of reports that can be
/// generated, the ones already generated, and the KPI summary — and takes no query
/// parameters. So the keyword box and the Category pill filter the loaded list in memory
/// rather than round-tripping; results are instant and no request is wasted on a
/// keystroke. The web layout's tab strip is not ported: it offers the same six categories
/// as the dropdown beside it, and a second scrolling row would cost a thumb-height of
/// phone screen for nothing.
///
/// Each card downloads its file, and its overflow opens Generate again / Delete
/// (2.Item-Context-Menu.png).
final class ReportsViewController: BaseSecondaryViewController, UICollectionViewDataSource {

    override var screenTitle: String { S.reports }
    override var screenSubtitle: String? { S.reportsPageSubtitle }
    override var trailingTitle: String? { S.generate }

    /// The category filter's options, in the order the web dropdown lists them.
    private static let categories = ["Sales", "Traders", "Inventory", "Deliveries", "Finance", "Products"]

    // The KPI cards ride in the list header so the report cards always own the
    // remaining height — a fixed summary left nothing to scroll on short screens.
    private let collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: AdaptiveGridLayout.make(estimatedHeight: 190, headerEstimatedHeight: 130))

    private var data: ReportsData?
    private var visible: [ReportsData.Report] = []

    private var search = ""
    private var selectedCategory = ""

    private var categoryPill: FilterPillButton!
    private let countLabel = UILabel.make(font: AppFonts.regular(AppMetrics.textCaption),
                                          color: AppColors.textSecondary)

    /// Held while the QuickLook preview is on screen — the controller only keeps a weak
    /// reference to its data source.
    private var previewURL: URL?

    /// The "Downloading…" alert, dismissed before the result sheet takes its place.
    private var downloadProgress: UIAlertController?

    override func setupContent(in container: UIView) {
        let searchBar = SearchBarView(placeholder: S.searchReportsHint, height: 42)
        searchBar.onChange = { [weak self] text in
            // Filtering is local, so there is nothing to debounce.
            self?.search = text.trimmingCharacters(in: .whitespaces)
            self?.render()
        }

        categoryPill = FilterPillButton(title: S.allCategories)
        categoryPill.addTarget(self, action: #selector(pickCategory), for: .touchUpInside)

        let chrome = ListScreenLayout.surfaceSection(
            [searchBar, categoryPill, countLabel],
            spacing: 10,
            insets: UIEdgeInsets(top: 12, left: 16, bottom: 10, right: 16))

        collectionView.dataSource = self
        collectionView.backgroundColor = AppColors.background
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .onDrag
        collectionView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 16, right: 0)
        collectionView.register(ReportCell.self, forCellWithReuseIdentifier: ReportCell.reuseIdentifier)
        collectionView.register(ReportsSummaryHeaderView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: ReportsSummaryHeaderView.reuseIdentifier)

        _ = embedSecondaryListChrome(in: container, chrome: chrome, listView: collectionView)
    }

    override func loadData() {
        ApiClient.shared.getReports { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                self.data = data
                self.render()
            case .failure(let error):
                self.toast(error.message)
            }
        }
    }

    // MARK: Filtering

    private func render() {
        let all = data?.reports ?? []
        visible = all.filter { matchesCategory($0) && matchesSearch($0) }
        countLabel.text = S.reportsShowingCount(visible.count, all.count)
        collectionView.reloadData()
    }

    private func matchesCategory(_ report: ReportsData.Report) -> Bool {
        guard !selectedCategory.isEmpty else { return true }
        return report.category?.trimmingCharacters(in: .whitespaces)
            .caseInsensitiveCompare(selectedCategory) == .orderedSame
    }

    /// The placeholder promises "name or period", so both are searched — as shown.
    private func matchesSearch(_ report: ReportsData.Report) -> Bool {
        guard !search.isEmpty else { return true }
        let haystack = [report.name, report.category, report.periodLabel, report.generatedDateLabel]
        return haystack.contains { ($0 ?? "").localizedCaseInsensitiveContains(search) }
    }

    @objc private func pickCategory() {
        let options = [S.allCategories] + Self.categories
        let sheet = UIAlertController(title: S.reportCategoryLabel, message: nil, preferredStyle: .actionSheet)
        for option in options {
            sheet.addAction(UIAlertAction(title: option, style: .default) { [weak self] _ in
                self?.selectedCategory = (option == S.allCategories) ? "" : option
                self?.categoryPill.setTitle(option)
                self?.render()
            })
        }
        sheet.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        sheet.popoverPresentationController?.sourceView = categoryPill   // iPad anchor
        sheet.popoverPresentationController?.sourceRect = categoryPill.bounds
        present(sheet, animated: true)
    }

    // MARK: Generate / delete / download

    /// "Generate" in the header → a fresh report.
    override func trailingTapped() {
        generate(repeat: nil)
    }

    /// - Parameter repeat: the report being regenerated ("Generate again"), whose
    ///   category, report and original period preselect the sheet.
    private func generate(repeat report: ReportsData.Report?) {
        guard let data = data else { return }   // the catalogue arrives with the list
        let sheet = GenerateReportViewController(data: data, repeating: report)
        sheet.onGenerated = { [weak self] message in
            self?.toast(message.isEmpty ? S.generateReportTitle : message)
            self?.loadData()
        }
        present(sheet, animated: true)
    }

    private func showRowMenu(_ report: ReportsData.Report, anchor: UIView) {
        let sheet = UIAlertController(title: report.name, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: S.reportGenerateAgain, style: .default) { [weak self] _ in
            self?.generate(repeat: report)
        })
        sheet.addAction(UIAlertAction(title: S.reportDelete, style: .destructive) { [weak self] _ in
            self?.confirmDelete(report)
        })
        sheet.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        sheet.popoverPresentationController?.sourceView = anchor   // iPad anchor
        sheet.popoverPresentationController?.sourceRect = anchor.bounds
        present(sheet, animated: true)
    }

    private func confirmDelete(_ report: ReportsData.Report) {
        let alert = UIAlertController(title: S.reportDeleteTitle,
                                      message: S.reportDeleteMessage(report.name ?? ""),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: S.reportDelete, style: .destructive) { [weak self] _ in
            self?.delete(report)
        })
        present(alert, animated: true)
    }

    private func delete(_ report: ReportsData.Report) {
        ApiClient.shared.deleteReport(id: report.id ?? "") { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                self.toast(message.isEmpty ? S.reportDeletedMessage : message)
                self.loadData()
            case .failure(let error):
                self.toast(error.message)
            }
        }
    }

    private func download(_ report: ReportsData.Report, anchor: UIView) {
        // Held so the result can replace it: a download often finishes inside the toast's
        // own lifetime, and presenting a second modal over a live one silently no-ops.
        let progress = UIAlertController(title: nil, message: S.reportDownloading, preferredStyle: .alert)
        downloadProgress = progress
        present(progress, animated: true)

        ApiClient.shared.downloadReport(id: report.id ?? "") { [weak self] result in
            guard let self = self else { return }
            self.dismissDownloadProgress {
                switch result {
                case .success(let download):
                    self.offer(download, report: report, anchor: anchor)
                    // The server counts the download, so refresh the KPI and row meta.
                    self.loadData()
                case .failure(let error):
                    self.toast(error.message)
                }
            }
        }
    }

    private func dismissDownloadProgress(_ then: @escaping () -> Void) {
        guard let progress = downloadProgress else {
            then()
            return
        }
        downloadProgress = nil
        progress.dismiss(animated: false, completion: then)
    }

    /// Writes the file to the app's Documents folder, then offers View / Share.
    private func offer(_ download: Http.Download, report: ReportsData.Report, anchor: UIView) {
        guard let url = save(download, fallbackName: report.suggestedFileName) else {
            toast(S.reportSaveFailed)
            return
        }
        previewURL = url

        let sheet = UIAlertController(title: S.reportDownloadedTitle,
                                      message: S.reportDownloadedMessage(url.lastPathComponent),
                                      preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: S.reportView, style: .default) { [weak self] _ in
            self?.preview(url)
        })
        sheet.addAction(UIAlertAction(title: S.reportShare, style: .default) { [weak self] _ in
            self?.share(url, anchor: anchor)
        })
        sheet.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        sheet.popoverPresentationController?.sourceView = anchor   // iPad anchor
        sheet.popoverPresentationController?.sourceRect = anchor.bounds
        present(sheet, animated: true)
    }

    private func save(_ download: Http.Download, fallbackName: String) -> URL? {
        guard let data = download.data else { return nil }
        let name = (download.fileName?.trimmingCharacters(in: .whitespaces)).flatMap {
            $0.isEmpty ? nil : $0
        } ?? fallbackName
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Reports", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(name)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            print("AxReports: could not save \(name): \(error.localizedDescription)")
            return nil
        }
    }

    /// QuickLook renders CSV inline, so the report is readable without leaving the app.
    private func preview(_ url: URL) {
        previewURL = url
        let controller = QLPreviewController()
        controller.dataSource = self
        present(controller, animated: true)
    }

    private func share(_ url: URL, anchor: UIView) {
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = anchor   // iPad anchor
        activity.popoverPresentationController?.sourceRect = anchor.bounds
        present(activity, animated: true)
    }

    // MARK: Collection view

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        visible.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ReportCell.reuseIdentifier, for: indexPath) as? ReportCell else {
            return UICollectionViewCell()
        }
        let report = visible[indexPath.row]
        cell.configure(report)
        cell.onDownload = { [weak self] anchor in self?.download(report, anchor: anchor) }
        cell.onMore = { [weak self] anchor in self?.showRowMenu(report, anchor: anchor) }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind, withReuseIdentifier: ReportsSummaryHeaderView.reuseIdentifier,
                for: indexPath) as? ReportsSummaryHeaderView else {
            return UICollectionReusableView()
        }
        let filtering = !search.isEmpty || !selectedCategory.isEmpty
        header.configure(summary: data?.summary,
                         emptyMessage: visible.isEmpty
                            ? (filtering ? S.reportsEmptyFiltered : S.reportsEmpty) : nil)
        return header
    }
}

// MARK: - QuickLook

extension ReportsViewController: QLPreviewControllerDataSource {

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        previewURL == nil ? 0 : 1
    }

    func previewController(_ controller: QLPreviewController,
                           previewItemAt index: Int) -> QLPreviewItem {
        // QLPreviewItem is an ObjC protocol: NSURL conforms to it, Swift's URL does not.
        (previewURL ?? URL(fileURLWithPath: "")) as NSURL
    }
}

// MARK: - KPI summary header

/// Scrolling header of the Reports list: the four KPI cards from the web dashboard —
/// Reports Generated, Downloads, This Month and Failed.
final class ReportsSummaryHeaderView: UICollectionReusableView {

    static let reuseIdentifier = "ReportsSummaryHeaderView"

    private let generatedCard = InventoryKpiCard(
        title: S.kpiReportsGenerated, icon: "ic_document", tint: AppColors.purplePrimary,
        tile: AppColors.purpleLight, caption: S.kpiReportsGeneratedCaption)
    private let downloadsCard = InventoryKpiCard(
        title: S.kpiReportDownloads, icon: "ic_download", tint: AppColors.success,
        tile: AppColors.successBg, caption: S.kpiReportDownloadsCaption)
    private let monthCard = InventoryKpiCard(
        title: S.kpiReportsThisMonth, icon: "ic_calendar", tint: AppColors.info,
        tile: AppColors.infoBg, caption: S.kpiReportsThisMonthCaption)
    private let failedCard = InventoryKpiCard(
        title: S.kpiReportsFailed, icon: "ic_cancel_circle", tint: AppColors.danger,
        tile: AppColors.dangerBg, caption: S.kpiReportsFailedNone)

    private let emptyLabel = UILabel.make(font: AppFonts.regular(AppMetrics.textBody),
                                          color: AppColors.textSecondary, align: .center, lines: 0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        build()
    }

    private func build() {
        backgroundColor = .clear

        let row = UIStackView.horizontal(spacing: 8, alignment: .fill)
        [generatedCard, downloadsCard, monthCard, failedCard].forEach { row.addArrangedSubview($0) }
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.clipsToBounds = false
        row.forAutoLayout()
        scroll.addSubview(row)
        scroll.forAutoLayout()
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            row.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])

        emptyLabel.isHidden = true

        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.addArrangedSubview(scroll)
        stack.addArrangedSubview(emptyLabel)
        stack.forAutoLayout()
        addSubview(stack)
        stack.pinEdges(to: self, insets: UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0))
    }

    func configure(summary: ReportsData.Summary?, emptyMessage: String?) {
        generatedCard.set("\(summary?.generated ?? 0)", caption: S.kpiReportsGeneratedCaption)
        downloadsCard.set("\(summary?.downloads ?? 0)", caption: S.kpiReportDownloadsCaption)
        monthCard.set("\(summary?.thisMonth ?? 0)", caption: S.kpiReportsThisMonthCaption)

        let failed = summary?.failed ?? 0
        failedCard.set("\(failed)",
                       caption: failed == 0 ? S.kpiReportsFailedNone : S.kpiReportsFailedSome)

        emptyLabel.text = emptyMessage
        emptyLabel.isHidden = emptyMessage?.isEmpty != false
    }
}

// MARK: - Report card

/// Generated-report card (1.Dashboard.png) — the phone form of the web table row: name
/// and category on top, the period and generation time under it, then the format / size /
/// rows facts as one meta line, with Download and the overflow on the bottom row.
final class ReportCell: UICollectionViewCell {

    static let reuseIdentifier = "ReportCell"

    /// Both pass their own frame so the sheet can point at them on iPad.
    var onDownload: ((UIView) -> Void)?
    var onMore: ((UIView) -> Void)?

    private let cardView = UIView()
    private let iconTile = StyleKit.iconTile(color: AppColors.purpleLight)
    private let nameLabel = UILabel()
    private let categoryBadge = StyleKit.badgeLabel()
    private let statusBadge = StyleKit.badgeLabel()
    private let periodLabel = UILabel()
    private let generatedLabel = UILabel()
    private let metaLabel = UILabel()
    private let errorLabel = UILabel()
    private let downloadButton = UIButton(type: .system)
    private let moreButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        build()
    }

    private func build() {
        backgroundColor = .clear
        StyleKit.styleCard(cardView)
        cardView.forAutoLayout()
        contentView.addSubview(cardView)
        cardView.pinEdges(to: contentView, insets: UIEdgeInsets(top: 0, left: 0, bottom: 10, right: 0))

        iconTile.constrainSize(40)
        let icon = UIImageView(image: AppIcons.symbol("ic_document"))
        icon.tintColor = AppColors.purplePrimary
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()
        iconTile.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20)
        ])

        nameLabel.font = AppFonts.bold(14)
        nameLabel.textColor = AppColors.topTitle
        nameLabel.lineBreakMode = .byTruncatingTail

        let badgeRow = UIStackView.horizontal(spacing: 6, alignment: .center)
        badgeRow.addArrangedSubview(categoryBadge)
        badgeRow.addArrangedSubview(statusBadge)
        badgeRow.addArrangedSubview(UIView())

        let identity = UIStackView.vertical(spacing: 4, alignment: .fill)
        identity.addArrangedSubview(nameLabel)
        identity.addArrangedSubview(badgeRow)

        moreButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        moreButton.tintColor = AppColors.textSecondary
        moreButton.accessibilityLabel = "More actions"
        moreButton.constrainSize(32)
        moreButton.setContentHuggingPriority(.required, for: .horizontal)
        moreButton.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.onMore?(self.moreButton)
        }, for: .touchUpInside)

        let topRow = UIStackView.horizontal(spacing: 12, alignment: .center)
        topRow.addArrangedSubview(iconTile)
        topRow.addArrangedSubview(identity)
        topRow.addArrangedSubview(moreButton)

        errorLabel.font = AppFonts.regular(11)
        errorLabel.textColor = AppColors.danger
        errorLabel.numberOfLines = 3
        errorLabel.isHidden = true

        StyleKit.styleOutlinedButton(downloadButton, fontSize: 13)
        downloadButton.setTitle(S.reportDownload, for: .normal)
        downloadButton.setImage(UIImage(systemName: "arrow.down.to.line"), for: .normal)
        // Trim the helper's 14pt vertical padding so the button settles at 40pt.
        downloadButton.configuration?.contentInsets =
            NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        downloadButton.configuration?.imagePadding = 8
        downloadButton.configuration?.preferredSymbolConfigurationForImage =
            UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        downloadButton.constrainHeight(40)
        downloadButton.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.onDownload?(self.downloadButton)
        }, for: .touchUpInside)

        let stack = UIStackView.vertical(spacing: 4, alignment: .fill)
        stack.addArrangedSubview(topRow)
        stack.addArrangedSubview(iconRow(symbol: "calendar", label: periodLabel))
        stack.addArrangedSubview(iconRow(symbol: "clock", label: generatedLabel))
        stack.addArrangedSubview(iconRow(symbol: "doc.text", label: metaLabel))
        stack.addArrangedSubview(errorLabel)
        stack.addArrangedSubview(downloadButton)
        stack.setCustomSpacing(10, after: topRow)
        stack.setCustomSpacing(12, after: errorLabel)
        stack.forAutoLayout()
        cardView.addSubview(stack)
        stack.pinEdges(to: cardView, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
    }

    /// A small tinted glyph in front of a secondary line, matching the web row's meta icons.
    private func iconRow(symbol: String, label: UILabel) -> UIStackView {
        label.font = AppFonts.regular(11)
        label.textColor = AppColors.textSecondary
        label.numberOfLines = 1

        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = AppColors.textTertiary
        icon.contentMode = .scaleAspectFit
        icon.constrainSize(12)
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView.horizontal(spacing: 6, alignment: .center)
        row.addArrangedSubview(icon)
        row.addArrangedSubview(label)
        return row
    }

    func configure(_ report: ReportsData.Report) {
        nameLabel.text = report.name

        apply(categoryBadge, text: Self.capitalised(report.category),
              colors: (AppColors.purplePrimary, AppColors.purpleLight))
        apply(statusBadge, text: Self.capitalised(report.status),
              colors: Self.statusColors(report.status))

        periodLabel.text = S.reportPeriodValue(report.periodLabel)
        let time = report.generatedTimeLabel
        generatedLabel.text = S.reportGeneratedValue(
            time.isEmpty ? report.generatedDateLabel : "\(report.generatedDateLabel), \(time)")
        metaLabel.text = Self.metaLine(report)

        let error = (report.error ?? "").trimmingCharacters(in: .whitespaces)
        let failed = !report.isReady
        errorLabel.text = error
        errorLabel.isHidden = !(failed && !error.isEmpty)

        // Nothing to fetch until the server says the file is ready.
        downloadButton.isEnabled = !failed
        downloadButton.alpha = failed ? 0.4 : 1
    }

    /// "CSV · 933 B · 10 rows · 1 download" — the table's trailing columns as one line.
    private static func metaLine(_ report: ReportsData.Report) -> String {
        let rows = report.rowCount ?? 0
        var parts = [report.formatLabel, report.sizeLabel, "\(rows) \(rows == 1 ? "row" : "rows")"]
        let downloads = report.downloads ?? 0
        if downloads > 0 {
            parts.append("\(downloads) \(downloads == 1 ? "download" : "downloads")")
        }
        return parts.joined(separator: " · ")
    }

    private func apply(_ badge: PaddingLabel, text: String, colors: (fg: UIColor, bg: UIColor)) {
        badge.isHidden = text.isEmpty
        guard !text.isEmpty else { return }
        badge.text = text
        badge.font = AppFonts.regular(AppMetrics.textMicro)
        badge.textColor = colors.fg
        badge.backgroundColor = colors.bg
    }

    /// The API sends categories and statuses lower-cased ("inventory", "ready").
    private static func capitalised(_ value: String?) -> String {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return "" }
        return String(first).uppercased() + trimmed.dropFirst()
    }

    private static func statusColors(_ status: String?) -> (UIColor, UIColor) {
        switch (status ?? "").trimmingCharacters(in: .whitespaces).lowercased() {
        case "ready": return (AppColors.success, AppColors.successBg)
        case "failed", "error": return (AppColors.danger, AppColors.dangerBg)
        default: return (AppColors.warning, AppColors.warningBg)
        }
    }
}
