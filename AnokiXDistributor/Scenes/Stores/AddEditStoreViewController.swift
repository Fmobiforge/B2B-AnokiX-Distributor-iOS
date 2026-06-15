import UIKit
import GoogleMaps
import CoreLocation

/// Port of AddEditStoreActivity + activity_add_edit_store.xml. Two-step form:
/// Step 1 (store info, fulfillment, tags, timezone/currency, trading days) and
/// Step 2 (address search + Google Maps pin picker + shipping fields). Wired to
/// /stores/create + /stores/update and prefilled from /stores in edit mode.
final class AddEditStoreViewController: BaseSecondaryViewController, GMSMapViewDelegate {

    var onSaved: (() -> Void)?

    private weak var formScrollView: UIScrollView?

    private let storeId: String?
    private let storeName: String?
    private let listItem: StoreItem?
    private var isEditMode: Bool { !(storeId ?? "").isEmpty }

    override var screenTitle: String {
        isEditMode ? "Edit Store - \(storeName ?? "")" : S.addStore
    }

    // Step containers
    private let step1 = UIStackView.vertical(spacing: 12, alignment: .fill)
    private let step2 = UIStackView.vertical(spacing: 12, alignment: .fill)
    private let stepperLabel = UILabel.make(font: AppFonts.bold(12), color: AppColors.purplePrimary)

    // Step 1 fields
    private let statsRow = UIStackView.horizontal(spacing: 12, alignment: .fill)
    private let followerValue = UILabel.make("0", font: AppFonts.bold(18), color: AppColors.textPrimary)
    private let reviewValue = UILabel.make("0", font: AppFonts.bold(18), color: AppColors.textPrimary)
    private var clickCollect = true
    private var clickDeliver = true
    private let collectCard = UIView()
    private let deliverCard = UIView()
    private let nameField = UITextField()
    private let buildingField = UITextField()
    private let contactField = UITextField()
    private let vatField = UITextField()
    private let descriptionView = UITextView()
    private let timeZoneButton = UIButton(type: .system)
    private let currencyButton = UIButton(type: .system)
    private var tags: [String] = []
    private let tagField = UITextField()
    private let tagsStack = UIStackView.horizontal(spacing: 8, alignment: .center)
    private var tradingRows: [TradingRowViews] = []
    private let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    // Step 2 fields
    private let addressSearchField = UITextField()
    private let mapContainer = UIView()
    private lazy var mapView: GMSMapView = makeMapView()
    private let street1Field = UITextField()
    private let street2Field = UITextField()
    private let suburbField = UITextField()
    private let cityField = UITextField()
    private let stateField = UITextField()
    private let countryField = UITextField()
    private let postalField = UITextField()
    private let submitButton = UIButton(type: .system)

    // Data
    private var timezones: [BaseInfoData.Timezone] = []
    private var currencies: [BaseInfoData.Currency] = []
    private var selectedTimezoneIndex = 0
    private var selectedCurrencyIndex = 0
    private var pickedCoordinate: CLLocationCoordinate2D?
    private var storeMarker: GMSMarker?
    private var pendingTimeZone: String?
    private var pendingCurrencyId: String?
    private var didWireMapScroll = false

