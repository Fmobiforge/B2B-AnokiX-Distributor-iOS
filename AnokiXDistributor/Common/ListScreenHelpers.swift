import UIKit

// MARK: - Search + filter row (fragment_orders / fragment_products search rows)

final class SearchFilterRowView: UIView {
    let searchBar: SearchBarView
    let filterButton: UIButton

    init(placeholder: String, height: CGFloat = 42) {
        searchBar = SearchBarView(placeholder: placeholder, height: height)
        filterButton = UIButton(type: .system)
        super.init(frame: .zero)
        filterButton.setImage(UIImage(systemName: "line.3.horizontal.decrease"), for: .normal)
        filterButton.tintColor = AppColors.textSecondary
        filterButton.backgroundColor = AppColors.surface
        filterButton.layer.cornerRadius = AppMetrics.radiusSM
        filterButton.layer.borderWidth = 1
        filterButton.layer.borderColor = AppColors.border.cgColor
        filterButton.forAutoLayout()
        searchBar.forAutoLayout()
        addSubviews(searchBar, filterButton)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: height),
            filterButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            filterButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            filterButton.widthAnchor.constraint(equalToConstant: height),
            filterButton.heightAnchor.constraint(equalToConstant: height),
            searchBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            searchBar.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchBar.trailingAnchor.constraint(equalTo: filterButton.leadingAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Date range pill (Orders header)

final class DateRangePillView: UIControl {
    init(text: String) {
        super.init(frame: .zero)
        backgroundColor = AppColors.surface
        layer.cornerRadius = AppMetrics.radiusSM
        layer.borderWidth = 1
        layer.borderColor = AppColors.border.cgColor

        let calendar = UIImageView(image: UIImage(systemName: "calendar"))
        calendar.tintColor = AppColors.textSecondary
        calendar.contentMode = .scaleAspectFit
        calendar.forAutoLayout()

        let label = UILabel.make(text, font: AppFonts.regular(AppMetrics.textBodySM), color: AppColors.textPrimary)
        label.lineBreakMode = .byTruncatingTail
        label.forAutoLayout()

        let row = UIStackView.horizontal(spacing: 6, alignment: .center)
        row.isUserInteractionEnabled = false
        row.addArrangedSubview(calendar)
        row.addArrangedSubview(label)
        row.forAutoLayout()
        addSubview(row)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: AppMetrics.filterPillHeight),
            calendar.widthAnchor.constraint(equalToConstant: 16),
            calendar.heightAnchor.constraint(equalToConstant: 16),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            row.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Horizontal status tabs (Orders — New / Processing / Delivered)

final class ScrollStatusTabBar: UIView {
    private let scrollView = UIScrollView()
    private let stack = UIStackView.horizontal(spacing: 0, alignment: .center)
    private var labels: [UILabel] = []
    private var onSelect: ((Int) -> Void)?

    init(titles: [String], selectedIndex: Int = 0, onSelect: @escaping (Int) -> Void) {
        super.init(frame: .zero)
        self.onSelect = onSelect
        backgroundColor = AppColors.surface
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.forAutoLayout()
        stack.forAutoLayout()
        addSubview(scrollView)
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -10),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor, constant: -14)
        ])
        stack.spacing = 20
        for (index, title) in titles.enumerated() {
            let label = UILabel.make(title, font: index == selectedIndex ? AppFonts.semibold(13) : AppFonts.medium(13),
                                     color: index == selectedIndex ? AppColors.purplePrimary : AppColors.textSecondary)
            label.isUserInteractionEnabled = true
            label.tag = index
            label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tabTapped(_:))))
            stack.addArrangedSubview(label)
            labels.append(label)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tabTapped(_ gesture: UITapGestureRecognizer) {
        guard let index = gesture.view?.tag else { return }
        for (i, label) in labels.enumerated() {
            let selected = i == index
            label.font = selected ? AppFonts.semibold(13) : AppFonts.medium(13)
            label.textColor = selected ? AppColors.purplePrimary : AppColors.textSecondary
        }
        onSelect?(index)
    }
}

// MARK: - Filter chips (Orders secondary filters)

final class ChipBarView: UIView {
    private let scrollView = UIScrollView()
    private let stack = UIStackView.horizontal(spacing: 8, alignment: .center)
    private var chips: [PaddingLabel] = []
    private var onSelect: ((Int) -> Void)?

