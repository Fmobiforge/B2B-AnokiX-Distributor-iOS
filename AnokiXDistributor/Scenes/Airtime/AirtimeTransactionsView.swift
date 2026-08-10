import UIKit

/// Airtime & VAS › Recent transactions. The same feed as before, now on its own tab; the
/// activity refreshes it after any sale or provisioning.
final class AirtimeTransactionsView: VasSectionView {

    private let listContainer = UIStackView.vertical(spacing: 0, alignment: .fill)
    private var transactions: [VasTransactionsData.Transaction] = []

    override func build() {
        let (cardView, content) = makeCard(title: "Recent VAS transactions")
        content.addArrangedSubview(listContainer)
        stack.addArrangedSubview(cardView)
        rebuild()
    }

    func setTransactions(_ items: [VasTransactionsData.Transaction]) {
        transactions = items
        rebuild()
    }

    private func rebuild() {
        listContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if transactions.isEmpty {
            listContainer.addArrangedSubview(centeredMessage("No transactions yet."))
            return
        }
        for (i, t) in transactions.enumerated() {
            listContainer.addArrangedSubview(row(t))
            if i < transactions.count - 1 { listContainer.addArrangedSubview(hairline()) }
        }
    }

    private func row(_ t: VasTransactionsData.Transaction) -> UIView {
        let title = UILabel.make(t.name ?? "—", font: AppFonts.semibold(14), color: AppColors.textPrimary, lines: 1)
        let meta = UILabel.make("\(VasFormat.msisdn(t.msisdn)) · \(VasFormat.time(t.createdAt))",
                                font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 1)
        let left = UIStackView.vertical(spacing: 3, alignment: .leading)
        left.setContentHuggingPriority(.defaultLow, for: .horizontal)
        [title, meta].forEach { left.addArrangedSubview($0) }

        let amount = UILabel.make(VasFormat.money(t.amount), font: AppFonts.bold(14), color: AppColors.textPrimary)
        let right = UIStackView.vertical(spacing: 4, alignment: .trailing)
        right.setContentHuggingPriority(.required, for: .horizontal)
        [amount, statusPill(VasFormat.statusStyle(t.status))].forEach { right.addArrangedSubview($0) }

        let row = UIStackView.horizontal(spacing: 10, alignment: .top)
        row.addArrangedSubview(left)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(right)
        return padded(row, insets: UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0))
    }
}
