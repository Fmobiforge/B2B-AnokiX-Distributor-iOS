import UIKit

/// Return detail screen (port of ReturnDetailActivity / the Returns-Item-Details mock): GRN
/// number + status, trader contact, reason + submitted date, trader note, the line items
/// (item / qty / line total), the issued credit note, the decision note, and — while pending —
/// Approve / Reject buttons. Fetched by id from `api/distributor/grns/get-by-id`.
final class ReturnDetailViewController: BaseSecondaryViewController {

    override var screenTitle: String { S.returnDetails }

    /// Notifies the list to refresh after a successful approve / reject.
    var onUpdated: (() -> Void)?

    private let returnId: String
    private let currency = "R"
    private var traderPhone: String?

    private var contentStack: UIStackView!
    private let spinner = UIActivityIndicatorView(style: .medium)

    init(returnId: String) {
        self.returnId = returnId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func setupContent(in container: UIView) {
        contentStack = makeScrollStack(in: container, spacing: 16)
        spinner.hidesWhenStopped = true
        spinner.forAutoLayout()
        container.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
    }

    override func loadData() {
        spinner.startAnimating()
        ApiClient.shared.getReturnById(id: returnId) { [weak self] result in
            guard let self = self else { return }
            self.spinner.stopAnimating()
            switch result {
            case .success(let data):
                guard let item = data.returnItem else {
                    self.toast(S.returnLoadFailed)
                    self.navigationController?.popViewController(animated: true)
                    return
                }
                self.bind(item)
            case .failure(let error):
                self.toast(error.message.isEmpty ? S.returnLoadFailed : error.message)
                self.navigationController?.popViewController(animated: true)
            }
        }
    }

    // MARK: - Bind

    private func bind(_ r: ReturnDetailDTO) {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        contentStack.addArrangedSubview(headerBlock(r))
        contentStack.addArrangedSubview(traderBlock(r))
        contentStack.addArrangedSubview(ListScreenLayout.hairline())
        contentStack.addArrangedSubview(reasonRow(r))
        if let note = r.note, !note.trimmingCharacters(in: .whitespaces).isEmpty {
            contentStack.addArrangedSubview(noteCard(S.traderNoteCaps, note, accent: false))
        }
        contentStack.addArrangedSubview(itemsCard(r))
        if let cn = r.creditNoteNumber, !cn.trimmingCharacters(in: .whitespaces).isEmpty {
            contentStack.addArrangedSubview(creditCard(cn, total: r.creditNoteTotal ?? 0))
        }
        if let decision = r.decisionNote, !decision.trimmingCharacters(in: .whitespaces).isEmpty {
            contentStack.addArrangedSubview(noteCard(S.decisionNoteCaps, decision, accent: false))
        }
        if ReturnsViewController.isPending(r.status) {
            contentStack.addArrangedSubview(actionButtons(r.id))
        }
    }

    private func headerBlock(_ r: ReturnDetailDTO) -> UIView {
        let number = UILabel.make(r.grnNumber ?? "", font: AppFonts.bold(20), color: AppColors.purplePrimary)

        let badge = StyleKit.badgeLabel()
        let (fg, bg) = ReturnFormat.colors(r.status)
        badge.text = ReturnFormat.label(r.status)
        badge.textColor = fg
        badge.backgroundColor = bg
        badge.font = AppFonts.regular(12)
        badge.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.addArrangedSubview(number)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(badge)
        return row
    }

    private func traderBlock(_ r: ReturnDetailDTO) -> UIView {
        let stack = UIStackView.vertical(spacing: 4, alignment: .fill)
        stack.addArrangedSubview(UILabel.make(r.resolvedTraderName, font: AppFonts.regular(13), color: AppColors.textSecondary, lines: 0))

        if let phone = r.traderPhone, !phone.isEmpty {
            traderPhone = phone
            let phoneIcon = UIImageView(image: UIImage(systemName: "phone.fill"))
            phoneIcon.tintColor = AppColors.textSecondary
            phoneIcon.contentMode = .scaleAspectFit
            phoneIcon.forAutoLayout()
            phoneIcon.constrainSize(16)
            phoneIcon.setContentHuggingPriority(.required, for: .horizontal)
            let phoneLabel = UILabel.make(phone, font: AppFonts.regular(13), color: AppColors.textSecondary)
            let phoneRow = UIStackView.horizontal(spacing: 8, alignment: .center)
            phoneRow.addArrangedSubview(phoneIcon)
            phoneRow.addArrangedSubview(phoneLabel)
            phoneRow.addArrangedSubview(UIView())
            phoneRow.isUserInteractionEnabled = true
            phoneRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(callTrader)))
            stack.addArrangedSubview(phoneRow)
        }
        return stack
    }

    private func reasonRow(_ r: ReturnDetailDTO) -> UIView {
        let reasonText = (r.reasonLabel?.isEmpty == false) ? r.reasonLabel! : ReturnFormat.label(r.reason)
        let row = UIStackView.horizontal(spacing: 8, alignment: .top)
        row.distribution = .fillEqually
        row.addArrangedSubview(labeledColumn(S.reasonCaps, reasonText))
        row.addArrangedSubview(labeledColumn(S.submittedCaps, ReturnFormat.date(r.createdAt)))
        return row
    }

    private func labeledColumn(_ caption: String, _ value: String) -> UIStackView {
        let stack = UIStackView.vertical(spacing: 3, alignment: .leading)
        stack.addArrangedSubview(UILabel.make(caption, font: AppFonts.regular(11), color: AppColors.textSecondary))
        stack.addArrangedSubview(UILabel.make(value.isEmpty ? "—" : value, font: AppFonts.bold(14), color: AppColors.purplePrimary, lines: 0))
        return stack
    }

    private func noteCard(_ caption: String, _ text: String, accent: Bool) -> UIView {
        let card = StyleKit.cardView()
        card.backgroundColor = AppColors.background
        let captionLabel = UILabel.make(caption, font: AppFonts.regular(11), color: AppColors.textSecondary)
        let body = UILabel.make(text, font: AppFonts.regular(13), color: AppColors.textPrimary, lines: 0)
        let stack = UIStackView.vertical(spacing: 4, alignment: .fill)
        stack.forAutoLayout()
        stack.addArrangedSubview(captionLabel)
        stack.addArrangedSubview(body)
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        return card
    }

    private func itemsCard(_ r: ReturnDetailDTO) -> UIView {
        let card = StyleKit.cardView()
        let stack = UIStackView.vertical(spacing: 0, alignment: .fill)
        stack.forAutoLayout()

        // Header row
        let header = UIStackView.horizontal(spacing: 8, alignment: .center)
        header.isLayoutMarginsRelativeArrangement = true
        header.layoutMargins = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        header.addArrangedSubview(UILabel.make(S.itemColTitle, font: AppFonts.bold(11), color: AppColors.textSecondary))
        let qtyTitle = UILabel.make(S.qtyColTitle, font: AppFonts.bold(11), color: AppColors.textSecondary, align: .right)
        qtyTitle.widthAnchor.constraint(equalToConstant: 44).isActive = true
        header.addArrangedSubview(qtyTitle)
        let lineTitle = UILabel.make(S.lineColTitle, font: AppFonts.bold(11), color: AppColors.textSecondary, align: .right)
        lineTitle.widthAnchor.constraint(equalToConstant: 76).isActive = true
        header.addArrangedSubview(lineTitle)
        let headerWrap = UIView()
        headerWrap.backgroundColor = AppColors.surfaceVariant
        header.forAutoLayout()
        headerWrap.addSubview(header)
        header.pinEdges(to: headerWrap)
        stack.addArrangedSubview(headerWrap)

        let items = r.items ?? []
        for (index, item) in items.enumerated() {
            if index > 0 { stack.addArrangedSubview(ListScreenLayout.hairline()) }
            stack.addArrangedSubview(itemRow(item))
        }

        card.addSubview(stack)
        stack.pinEdges(to: card)
        return card
    }

    private func itemRow(_ item: ReturnItemDTO) -> UIView {
        let name = UILabel.make(item.name ?? "", font: AppFonts.regular(13), color: AppColors.textPrimary, lines: 0)
        let qty = UILabel.make("\(item.quantity ?? 0)", font: AppFonts.regular(13), color: AppColors.textPrimary, align: .right)
        qty.widthAnchor.constraint(equalToConstant: 44).isActive = true
        let line = UILabel.make(OrderFormat.money(item.lineTotal ?? 0, currency: currency),
                                font: AppFonts.regular(13), color: AppColors.textPrimary, align: .right)
        line.widthAnchor.constraint(equalToConstant: 76).isActive = true
        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        row.addArrangedSubview(name)
        row.addArrangedSubview(qty)
        row.addArrangedSubview(line)
        return row
    }

    private func creditCard(_ number: String, total: Double) -> UIView {
        let card = StyleKit.cardView()
        card.backgroundColor = AppColors.successBg
        card.layer.borderColor = AppColors.success.cgColor
        card.layer.borderWidth = 1

        let icon = UIImageView(image: UIImage(systemName: "checkmark.shield.fill"))
        icon.tintColor = AppColors.success
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()
        icon.constrainSize(22)
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let numberLabel = UILabel.make(number, font: AppFonts.bold(14), color: AppColors.success)
        let sub = UILabel.make("\(OrderFormat.money(total, currency: currency)) credited to trader",
                               font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 0)
        let textCol = UIStackView.vertical(spacing: 2, alignment: .leading)
        textCol.addArrangedSubview(numberLabel)
        textCol.addArrangedSubview(sub)

        let row = UIStackView.horizontal(spacing: 10, alignment: .center)
        row.forAutoLayout()
        row.addArrangedSubview(icon)
        row.addArrangedSubview(textCol)
        card.addSubview(row)
        row.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        return card
    }

    private func actionButtons(_ id: Int) -> UIView {
        let reject = UIButton(type: .system)
        var rejectConfig = UIButton.Configuration.plain()
        rejectConfig.title = S.reject
        rejectConfig.image = UIImage(systemName: "xmark.circle")
        rejectConfig.imagePadding = 6
        rejectConfig.baseForegroundColor = AppColors.danger
        rejectConfig.background.strokeColor = AppColors.danger
        rejectConfig.background.strokeWidth = 1
        rejectConfig.background.cornerRadius = AppMetrics.radiusMD
        rejectConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming; out.font = AppFonts.bold(15); return out
        }
        reject.configuration = rejectConfig
        reject.heightAnchor.constraint(equalToConstant: 50).isActive = true
        reject.addAction(UIAction { [weak self] _ in self?.promptAction(id, action: "reject") }, for: .touchUpInside)

        let approve = UIButton(type: .system)
        StyleKit.stylePrimaryButton(approve)
        approve.setTitle(S.approve, for: .normal)
        approve.setImage(UIImage(systemName: "checkmark.circle"), for: .normal)
        approve.tintColor = .white
        approve.heightAnchor.constraint(equalToConstant: 50).isActive = true
        approve.addAction(UIAction { [weak self] _ in self?.promptAction(id, action: "approve") }, for: .touchUpInside)

        let row = UIStackView.horizontal(spacing: 12, alignment: .fill)
        row.distribution = .fillEqually
        row.addArrangedSubview(reject)
        row.addArrangedSubview(approve)
        return row
    }

    // MARK: - Actions

    private func promptAction(_ id: Int, action: String) {
        let approve = action == "approve"
        let alert = UIAlertController(title: approve ? S.approveReturn : S.rejectReturn,
                                      message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = S.decisionNoteHint }
        alert.addAction(UIAlertAction(title: S.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: approve ? S.approve : S.reject,
                                      style: approve ? .default : .destructive) { [weak self, weak alert] _ in
            let note = alert?.textFields?.first?.text ?? ""
            self?.performAction(id, action: action, note: note)
        })
        present(alert, animated: true)
    }

    private func performAction(_ id: Int, action: String, note: String) {
        spinner.startAnimating()
        ApiClient.shared.returnAction(action, grnId: id, note: note) { [weak self] result in
            guard let self = self else { return }
            self.spinner.stopAnimating()
            switch result {
            case .success(let data):
                self.onUpdated?()
                self.successBanner(action == "approve" ? S.returnApprovedMsg : S.returnRejectedMsg)
                if let item = data.returnItem { self.bind(item) }
            case .failure(let error):
                self.toast(error.message.isEmpty ? S.returnActionFailed : error.message)
            }
        }
    }

    @objc private func callTrader() {
        let digits = (traderPhone ?? "").filter { !$0.isWhitespace }
        guard !digits.isEmpty, let url = URL(string: "tel://\(digits)"),
              UIApplication.shared.canOpenURL(url) else {
            toast(S.orderCallFailed)
            return
        }
        UIApplication.shared.open(url)
    }
}