    init(titles: [String], selectedIndex: Int = 0, onSelect: @escaping (Int) -> Void) {
        super.init(frame: .zero)
        self.onSelect = onSelect
        backgroundColor = AppColors.surface
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.forAutoLayout()
        stack.forAutoLayout()
        addSubview(scrollView)
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -10),
            stack.heightAnchor.constraint(equalToConstant: 32)
        ])
        for (index, title) in titles.enumerated() {
            let chip = PaddingLabel(insets: UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14))
            chip.text = title
            chip.font = index == selectedIndex ? AppFonts.semibold(12) : AppFonts.medium(12)
            chip.layer.cornerRadius = 16
            chip.layer.masksToBounds = true
            chip.textAlignment = .center
            chip.isUserInteractionEnabled = true
            chip.tag = index
            chip.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(chipTapped(_:))))
            styleChip(chip, selected: index == selectedIndex)
            stack.addArrangedSubview(chip)
            chips.append(chip)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func styleChip(_ chip: PaddingLabel, selected: Bool) {
        if selected {
            chip.textColor = .white
            chip.backgroundColor = AppColors.purplePrimary
            chip.layer.borderWidth = 1
            chip.layer.borderColor = AppColors.purplePrimary.cgColor
        } else {
            chip.textColor = AppColors.textSecondary
            chip.backgroundColor = AppColors.surface
            chip.layer.borderWidth = 1
            chip.layer.borderColor = AppColors.border.cgColor
        }
    }

    @objc private func chipTapped(_ gesture: UITapGestureRecognizer) {
        guard let index = gesture.view?.tag else { return }
        for (i, chip) in chips.enumerated() {
            chip.font = i == index ? AppFonts.semibold(12) : AppFonts.medium(12)
            styleChip(chip, selected: i == index)
        }
        onSelect?(index)
    }
}

// MARK: - Underline tabs (Inventory — All / Low Stock / Expired)

final class UnderlineTabBar: UIView {
    private var stacks: [(label: UILabel, indicator: UIView)] = []
    private var onSelect: ((Int) -> Void)?

    init(titles: [String], selectedIndex: Int = 0, onSelect: @escaping (Int) -> Void) {
        super.init(frame: .zero)
        self.onSelect = onSelect
        backgroundColor = AppColors.surface
        let row = UIStackView.horizontal(spacing: 0, alignment: .fill)
        row.distribution = .fillEqually
        row.forAutoLayout()
        addSubview(row)
        row.pinEdges(to: self, insets: UIEdgeInsets(top: 4, left: 8, bottom: 0, right: 8))

        for (index, title) in titles.enumerated() {
            let col = UIStackView.vertical(spacing: 0, alignment: .fill)
            let label = UILabel.make(title,
                                     font: index == selectedIndex ? AppFonts.semibold(AppMetrics.textBodySM) : AppFonts.medium(AppMetrics.textBodySM),
                                     color: index == selectedIndex ? AppColors.purplePrimary : AppColors.textSecondary)
            label.textAlignment = .center
            label.isUserInteractionEnabled = true
            label.tag = index
            label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tabTapped(_:))))
            let indicator = UIView()
            indicator.backgroundColor = AppColors.purplePrimary
            indicator.layer.cornerRadius = 1
            indicator.constrainHeight(2)
            indicator.isHidden = index != selectedIndex
            col.addArrangedSubview(label)
            col.addArrangedSubview(indicator)
            row.addArrangedSubview(col)
            stacks.append((label, indicator))
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tabTapped(_ gesture: UITapGestureRecognizer) {
        guard let index = gesture.view?.tag else { return }
        for (i, pair) in stacks.enumerated() {
            let selected = i == index
            pair.label.font = selected ? AppFonts.semibold(AppMetrics.textBodySM) : AppFonts.medium(AppMetrics.textBodySM)
            pair.label.textColor = selected ? AppColors.purplePrimary : AppColors.textSecondary
            pair.indicator.isHidden = !selected
        }
        onSelect?(index)
    }
}

// MARK: - White section wrapper (surface background blocks like Android)

