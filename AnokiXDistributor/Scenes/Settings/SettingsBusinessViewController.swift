import UIKit
import GoogleMaps
import CoreLocation

final class SettingsBusinessViewController: BaseSettingsFormViewController,
    GMSMapViewDelegate, UITableViewDataSource, UITableViewDelegate {

    override var screenTitle: String { S.settingsBusinessTitle }
    override var screenSubtitle: String? { S.settingsBusinessSub }

    private let businessNameField = UITextField()
    private let registrationField = UITextField()
    private let vatField = UITextField()
    private let addressField = UITextField()
    private let cityField = UITextField()
    private let addressResultsTable = UITableView(frame: .zero, style: .plain)
    private var addressResultsHeight: NSLayoutConstraint!
    private lazy var mapView: GMSMapView = makeMapView()

    private var predictions: [AutocompleteData.Prediction] = []
    private var pickedCoordinate: CLLocationCoordinate2D?
    private var marker: GMSMarker?
    private var suppressAddressChange = false
    private var autocompleteWorkItem: DispatchWorkItem?

    override func setupForm(in card: UIView) {
        addressField.addTarget(self, action: #selector(addressChanged), for: .editingChanged)
        addressResultsTable.dataSource = self
        addressResultsTable.delegate = self
        addressResultsTable.isHidden = true
        addressResultsTable.layer.cornerRadius = AppMetrics.radiusMD
        addressResultsTable.layer.borderWidth = 1
        addressResultsTable.layer.borderColor = AppColors.border.cgColor
        addressResultsTable.register(UITableViewCell.self, forCellReuseIdentifier: "pred")
        addressResultsHeight = addressResultsTable.heightAnchor.constraint(equalToConstant: 0)
        mapView.heightAnchor.constraint(equalToConstant: 220).isActive = true
        wireMapScrollBehavior()

        let stack = UIStackView.vertical(spacing: 0, alignment: .fill)
        stack.addArrangedSubview(settingsFieldGroup(S.businessNameReq, businessNameField, placeholder: ""))
        stack.addArrangedSubview(settingsFieldGroup(S.registrationNumberLabel, registrationField, placeholder: ""))
        stack.addArrangedSubview(settingsFieldGroup(S.vatNumberLabel, vatField, placeholder: ""))
        stack.addArrangedSubview(settingsFieldGroup(S.addressOfBusiness, addressField, placeholder: S.searchAddressHint))
        stack.addArrangedSubview(addressResultsTable)
        stack.addArrangedSubview(UILabel.make(S.mapPinHintTrader,
                                              font: AppFonts.regular(12), color: AppColors.textSecondary, lines: 0))
        stack.setCustomSpacing(12, after: addressResultsTable)
        stack.addArrangedSubview(mapView)
        stack.setCustomSpacing(12, after: mapView)
        stack.addArrangedSubview(settingsFieldGroup(S.cityLabel, cityField, placeholder: S.cityHint))

        stack.forAutoLayout()
        card.addSubview(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        NSLayoutConstraint.activate([addressResultsHeight])
    }

    override func loadData() {
        let data = repository.getBusinessSettings()
        businessNameField.text = data.businessName
        registrationField.text = data.registrationNumber
        vatField.text = data.vatNumber
        setAddressText(data.address)
        cityField.text = data.city
        if let lat = data.latitude, let lng = data.longitude {
            pickedCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            placePin(at: pickedCoordinate!, zoom: true)
        }
    }

    override func onSave() {
        let businessName = businessNameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        if businessName.isEmpty { toast(S.errBusinessName); return }

        repository.saveBusinessSettings(BusinessSettings(
            businessName: businessName,
            registrationNumber: registrationField.text?.trimmingCharacters(in: .whitespaces) ?? "",
            vatNumber: vatField.text?.trimmingCharacters(in: .whitespaces) ?? "",
            address: addressField.text?.trimmingCharacters(in: .whitespaces) ?? "",
            city: cityField.text?.trimmingCharacters(in: .whitespaces) ?? "",
            latitude: pickedCoordinate?.latitude,
            longitude: pickedCoordinate?.longitude
        ))
        settingsSavedToast()
        navigationController?.popViewController(animated: true)
    }

    @objc private func addressChanged() {
        guard !suppressAddressChange else { return }
        let keyword = addressField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        autocompleteWorkItem?.cancel()
        guard keyword.count >= 3 else { hideAddressResults(); return }
        let work = DispatchWorkItem { [weak self] in self?.queryAutocomplete(keyword) }
        autocompleteWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func queryAutocomplete(_ keyword: String) {
        ApiClient.shared.getAddressAutocomplete(keyword: keyword) { [weak self] result in
            guard let self = self, case .success(let data) = result else { return }
            self.predictions = data.predictions ?? []
            if self.predictions.isEmpty { self.hideAddressResults() }
            else {
                self.addressResultsTable.isHidden = false
                self.addressResultsHeight.constant = CGFloat(min(self.predictions.count, 5)) * 44
                self.addressResultsTable.reloadData()
            }
        }
    }

    private func hideAddressResults() {
        predictions = []
        addressResultsTable.isHidden = true
        addressResultsHeight.constant = 0
    }

    private func setAddressText(_ value: String) {
        suppressAddressChange = true
        addressField.text = value
        suppressAddressChange = false
    }

    private func makeMapView() -> GMSMapView {
        let sa = CLLocationCoordinate2D(latitude: -29.8587, longitude: 31.0218)
        let camera = GMSCameraPosition.camera(withTarget: sa, zoom: 9)
        let map = GMSMapView(frame: .zero, camera: camera)
        map.delegate = self
        map.layer.cornerRadius = AppMetrics.radiusMD
        map.clipsToBounds = true
        map.settings.zoomGestures = true
        map.settings.scrollGestures = true
        map.settings.compassButton = false
        return map
    }

    private func wireMapScrollBehavior() {
        mapView.isExclusiveTouch = true
        for recognizer in mapView.gestureRecognizers ?? [] {
            recognizer.cancelsTouchesInView = false
            recognizer.addTarget(self, action: #selector(mapGestureChanged(_:)))
        }
    }

    @objc private func mapGestureChanged(_ recognizer: UIGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed: formScroll.isScrollEnabled = false
        default: formScroll.isScrollEnabled = true
        }
    }

    func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
        placePin(at: coordinate, zoom: false)
        reverseGeocode(coordinate)
    }

    func mapView(_ mapView: GMSMapView, didEndDragging marker: GMSMarker) {
        pickedCoordinate = marker.position
        reverseGeocode(marker.position)
    }

    private func placePin(at coord: CLLocationCoordinate2D, zoom: Bool) {
        pickedCoordinate = coord
        if marker == nil {
            let pin = GMSMarker(position: coord)
            pin.isDraggable = true
            pin.map = mapView
            marker = pin
        } else {
            marker?.position = coord
        }
        if zoom { mapView.animate(to: GMSCameraPosition.camera(withTarget: coord, zoom: 15)) }
    }

    private func reverseGeocode(_ coord: CLLocationCoordinate2D) {
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: coord.latitude, longitude: coord.longitude)) { [weak self] placemarks, _ in
            guard let self = self, let p = placemarks?.first else { return }
            let line = [p.name, p.locality, p.country].compactMap { $0 }.joined(separator: ", ")
            if !line.isEmpty { self.setAddressText(line) }
            if let city = p.locality { self.cityField.text = city }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { predictions.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "pred", for: indexPath)
        cell.textLabel?.text = predictions[indexPath.row].description
        cell.textLabel?.font = AppFonts.regular(13)
        cell.textLabel?.numberOfLines = 2
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let prediction = predictions[indexPath.row]
        if let desc = prediction.description { setAddressText(desc) }
        hideAddressResults()
        view.endEditing(true)
        guard let placeId = prediction.placeId else { return }
        ApiClient.shared.getCoordinateFromPlaceId(placeId) { [weak self] result in
            guard let self = self, case .success(let data) = result,
                  let lat = data.latitude, let lng = data.longitude else { return }
            if let formatted = data.formattedAddress, !formatted.isEmpty { self.setAddressText(formatted) }
            self.placePin(at: CLLocationCoordinate2D(latitude: lat, longitude: lng), zoom: true)
        }
    }
}
