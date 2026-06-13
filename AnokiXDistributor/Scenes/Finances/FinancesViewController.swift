import UIKit

/// Port of FinancesActivity — summary cards, segment filter, transaction list in card.
final class FinancesViewController: BaseSecondaryViewController {

    override var screenTitle: String { S.finances }
    override var screenSubtitle: String? { "Track revenue, payments and expenses" }

    private var stack: UIStackView!
    private var typeFilter = "all"
    private var transactionsContainer = UIStackView.vertical(spacing: 0, alignment: .fill)

    override func setupContent(in container: UIView) {
        stack = makeScrollStack(in: container, insets: UIEdgeInsets(top: 0, left: 16, bottom: 24, right: 16))

        let summaryScroll = UIScrollView()
        summaryScroll.showsHorizontalScrollIndicator = false
        let summaryRow = UIStackView.horizontal(spacing: 12, alignment: .fill)
        summaryRow.forAutoLayout()
        for summary in repository.getFinanceSummaries() {
            summaryRow.addArrangedSubview(summaryCard(summary))
        }
        summaryScroll.addSubview(summaryRow)
        summaryRow.pinEdges(to: summaryScroll, insets: UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0))
        summaryScroll.heightAnchor.constraint(equalToConstant: 112).isActive = true
        summaryRow.heightAnchor.constraint(equalTo: summaryScroll.heightAnchor, constant: -12).isActive = true

        let summaryBlock = ListScreenLayout.surfaceSection(
            [summaryScroll],
            insets: UIEdgeInsets(top: AppMetrics.screenPaddingVertical, left: 0, bottom: 0, right: 0)
        )

        let segment = SegmentContainerView(titles: ["All", "Income", "Expenses"], selectedIndex: 0) { [weak self] index in
            self?.typeFilter = ["all", "income", "expenses"][index]
            self?.reloadTransactions()
        }
        let filterBlock = ListScreenLayout.surfaceSection(
            [segment],
            insets: UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)
        )

        let txCard = StyleKit.cardView()
        transactionsContainer.forAutoLayout()
        txCard.addSubview(transactionsContainer)
        transactionsContainer.pinEdges(to: txCard, insets: UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0))

        stack.addArrangedSubview(summaryBlock)
        stack.addArrangedSubview(filterBlock)
        stack.addArrangedSubview(txCard)
    }

    override func loadData() { reloadTransactions() }

    private func reloadTransactions() {
        transactionsContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let items = repository.getFinanceTransactions(typeFilter: typeFilter)
        for (index, t) in items.enumerated() {
            transactionsContainer.addArrangedSubview(transactionRow(t))
            if index < items.count - 1 {
                let line = UIView()
                line.backgroundColor = AppColors.border
                line.constrainHeight(1)
                let wrap = UIStackView.vertical(spacing: 0, alignment: .fill)
                wrap.addArrangedSubview(line)
                transactionsContainer.addArrangedSubview(wrap)
            }
        }
    }

    private func summaryCard(_ s: FinanceSummary) -> UIView {
        let card = StyleKit.cardView()
        card.widthAnchor.constraint(equalToConstant: 160).isActive = true
        let title = UILabel.make(s.title, font: AppFonts.regular(11), color: AppColors.textSecondary, lines: 2)
        let amount = UILabel.make(s.amount, font: AppFonts.bold(20), color: s.valueColor)
        let trend = UILabel.make(s.trend, font: AppFonts.regular(10), color: s.trendColor, lines: 2)
        let inner = UIStackView.vertical(spacing: 4, alignment: .leading)
        inner.forAutoLayout()
        [title, amount, trend].forEach { inner.addArrangedSubview($0) }
        card.addSubview(inner)
        inner.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        return card
    }

    private func transactionRow(_ t: FinanceTransaction) -> UIView {
        let tile = StyleKit.iconTile(color: t.isIncome ? AppColors.successBg : AppColors.dangerBg)
        tile.constrainSize(40)
        let icon = UIImageView(image: AppIcons.symbol(t.icon))
        icon.tintColor = t.isIncome ? AppColors.success : AppColors.danger
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()
        tile.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18)
        ])
        let title = UILabel.make(t.title, font: AppFonts.bold(13), color: AppColors.textPrimary)
        let meta = UILabel.make("\(t.invoiceId) · \(t.date)", font: AppFonts.regular(11), color: AppColors.textSecondary)
        let textStack = UIStackView.vertical(spacing: 2, alignment: .leading)
        textStack.addArrangedSubview(title)
        textStack.addArrangedSubview(meta)
        let amount = UILabel.make(t.amount, font: AppFonts.bold(13), color: t.isIncome ? AppColors.success : AppColors.danger)
        amount.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.forAutoLayout()
        [tile, textStack, UIView(), amount].forEach { row.addArrangedSubview($0) }
        let wrapper = UIView()
        wrapper.addSubview(row)
        row.pinEdges(to: wrapper, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        return wrapper
    }
}