enum ListScreenLayout {
    static func surfaceSection(_ views: [UIView], spacing: CGFloat = 0,
                               insets: UIEdgeInsets = .zero) -> UIView {
        let stack = UIStackView.vertical(spacing: spacing, alignment: .fill)
        views.forEach { stack.addArrangedSubview($0) }
        let wrapper = UIView()
        wrapper.backgroundColor = AppColors.surface
        stack.forAutoLayout()
        wrapper.addSubview(stack)
        stack.pinEdges(to: wrapper, insets: insets)
        return wrapper
    }

    static func hairline() -> UIView {
        let line = UIView()
        line.backgroundColor = AppColors.border
        line.constrainHeight(1)
        return line
    }
}

// MARK: - Filter pill (Stores / Traders area & segment dropdowns)

final class FilterPillButton: UIControl {
    let titleLabel = UILabel()

    init(title: String) {
        super.init(frame: .zero)
        backgroundColor = AppColors.surface
        layer.cornerRadius = AppMetrics.radiusSM
        layer.borderWidth = 1
        layer.borderColor = AppColors.border.cgColor

        titleLabel.text = title
        titleLabel.font = AppFonts.regular(AppMetrics.textBodySM)
        titleLabel.textColor = AppColors.textPrimary
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.forAutoLayout()

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = AppColors.textSecondary
        chevron.contentMode = .scaleAspectFit
        chevron.forAutoLayout()

        let row = UIStackView.horizontal(spacing: 4, alignment: .center)
        row.isUserInteractionEnabled = false
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(chevron)
        row.forAutoLayout()
        addSubview(row)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: AppMetrics.filterPillHeight),
            chevron.widthAnchor.constraint(equalToConstant: 14),
            chevron.heightAnchor.constraint(equalToConstant: 14),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            row.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setTitle(_ text: String) { titleLabel.text = text }
}

// MARK: - Segment container (Finances / Deliveries / Returns filters)

final class SegmentContainerView: UIView {
    private var labels: [UILabel] = []
    private var onSelect: ((Int) -> Void)?

    init(titles: [String], selectedIndex: Int = 0, onSelect: @escaping (Int) -> Void) {
        super.init(frame: .zero)
        self.onSelect = onSelect
        backgroundColor = AppColors.borderLight
        layer.cornerRadius = AppMetrics.radiusMD
        layer.masksToBounds = true

        let row = UIStackView.horizontal(spacing: 0, alignment: .fill)
        row.distribution = .fillEqually
        row.forAutoLayout()
        addSubview(row)
        row.pinEdges(to: self, insets: UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4))

        for (index, title) in titles.enumerated() {
            let label = UILabel.make(title,
                                     font: index == selectedIndex ? AppFonts.semibold(AppMetrics.textBodySM) : AppFonts.medium(AppMetrics.textBodySM),
                                     color: index == selectedIndex ? .white : AppColors.textSecondary,
                                     align: .center)
            label.layer.cornerRadius = AppMetrics.radiusMD - 2
            label.layer.masksToBounds = true
            label.backgroundColor = index == selectedIndex ? AppColors.purplePrimary : .clear
            label.isUserInteractionEnabled = true
            label.tag = index
            label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tabTapped(_:))))
            row.addArrangedSubview(label)
            labels.append(label)
        }
        constrainHeight(40)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tabTapped(_ gesture: UITapGestureRecognizer) {
        guard let index = gesture.view?.tag else { return }
        for (i, label) in labels.enumerated() {
            let selected = i == index
            label.font = selected ? AppFonts.semibold(AppMetrics.textBodySM) : AppFonts.medium(AppMetrics.textBodySM)
            label.textColor = selected ? .white : AppColors.textSecondary
            label.backgroundColor = selected ? AppColors.purplePrimary : .clear
        }
        onSelect?(index)
    }
}

enum FilterIconButton {
    static func make() -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "line.3.horizontal.decrease"), for: .normal)
        button.tintColor = AppColors.textSecondary
        button.backgroundColor = AppColors.surface
        button.layer.cornerRadius = AppMetrics.radiusSM
        button.layer.borderWidth = 1
        button.layer.borderColor = AppColors.border.cgColor
        button.forAutoLayout()
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 36),
            button.heightAnchor.constraint(equalToConstant: 36)
        ])
        return button
    }
}

// MARK: - Horizontal scroll segment tabs (Deliveries — All / In Transit / …)

