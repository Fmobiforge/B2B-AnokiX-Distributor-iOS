import UIKit

/// Port of ReportsActivity. Report-type cards (2-up grid) and a recent reports list.
final class ReportsViewController: BaseSecondaryViewController {

    override var screenTitle: String { S.reports }
    override var screenSubtitle: String? { "Generate and download business reports" }

    override func setupContent(in container: UIView) {
        let stack = makeScrollStack(in: container)

        stack.addArrangedSubview(UILabel.make(S.reportsSubtitle, font: AppFonts.light(13), color: AppColors.textSecondary))

        stack.addArrangedSubview(UILabel.title("Report Types"))
        let types = repository.getReportTypes()
        for pair in stride(from: 0, to: types.count, by: 2) {
            let row = UIStackView.horizontal(spacing: 12, alignment: .fill)
            row.distribution = .fillEqually
            row.addArrangedSubview(typeCard(types[pair]))
            if pair + 1 < types.count { row.addArrangedSubview(typeCard(types[pair + 1])) }
            else { row.addArrangedSubview(UIView()) }
            stack.addArrangedSubview(row)
        }

        let generate = UIButton(type: .system)
        StyleKit.stylePrimaryButton(generate, fontSize: 13)
        generate.setTitle(S.generateReport, for: .normal)
        generate.setImage(UIImage(systemName: "doc.text"), for: .normal)
        generate.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        generate.tintColor = .white
        generate.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        stack.addArrangedSubview(generate)

        stack.addArrangedSubview(UILabel.title("Recent Reports"))
        for report in repository.getRecentReports() {
            stack.addArrangedSubview(recentRow(report))
        }
    }

    private func typeCard(_ type: ReportTypeItem) -> UIView {
        let card = StyleKit.cardView()
        let tile = StyleKit.iconTile(color: AppColors.purpleLight)
        tile.constrainSize(40)
        let icon = UIImageView(image: AppIcons.symbol(type.icon))
        icon.tintColor = AppColors.purplePrimary
        icon.contentMode = .scaleAspectFit
        icon.forAutoLayout()
        tile.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20)
        ])
        let title = UILabel.make(type.title, font: AppFonts.bold(13), color: AppColors.textPrimary)
        let desc = UILabel.make(type.description, font: AppFonts.regular(10), color: AppColors.textSecondary, lines: 2)
        let stack = UIStackView.vertical(spacing: 8, alignment: .leading)
        stack.forAutoLayout()
        [tile, title, desc].forEach { stack.addArrangedSubview($0) }
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        return card
    }

    private func recentRow(_ report: ReportHistoryItem) -> UIView {
        let card = StyleKit.cardView()
        let icon = UIImageView(image: AppIcons.symbol("ic_pdf"))
        icon.tintColor = AppColors.danger
        icon.contentMode = .scaleAspectFit
        icon.constrainSize(28)
        let title = UILabel.make(report.name, font: AppFonts.bold(13), color: AppColors.textPrimary)
        let date = UILabel.make("Generated \(report.generatedDate)", font: AppFonts.regular(11), color: AppColors.textSecondary)
        let textStack = UIStackView.vertical(spacing: 2, alignment: .leading)
        textStack.addArrangedSubview(title)
        textStack.addArrangedSubview(date)
        let badge = StyleKit.badgeLabel()
        badge.text = report.format
        badge.textColor = AppColors.info
        badge.backgroundColor = AppColors.infoBg
        badge.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView.horizontal(spacing: 12, alignment: .center)
        row.forAutoLayout()
        [icon, textStack, UIView(), badge].forEach { row.addArrangedSubview($0) }
        card.addSubview(row)
        row.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        return card
    }

    @objc private func generateTapped() {
        toast(S.generateReport)
    }
}
