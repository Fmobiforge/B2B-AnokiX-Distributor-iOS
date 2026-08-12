import UIKit

/// The three stock mutations behind the Inventory screen — Adjust Stock, Transfer and
/// Add Stock / Receive — as modal forms, mirroring the web dialogs and the Android
/// bottom sheets in StockActionSheets.java.
///
/// Each one posts to the API and calls `onCompleted` with the server's confirmation so
/// the caller can reload the inventory page with fresh numbers.
enum StockActionSheets {

    static func showAdjustStock(from presenter: UIViewController,
                                row: InventoryPageData.Row,
                                onCompleted: @escaping (String) -> Void) {
        let form = StockFormViewController(title: "Adjust Stock — \(row.name ?? "")",
                                           help: "Enter the quantity actually on the shelf. This sets the Available count — it is not a difference — and is recorded in the stock ledger.",
                                           submitTitle: "Save")
        let quantity = form.addTextField(placeholder: "Quantity", keyboard: .numberPad,
                                         text: String(row.unitsOnHand))
        let reason = form.addTextField(placeholder: "Reason (e.g. stock count, damage)")

        form.onSubmit = { [weak form] in
            guard let form = form, let value = Int(quantity.text ?? ""), value > 0 else {
                form?.showError("Enter a quantity."); return
            }
            form.setSubmitting(true)
            ApiClient.shared.setStock(productId: String(row.productId ?? 0), quantity: value,
                                      notes: reason.text ?? "") { result in
                switch result {
                case .success(let message):
                    form.dismiss(animated: true) { onCompleted(message) }
                case .failure(let error):
                    form.setSubmitting(false)
                    form.showError(error.message)
                }
            }
        }
        presenter.present(form.wrappedInNavigation(), animated: true)
    }

    static func showTransfer(from presenter: UIViewController,
                             row: InventoryPageData.Row,
                             warehouses: [InventoryPageData.Warehouse],
                             onCompleted: @escaping (String) -> Void) {
        guard warehouses.count >= 2 else {
            presenter.presentInfo("No warehouses are configured yet."); return
        }

        let form = StockFormViewController(title: "Transfer — \(row.name ?? "")",
                                           help: "Moves units from one warehouse to another. Your total on hand does not change — only where the stock sits.",
                                           submitTitle: "Move stock")
        let names = warehouses.map { $0.name ?? "" }
        // Default the source to the warehouse the row already sits in, when we know it.
        let defaultFrom = warehouses.firstIndex { $0.id == row.warehouseKey } ?? 0
        let fromPicker = form.addPicker(title: "Move from", options: names, selectedIndex: defaultFrom)
        let toPicker = form.addPicker(title: "Move to", options: names, selectedIndex: nil)
        let quantity = form.addTextField(placeholder: "Quantity", keyboard: .numberPad)
        let reason = form.addTextField(placeholder: "Reason (optional)")

        form.onSubmit = { [weak form] in
            guard let form = form else { return }
            guard let toIndex = toPicker.selectedIndex else {
                form.showError("Select a warehouse."); return
            }
            guard let fromIndex = fromPicker.selectedIndex, fromIndex != toIndex else {
                form.showError("Choose two different warehouses."); return
            }
            guard let value = Int(quantity.text ?? ""), value > 0 else {
                form.showError("Enter a quantity."); return
            }
            form.setSubmitting(true)
            ApiClient.shared.transferStock(productId: String(row.productId ?? 0),
                                           fromWarehouseId: warehouses[fromIndex].id ?? "",
                                           toWarehouseId: warehouses[toIndex].id ?? "",
                                           quantity: value, notes: reason.text ?? "") { result in
                switch result {
                case .success(let message):
                    form.dismiss(animated: true) { onCompleted(message) }
                case .failure(let error):
                    form.setSubmitting(false)
                    form.showError(error.message)
                }
            }
        }
        presenter.present(form.wrappedInNavigation(), animated: true)
    }

    static func showReceive(from presenter: UIViewController,
                            warehouses: [InventoryPageData.Warehouse],
                            rows: [InventoryPageData.Row],
                            preselected: InventoryPageData.Row?,
                            onCompleted: @escaping (String) -> Void) {
        guard !warehouses.isEmpty else {
            presenter.presentInfo("No warehouses are configured yet."); return
        }

        let form = StockFormViewController(title: "Receive Stock", help: nil, submitTitle: "Receive")
        let warehousePicker = form.addPicker(title: "Select warehouse",
                                             options: warehouses.map { $0.name ?? "" }, selectedIndex: 0)
        let productIndex = preselected.flatMap { target in
            rows.firstIndex { $0.productId == target.productId }
        }
        let productPicker = form.addPicker(title: "Select product",
                                           options: rows.map { $0.name ?? "" }, selectedIndex: productIndex)
        let quantity = form.addTextField(placeholder: "Quantity", keyboard: .numberPad)
        let unitPicker = form.addPicker(title: "Cases or units", options: ["Cases", "Units"], selectedIndex: 0)
        let cost = form.addTextField(placeholder: "Cost / case", keyboard: .decimalPad)
        let hint = form.addHint()
        let batch = form.addTextField(placeholder: "Batch number (optional)")
        let expiry = form.addDatePicker(title: "Expiry date (optional)")

        // Keep the "adds N sellable units" line and the cost label in step with the inputs.
        let refreshHint = { [weak form] in
            let entered = Int(quantity.text ?? "") ?? 0
            let perCase = productPicker.selectedIndex.map { max(1, rows[$0].unitsPerCase ?? 1) } ?? 1
            let cases = unitPicker.selectedIndex == 0
            let units = cases ? entered * perCase : entered
            hint.text = entered > 0 ? "Adds \(units) sellable units to stock." : ""
            cost.placeholder = cases ? "Cost / case" : "Cost / unit"
            form?.view.setNeedsLayout()
        }
        quantity.addAction(UIAction { _ in refreshHint() }, for: .editingChanged)
        productPicker.onChange = { _ in refreshHint() }
        unitPicker.onChange = { _ in refreshHint() }

        form.onSubmit = { [weak form] in
            guard let form = form else { return }
            guard let productIdx = productPicker.selectedIndex else {
                form.showError("Select a product."); return
            }
            guard let entered = Int(quantity.text ?? ""), entered > 0 else {
                form.showError("Enter a quantity."); return
            }
            let product = rows[productIdx]
            let perCase = max(1, product.unitsPerCase ?? 1)
            let cases = unitPicker.selectedIndex == 0
            let units = cases ? entered * perCase : entered

            // The API books sellable units, so a per-case cost is spread over the case.
            var unitCost = cost.text ?? ""
            if !unitCost.isEmpty, cases, perCase > 1, let value = Double(unitCost) {
                unitCost = String(format: "%.2f", value / Double(perCase))
            }

            form.setSubmitting(true)
            ApiClient.shared.receiveStock(warehouseId: warehouses[warehousePicker.selectedIndex ?? 0].id ?? "",
                                          productId: String(product.productId ?? 0),
                                          quantity: units, unitCost: unitCost,
                                          batchNumber: batch.text ?? "",
                                          expiryDate: expiry.apiDate) { result in
                switch result {
                case .success(let message):
                    form.dismiss(animated: true) { onCompleted(message) }
                case .failure(let error):
                    form.setSubmitting(false)
                    form.showError(error.message)
                }
            }
        }
        presenter.present(form.wrappedInNavigation(), animated: true)
    }
}

extension UIViewController {
    /// Short-lived informational alert (no buttons) used by the stock forms.
    func presentInfo(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { alert.dismiss(animated: true) }
    }
}