final class ScrollSegmentBar: UIView {
    private let scrollView = UIScrollView()
    private let container = UIView()
    private var tabs: [UILabel] = []
    private var onSelect: ((Int) -> Void)?

    init(titles: [String], selectedIndex: Int = 0, onSelect: @escaping (Int) -> Void) {
        super.init(frame: .zero)
        self.onSelect = onSelect
        backgroundColor = AppColors.surface
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.forAutoLayout()
        container.forAutoLayout()
        container.backgroundColor = AppColors.borderLight
        container.layer.cornerRadius = AppMetrics.radiusMD
        container.layer.masksToBounds = true
        addSubview(scrollView)
        scrollView.addSubview(container)

        let row = UIStackView.horizontal(spacing: 0, alignment: .fill)
        row.forAutoLayout()
        container.addSubview(row)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            container.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            container.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            container.heightAnchor.constraint(equalToConstant: 40),
            row.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])

        for (index, title) in titles.enumerated() {
            let label = PaddingLabel(insets: UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14))
            label.text = title
            label.font = index == selectedIndex ? AppFonts.semibold(12) : AppFonts.medium(12)
            label.textAlignment = .center
            label.layer.cornerRadius = AppMetrics.radiusMD - 2
            label.layer.masksToBounds = true
            label.isUserInteractionEnabled = true
            label.tag = index
            label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tabTapped(_:))))
            styleTab(label, selected: index == selectedIndex)
            row.addArrangedSubview(label)
            tabs.append(label)
        }
        constrainHeight(52)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func styleTab(_ label: UILabel, selected: Bool) {
        if selected {
            label.textColor = .white
            label.backgroundColor = AppColors.purplePrimary
        } else {
            label.textColor = AppColors.textSecondary
            label.backgroundColor = .clear
        }
    }

    @objc private func tabTapped(_ gesture: UITapGestureRecognizer) {
        guard let index = gesture.view?.tag else { return }
        for (i, label) in tabs.enumerated() {
            label.font = i == index ? AppFonts.semibold(12) : AppFonts.medium(12)
            styleTab(label, selected: i == index)
        }
        onSelect?(index)
    }
}

// MARK: - Returns status tabs (Pending / Approved / Rejected — purple selected text)

final class ReturnStatusTabBar: UIView {
    private var labels: [UILabel] = []
    private var onSelect: ((Int) -> Void)?

    init(titles: [String], selectedIndex: Int = 0, onSelect: @escaping (Int) -> Void) {
        super.init(frame: .zero)
        self.onSelect = onSelect
        let row = UIStackView.horizontal(spacing: 0, alignment: .fill)
        row.distribution = .fillEqually
        row.forAutoLayout()
        addSubview(row)
        row.pinEdges(to: self, insets: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))

        for (index, title) in titles.enumerated() {
            let label = UILabel.make(title,
                                     font: index == selectedIndex ? AppFonts.semibold(14) : AppFonts.medium(14),
                                     color: index == selectedIndex ? AppColors.purplePrimary : AppColors.textSecondary,
                                     align: .center)
            label.isUserInteractionEnabled = true
            label.tag = index
            label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tabTapped(_:))))
            row.addArrangedSubview(label)
            labels.append(label)
        }
        constrainHeight(36)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tabTapped(_ gesture: UITapGestureRecognizer) {
        guard let index = gesture.view?.tag else { return }
        for (i, label) in labels.enumerated() {
            let selected = i == index
            label.font = selected ? AppFonts.semibold(14) : AppFonts.medium(14)
            label.textColor = selected ? AppColors.purplePrimary : AppColors.textSecondary
        }
        onSelect?(index)
    }
}

extension SearchFilterRowView {
    func bindFilterToast(from viewController: UIViewController) {
        filterButton.addAction(UIAction { [weak viewController] _ in
            guard let viewController else { return }
            let alert = UIAlertController(title: nil, message: S.filtersComingSoon, preferredStyle: .alert)
            viewController.present(alert, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { alert.dismiss(animated: true) }
        }, for: .touchUpInside)
    }
}

extension DateRangePillView {
    var rangeLabel: UILabel {
        subviews.compactMap { $0 as? UIStackView }.first?
            .arrangedSubviews.compactMap { $0 as? UILabel }.first ?? UILabel()
    }
}