    init(storeId: String?, storeName: String?, listItem: StoreItem? = nil) {
        self.storeId = storeId
        self.storeName = storeName
        self.listItem = listItem
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func setupContent(in container: UIView) {
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.showsVerticalScrollIndicator = false
        scroll.forAutoLayout()
        container.addSubview(scroll)
        scroll.pinEdges(to: container)
        formScrollView = scroll

        let stack = UIStackView.vertical(spacing: 12, alignment: .fill)
        stack.forAutoLayout()
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32)
        ])

        // Stepper
        let stepperCard = UIView()
        stepperCard.backgroundColor = AppColors.surface
        let stepperInner = UIStackView.horizontal(spacing: 8, alignment: .center)
        stepperInner.forAutoLayout()
        stepperInner.addArrangedSubview(stepperLabel)
        stepperCard.addSubview(stepperInner)
        stepperInner.pinEdges(to: stepperCard, insets: UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4))
        stack.addArrangedSubview(stepperCard)

        buildStep1()
        buildStep2()
        stack.addArrangedSubview(step1)
        stack.addArrangedSubview(step2)
        showStep(0)
    }

    // MARK: Step 1

    private func buildStep1() {
        step1.addArrangedSubview(UILabel.headline("Store Information"))
        step1.addArrangedSubview(UILabel.make("Set fulfillment options and enter your store profile details.",
                                              font: AppFonts.regular(12), color: AppColors.textSecondary))

        // Followers / Reviews stats (edit mode only)
        statsRow.distribution = .fillEqually
        statsRow.addArrangedSubview(statCard(title: S.followersLabel, value: followerValue,
                                             icon: "ic_traders", bg: AppColors.infoBg, tint: AppColors.info))
        statsRow.addArrangedSubview(statCard(title: S.reviewsLabel, value: reviewValue,
                                             icon: "ic_chat", bg: AppColors.warningBg, tint: AppColors.warning))
        statsRow.isHidden = true
        step1.addArrangedSubview(statsRow)

        // Fulfillment cards
        let fulfillmentRow = UIStackView.horizontal(spacing: 12, alignment: .fill)
        fulfillmentRow.distribution = .fillEqually
        configureFulfillmentCard(collectCard, title: "Click & Collect", subtitle: "Customers pick up orders at your store")
        configureFulfillmentCard(deliverCard, title: "Click & Deliver", subtitle: "Deliver orders to customer addresses")
        collectCard.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleCollect)))
        deliverCard.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleDeliver)))
        fulfillmentRow.addArrangedSubview(collectCard)
        fulfillmentRow.addArrangedSubview(deliverCard)
        step1.addArrangedSubview(fulfillmentRow)

        step1.addArrangedSubview(fieldGroup("Store Name", nameField))
        step1.addArrangedSubview(fieldGroup("Building Number", buildingField))
        step1.addArrangedSubview(fieldGroup("Contact Number of your store", contactField))
        step1.addArrangedSubview(fieldGroup("VAT Number", vatField))

        // Description
        step1.addArrangedSubview(UILabel.make("Store Description", font: AppFonts.regular(13), color: AppColors.textPrimary))
        descriptionView.font = AppFonts.regular(14)
        descriptionView.textColor = AppColors.textPrimary
        descriptionView.layer.cornerRadius = AppMetrics.radiusMD
        descriptionView.layer.borderWidth = 1
        descriptionView.layer.borderColor = AppColors.border.cgColor
        descriptionView.constrainHeight(90)
        step1.addArrangedSubview(descriptionView)

        // Time Zone + Currency pickers
        configurePickerButton(timeZoneButton, placeholder: "Select time zone")
        timeZoneButton.addTarget(self, action: #selector(pickTimezone), for: .touchUpInside)
        step1.addArrangedSubview(pickerGroup("Time Zone", timeZoneButton))

        configurePickerButton(currencyButton, placeholder: "select a currency")
        currencyButton.addTarget(self, action: #selector(pickCurrency), for: .touchUpInside)
        step1.addArrangedSubview(pickerGroup("Currency", currencyButton))

        step1.addArrangedSubview(buildTagsSection())
        step1.addArrangedSubview(buildTradingSection())

        // Next button
        let next = UIButton(type: .system)
        next.setTitle("Next", for: .normal)
        StyleKit.stylePrimaryButton(next)
        next.constrainHeight(48)
        next.addTarget(self, action: #selector(goNext), for: .touchUpInside)
        step1.addArrangedSubview(next)
    }

    // MARK: Step 2

    private func buildStep2() {
        step2.addArrangedSubview(UILabel.headline("Address & Shipping"))
        step2.addArrangedSubview(UILabel.make("Pin your store on the map and complete shipping address details.",
                                              font: AppFonts.regular(12), color: AppColors.textSecondary))
        step2.addArrangedSubview(fieldGroup("Address of your store", addressSearchField))

        mapContainer.forAutoLayout()
        mapContainer.constrainHeight(AppMetrics.storeMapHeight)
        mapContainer.setContentCompressionResistancePriority(.required, for: .vertical)
        mapContainer.setContentHuggingPriority(.defaultHigh, for: .vertical)

        mapView.forAutoLayout()
        mapContainer.addSubview(mapView)
        mapView.pinEdges(to: mapContainer)
        step2.addArrangedSubview(mapContainer)
        step2.addArrangedSubview(UILabel.make("Tap the map to drop a pin, or drag the pin to set your store location.",
                                              font: AppFonts.light(10), color: AppColors.textSecondary))

        step2.addArrangedSubview(fieldGroup("Street 1*", street1Field))
        step2.addArrangedSubview(fieldGroup("Street 2 (optional)", street2Field))
        step2.addArrangedSubview(fieldGroup("Suburb*", suburbField))
        step2.addArrangedSubview(fieldGroup("City*", cityField))
        step2.addArrangedSubview(fieldGroup("State/Province*", stateField))
        step2.addArrangedSubview(fieldGroup("Country*", countryField))
        step2.addArrangedSubview(fieldGroup("Postal Code*", postalField))

        let back = UIButton(type: .system)
        back.setTitle("Back", for: .normal)
        StyleKit.styleOutlinedButton(back)
        back.constrainHeight(48)
        back.addTarget(self, action: #selector(goBack), for: .touchUpInside)

        submitButton.setTitle(isEditMode ? "Update" : "Create", for: .normal)
        StyleKit.stylePrimaryButton(submitButton)
        submitButton.constrainHeight(48)
        submitButton.addTarget(self, action: #selector(submit), for: .touchUpInside)

        let buttonRow = UIStackView.horizontal(spacing: 12, alignment: .fill)
        buttonRow.distribution = .fillEqually
        buttonRow.addArrangedSubview(back)
        buttonRow.addArrangedSubview(submitButton)
        step2.addArrangedSubview(buttonRow)
    }

    override func loadData() {
        prefillFromListItem()
        loadBaseInfo()
        if isEditMode, let id = storeId { loadStore(id) }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didWireMapScroll else { return }
        didWireMapScroll = true
        wireMapScrollBehavior()
    }

    /// Show list-row data immediately while the detail API loads (matches Android UX).
    private func prefillFromListItem() {
        guard let item = listItem else { return }
        statsRow.isHidden = false
        followerValue.text = "\(item.followerCount)"
        reviewValue.text = "\(item.reviewCount)"
        nameField.text = item.name
        addressSearchField.text = item.address
        header?.setTitle("Edit Store - \(item.name)")
    }

    // MARK: Networking

    private func loadBaseInfo() {
        ApiClient.shared.getBaseInfo { [weak self] result in
            guard let self = self, case .success(let data) = result else { return }
            self.timezones = data.timezones ?? []
            self.currencies = [BaseInfoData.Currency(id: nil, code: nil, name: nil, symbol: nil)] + (data.currencies ?? [])
            self.applyPendingSelections()
        }
    }

    private func loadStore(_ id: String) {
        ApiClient.shared.getStore(id: id) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                guard let store = data.store else {
                    self.toast("Store details unavailable")
                    return
                }
                self.prefill(store)
            case .failure(let error):
                self.toast(error.message)
            }
        }
    }

    private func prefill(_ s: StoreDetailData.Store) {
        if let name = s.name, !name.isEmpty {
            header?.setTitle("Edit Store - \(name)")
        }
        statsRow.isHidden = false
        followerValue.text = "\(s.followerCount ?? listItem?.followerCount ?? 0)"
        reviewValue.text = "\(s.reviewCount ?? listItem?.reviewCount ?? 0)"
        nameField.text = s.name
        buildingField.text = s.buildingNumber
        contactField.text = s.contactNumber
        vatField.text = s.vatNumber
        descriptionView.text = s.storeDescription
        addressSearchField.text = s.street ?? s.address
        street1Field.text = s.addressStreet1
        street2Field.text = s.addressStreet2
        suburbField.text = s.addressSuburb
        cityField.text = s.addressCity
        stateField.text = s.addressState
        countryField.text = s.addressCountry
        postalField.text = s.addressPostalCode
        clickCollect = s.isClickCollect ?? true
        clickDeliver = s.isClickDeliver ?? true
        applyFulfillment()
        pendingTimeZone = s.timeZone
        pendingCurrencyId = s.currencyId
        applyPendingSelections()

        if let tagList = s.tagList, !tagList.trimmingCharacters(in: .whitespaces).isEmpty {
            for part in tagList.split(separator: ",") {
                let tag = part.trimmingCharacters(in: .whitespaces)
                if !tag.isEmpty && !tags.contains(tag) { tags.append(tag) }
            }
            renderTags()
        }
        parseTradingTime(s.tradingTime)
        if let lat = s.latitude, let lng = s.longitude {
            placePin(at: CLLocationCoordinate2D(latitude: lat, longitude: lng), zoom: true)
        }
    }

    private func applyPendingSelections() {
        if let tz = pendingTimeZone, let idx = timezones.firstIndex(where: { $0.timeZone == tz }) {
            selectedTimezoneIndex = idx
        }
        if !timezones.isEmpty {
            setPickerTitle(timeZoneButton, tzLabel(timezones[selectedTimezoneIndex]))
        }
        if let cid = pendingCurrencyId, let idx = currencies.firstIndex(where: { $0.id == cid }) {
            selectedCurrencyIndex = idx
        }
        if !currencies.isEmpty {
            setPickerTitle(currencyButton, currencyLabel(currencies[selectedCurrencyIndex]))
        }
    }

    private func setPickerTitle(_ button: UIButton, _ title: String) {
        guard var config = button.configuration else { return }
        config.title = title
        button.configuration = config
    }

    @objc private func submit() {
        let name = nameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !name.isEmpty else { showStep(0); toast("Store name is required"); return }

        var form: [String: String] = [:]
        if isEditMode, let id = storeId { form["id"] = id }
        form["name"] = name
        form["building_number"] = text(buildingField)
        form["contact_number"] = text(contactField)
        form["vat_number"] = text(vatField)
        form["description"] = descriptionView.text ?? ""
        form["is_click_collect"] = clickCollect ? "1" : "0"
        form["is_click_deliver"] = clickDeliver ? "1" : "0"
        form["street"] = text(addressSearchField)
        form["address_street1"] = text(street1Field)
        form["address_street2"] = text(street2Field)
        form["address_suburb"] = text(suburbField)
        form["address_city"] = text(cityField)
        form["address_state"] = text(stateField)
        form["address_country"] = text(countryField)
        form["address_postal_code"] = text(postalField)
        if timezones.indices.contains(selectedTimezoneIndex) {
            let tz = timezones[selectedTimezoneIndex]
            form["time_zone"] = tz.timeZone ?? ""
            form["time_offset"] = String(tz.timeOffset ?? 0)
        }
        if currencies.indices.contains(selectedCurrencyIndex), let id = currencies[selectedCurrencyIndex].id {
            form["currency_id"] = id
        }
        if let coord = pickedCoordinate {
            form["latitude"] = String(coord.latitude)
            form["longitude"] = String(coord.longitude)
        }
        form["tag_list"] = tags.joined(separator: ",")
        form["trading_time"] = buildTradingTime()
        form["working_days"] = buildWorkingDays()

        submitButton.isEnabled = false
        let handler: (Result<StoreDetailData, ApiError>) -> Void = { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.toast(self.isEditMode ? "Store updated successfully" : "Store created successfully")
                self.onSaved?()
                self.navigationController?.popViewController(animated: true)
            case .failure(let error):
                self.submitButton.isEnabled = true
                self.toast(error.message)
            }
        }
        isEditMode ? ApiClient.shared.updateStore(form: form, completion: handler)
                   : ApiClient.shared.createStore(form: form, completion: handler)
    }

    // MARK: Map (Google Maps — same as Android AddEditStoreActivity)

    private func makeMapView() -> GMSMapView {
        let durban = CLLocationCoordinate2D(latitude: -29.8587, longitude: 31.0218)
        let camera = GMSCameraPosition.camera(withTarget: durban, zoom: 9)
        let map = GMSMapView(frame: .zero, camera: camera)
        map.delegate = self
        map.layer.cornerRadius = AppMetrics.radiusMD
        map.clipsToBounds = true
        map.settings.zoomGestures = true
        map.settings.scrollGestures = true
        map.settings.rotateGestures = false
        map.settings.tiltGestures = false
        map.settings.compassButton = false
        map.settings.myLocationButton = false
        return map
    }

    /// Let the map pan/zoom without the form scroll view stealing the gesture (Android parity).
    private func wireMapScrollBehavior() {
        guard formScrollView != nil else { return }
        mapView.isExclusiveTouch = true
        for recognizer in mapView.gestureRecognizers ?? [] {
            recognizer.cancelsTouchesInView = false
            recognizer.addTarget(self, action: #selector(mapGestureChanged(_:)))
        }
    }

    @objc private func mapGestureChanged(_ recognizer: UIGestureRecognizer) {
        guard let scroll = formScrollView else { return }
        switch recognizer.state {
        case .began, .changed:
            scroll.isScrollEnabled = false
        default:
            scroll.isScrollEnabled = true
        }
    }

    func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
        placePin(at: coordinate, zoom: false)
    }

    func mapView(_ mapView: GMSMapView, didEndDragging marker: GMSMarker) {
        pickedCoordinate = marker.position
        reverseGeocode(marker.position)
    }

    private func placePin(at coord: CLLocationCoordinate2D, zoom: Bool) {
        pickedCoordinate = coord
        if storeMarker == nil {
            let pin = GMSMarker(position: coord)
            pin.isDraggable = true
            pin.map = mapView
            storeMarker = pin
        } else {
            storeMarker?.position = coord
        }
        if zoom {
            mapView.animate(to: GMSCameraPosition.camera(withTarget: coord, zoom: 15))
        }
        reverseGeocode(coord)
    }

    private func reverseGeocode(_ coord: CLLocationCoordinate2D) {
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: coord.latitude, longitude: coord.longitude)) { [weak self] placemarks, _ in
            guard let self = self, let p = placemarks?.first else { return }
            if let line = p.name { self.addressSearchField.text = line }
            if let s = p.thoroughfare { self.street1Field.text = s }
            if let sub = p.subLocality { self.suburbField.text = sub }
            if let city = p.locality { self.cityField.text = city }
            if let state = p.administrativeArea { self.stateField.text = state }
            if let country = p.country { self.countryField.text = country }
            if let postal = p.postalCode { self.postalField.text = postal }
        }
    }

    // MARK: Step navigation + fulfillment

    @objc private func goNext() { showStep(1) }
    @objc private func goBack() { showStep(0) }

    private func showStep(_ index: Int) {
        step1.isHidden = index != 0
        step2.isHidden = index != 1
        stepperLabel.text = index == 0 ? "Step 1 of 2 — Store Information" : "Step 2 of 2 — Address & Shipping"
    }

    @objc private func toggleCollect() { clickCollect.toggle(); applyFulfillment() }
    @objc private func toggleDeliver() { clickDeliver.toggle(); applyFulfillment() }

    private func applyFulfillment() {
        styleFulfillment(collectCard, selected: clickCollect)
        styleFulfillment(deliverCard, selected: clickDeliver)
    }

    private func styleFulfillment(_ card: UIView, selected: Bool) {
        card.layer.borderColor = (selected ? AppColors.purplePrimary : AppColors.border).cgColor
        card.backgroundColor = selected ? AppColors.purpleLight.withAlphaComponent(0.35) : AppColors.surface
    }

    // MARK: Pickers

    @objc private func pickTimezone() {
        presentPicker(title: "Time Zone", options: timezones.map { tzLabel($0) }) { [weak self] idx in
            self?.selectedTimezoneIndex = idx
            self?.setPickerTitle(self!.timeZoneButton, self!.tzLabel(self!.timezones[idx]))
        }
    }
    @objc private func pickCurrency() {
        presentPicker(title: "Currency", options: currencies.map { currencyLabel($0) }) { [weak self] idx in
            self?.selectedCurrencyIndex = idx
            self?.setPickerTitle(self!.currencyButton, self!.currencyLabel(self!.currencies[idx]))
        }
    }

    private func presentPicker(title: String, options: [String], onPick: @escaping (Int) -> Void) {
        guard !options.isEmpty else { return }
        let sheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for (idx, option) in options.enumerated() {
            sheet.addAction(UIAlertAction(title: option, style: .default) { _ in onPick(idx) })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }

    private func tzLabel(_ tz: BaseInfoData.Timezone) -> String {
        let hours = (tz.timeOffset ?? 0) / 3600
        let sign = hours >= 0 ? "+" : ""
        return "\(tz.name ?? "") (GMT\(sign)\(hours))"
    }
    private func currencyLabel(_ c: BaseInfoData.Currency) -> String {
        guard let code = c.code else { return "select a currency" }
        return "\(code) - \(c.name ?? "")"
    }

    // MARK: Tags

    private func buildTagsSection() -> UIView {
        let label = UILabel.make("Tags", font: AppFonts.regular(13), color: AppColors.textPrimary)
        StyleKit.styleInput(tagField)
        tagField.placeholder = "Type a tag name"
        tagField.returnKeyType = .done
        tagField.addTarget(self, action: #selector(commitTag), for: .editingDidEndOnExit)
        let help = UILabel.make("Press Enter to add a tag. Separate multiple tags with commas.",
                                font: AppFonts.light(10), color: AppColors.textSecondary, lines: 0)

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        tagsStack.forAutoLayout()
        scroll.addSubview(tagsStack)
        tagsStack.pinEdges(to: scroll)
        tagsStack.heightAnchor.constraint(equalTo: scroll.heightAnchor).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 32).isActive = true

        let stack = UIStackView.vertical(spacing: 5, alignment: .fill)
        [label, tagField, help, scroll].forEach { stack.addArrangedSubview($0) }
        return stack
    }

    @objc private func commitTag() {
        let raw = tagField.text ?? ""
        for part in raw.split(separator: ",") {
            let tag = part.trimmingCharacters(in: .whitespaces)
            if !tag.isEmpty && !tags.contains(tag) { tags.append(tag) }
        }
        tagField.text = ""
        renderTags()
    }

    private func renderTags() {
        tagsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for tag in tags {
            tagsStack.addArrangedSubview(makeChip(tag))
        }
    }

    private func makeChip(_ tag: String) -> UIView {
        let chip = UIView()
        chip.backgroundColor = AppColors.purpleLight
        chip.layer.cornerRadius = AppMetrics.radiusSM
        let label = UILabel.make(tag, font: AppFonts.medium(11), color: AppColors.purplePrimary)
        let remove = UIButton(type: .system)
        remove.setImage(UIImage(systemName: "xmark"), for: .normal)
        remove.tintColor = AppColors.purplePrimary
        remove.constrainSize(14)
        remove.addAction(UIAction { [weak self] _ in
            self?.tags.removeAll { $0 == tag }
            self?.renderTags()
        }, for: .touchUpInside)
        let row = UIStackView.horizontal(spacing: 6, alignment: .center)
        row.forAutoLayout()
        row.addArrangedSubview(label)
        row.addArrangedSubview(remove)
        chip.addSubview(row)
        row.pinEdges(to: chip, insets: UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 8))
        return chip
    }

    // MARK: Trading days & times

    private func buildTradingSection() -> UIView {
        let label = UILabel.make("Trading Days and Times", font: AppFonts.regular(13), color: AppColors.textPrimary)

        let container = UIStackView.vertical(spacing: 6, alignment: .fill)
        container.backgroundColor = AppColors.surface
        container.isLayoutMarginsRelativeArrangement = true
        container.layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        container.layer.cornerRadius = AppMetrics.radiusMD
        container.layer.borderWidth = 1
        container.layer.borderColor = AppColors.border.cgColor

        container.addArrangedSubview(tradingHeaderRow())
        tradingRows = []
        for i in 0..<7 {
            let row = TradingRowViews(day: dayLabels[i])
            tradingRows.append(row)
            container.addArrangedSubview(row.view)
        }

        let stack = UIStackView.vertical(spacing: 6, alignment: .fill)
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(container)
        return stack
    }

    private func tradingHeaderRow() -> UIView {
        let row = UIStackView.horizontal(spacing: 6, alignment: .center)
        let day = UILabel.make("DAY", font: AppFonts.regular(9), color: AppColors.textSecondary, align: .center)
        day.widthAnchor.constraint(equalToConstant: 84).isActive = true
        row.addArrangedSubview(day)
        let cells = UIStackView.horizontal(spacing: 6, alignment: .center)
        cells.distribution = .fillEqually
        ["OPEN", "CLOSE", "OPEN", "CLOSE"].forEach {
            cells.addArrangedSubview(UILabel.make($0, font: AppFonts.regular(9), color: AppColors.textSecondary, align: .center))
        }
        row.addArrangedSubview(cells)
        return row
    }

    private func buildTradingTime() -> String {
        var parts: [String] = []
        for (i, row) in tradingRows.enumerated() {
            guard row.isOn else { continue }
            let o1 = row.text(row.open1), c1 = row.text(row.close1)
            if o1.isEmpty || c1.isEmpty { continue }
            var day = "\(i):\(o1).00-\(c1)"
            let o2 = row.text(row.open2), c2 = row.text(row.close2)
            if !o2.isEmpty && !c2.isEmpty { day += ",\(o2)-\(c2)" }
            parts.append(day)
        }
        return parts.joined(separator: "/")
    }

    private func buildWorkingDays() -> String {
        var result = ""
        for (i, row) in tradingRows.enumerated() where row.isOn { result += "\(i)" }
        return result
    }

    private func parseTradingTime(_ tradingTime: String?) {
        guard let tt = tradingTime, !tt.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        for part in tt.split(separator: "/") {
            let kv = part.split(separator: ":", maxSplits: 1).map(String.init)
            guard kv.count >= 2,
                  let idx = Int(kv[0].trimmingCharacters(in: .whitespaces)),
                  tradingRows.indices.contains(idx) else { continue }
            let row = tradingRows[idx]
            row.setChecked(true)
            let ranges = kv[1].components(separatedBy: ",")
            fillRange(ranges.count > 0 ? ranges[0] : "", row.open1, row.close1)
            fillRange(ranges.count > 1 ? ranges[1] : "", row.open2, row.close2)
        }
    }

    private func fillRange(_ range: String, _ open: UITextField, _ close: UITextField) {
        let trimmed = range.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let oc = trimmed.components(separatedBy: "-")
        if oc.count >= 1 { open.text = cleanHour(oc[0]) }
        if oc.count >= 2 { close.text = cleanHour(oc[1]) }
    }

    private func cleanHour(_ value: String) -> String {
        let v = value.trimmingCharacters(in: .whitespaces)
        if let dot = v.firstIndex(of: ".") { return String(v[..<dot]) }
        return v
    }

    // MARK: View builders

    private func statCard(title: String, value: UILabel, icon: String, bg: UIColor, tint: UIColor) -> UIView {
        let card = StyleKit.cardView()
        let tile = StyleKit.iconTile(color: bg)
        tile.constrainSize(36)
        let iconView = UIImageView(image: AppIcons.symbol(icon))
        iconView.tintColor = tint
        iconView.contentMode = .scaleAspectFit
        iconView.forAutoLayout()
        tile.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20)
        ])
        let label = UILabel.make(title, font: AppFonts.regular(12), color: AppColors.textSecondary)
        let textStack = UIStackView.vertical(spacing: 0, alignment: .leading)
        textStack.addArrangedSubview(value)
        textStack.addArrangedSubview(label)
        let row = UIStackView.horizontal(spacing: 10, alignment: .center)
        row.forAutoLayout()
        row.addArrangedSubview(tile)
        row.addArrangedSubview(textStack)
        card.addSubview(row)
        row.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        return card
    }

    private func configureFulfillmentCard(_ card: UIView, title: String, subtitle: String) {
        card.layer.cornerRadius = AppMetrics.radiusMD
        card.layer.borderWidth = 1
        card.isUserInteractionEnabled = true
        let titleLabel = UILabel.make(title, font: AppFonts.bold(12), color: AppColors.textPrimary)
        let subLabel = UILabel.make(subtitle, font: AppFonts.light(10), color: AppColors.textSecondary, lines: 2)
        let stack = UIStackView.vertical(spacing: 4, alignment: .leading)
        stack.forAutoLayout()
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subLabel)
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        styleFulfillment(card, selected: true)
    }

    private func fieldGroup(_ label: String, _ field: UITextField) -> UIStackView {
        StyleKit.styleInput(field)
        let title = UILabel.make(label, font: AppFonts.regular(13), color: AppColors.textPrimary)
        let stack = UIStackView.vertical(spacing: 5, alignment: .fill)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(field)
        return stack
    }

    private func pickerGroup(_ label: String, _ button: UIButton) -> UIStackView {
        let title = UILabel.make(label, font: AppFonts.regular(13), color: AppColors.textPrimary)
        let stack = UIStackView.vertical(spacing: 5, alignment: .fill)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(button)
        return stack
    }

    private func configurePickerButton(_ button: UIButton, placeholder: String) {
        var config = UIButton.Configuration.bordered()
        config.baseForegroundColor = AppColors.textPrimary
        config.background.strokeColor = AppColors.border
        config.background.backgroundColor = AppColors.surface
        config.cornerStyle = .medium
        config.title = placeholder
        config.image = UIImage(systemName: "chevron.down")
        config.imagePlacement = .trailing
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            pointSize: AppMetrics.textBodySM, weight: .regular)
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = AppFonts.regular(AppMetrics.textBody)
            return outgoing
        }
        button.configuration = config
        button.contentHorizontalAlignment = .leading
        button.constrainHeight(48)
    }

    private func text(_ field: UITextField) -> String {
        field.text?.trimmingCharacters(in: .whitespaces) ?? ""
    }
}

/// One row of the trading-days grid: a checkbox + day label and four hour fields
/// (open/close, open/close), mirroring buildTradingRows() in AddEditStoreActivity.
final class TradingRowViews {
    let view = UIStackView.horizontal(spacing: 6, alignment: .center)
    private let checkbox = UIButton(type: .system)
    let open1 = TradingRowViews.hourField()
    let close1 = TradingRowViews.hourField()
    let open2 = TradingRowViews.hourField()
    let close2 = TradingRowViews.hourField()

    var isOn: Bool { checkbox.isSelected }

    init(day: String) {
        var config = UIButton.Configuration.plain()
        config.background.backgroundColor = .clear
        config.contentInsets = .zero
        checkbox.configuration = config
        checkbox.constrainSize(22)
        applyCheckboxAppearance(checked: false)
        checkbox.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.applyCheckboxAppearance(checked: !self.checkbox.isSelected)
        }, for: .touchUpInside)

        let label = UILabel.make(day, font: AppFonts.regular(11), color: AppColors.textPrimary)
        let dayCol = UIStackView.horizontal(spacing: 4, alignment: .center)
        dayCol.addArrangedSubview(checkbox)
        dayCol.addArrangedSubview(label)
        dayCol.widthAnchor.constraint(equalToConstant: 84).isActive = true

        let cells = UIStackView.horizontal(spacing: 6, alignment: .center)
        cells.distribution = .fillEqually
        [open1, close1, open2, close2].forEach { cells.addArrangedSubview($0) }

        view.addArrangedSubview(dayCol)
        view.addArrangedSubview(cells)
    }

    func setChecked(_ on: Bool) {
        applyCheckboxAppearance(checked: on)
    }

    private func applyCheckboxAppearance(checked: Bool) {
        checkbox.isSelected = checked
        let symbol = checked ? "checkmark.square" : "square"
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        checkbox.setImage(UIImage(systemName: symbol, withConfiguration: imageConfig), for: .normal)
        checkbox.tintColor = checked ? AppColors.purplePrimary : AppColors.textSecondary
    }

    func text(_ field: UITextField) -> String {
        field.text?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    private static func hourField() -> UITextField {
        let field = UITextField()
        field.keyboardType = .numberPad
        field.textAlignment = .center
        field.font = AppFonts.regular(12)
        field.textColor = AppColors.textPrimary
        field.placeholder = "—"
        field.backgroundColor = AppColors.surface
        field.layer.cornerRadius = AppMetrics.radiusSM
        field.layer.borderWidth = 1
        field.layer.borderColor = AppColors.border.cgColor
        field.heightAnchor.constraint(equalToConstant: 34).isActive = true
        return field
    }
}
