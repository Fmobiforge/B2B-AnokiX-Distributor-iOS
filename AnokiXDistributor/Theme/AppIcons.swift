import UIKit

/// Maps the Android vector drawable names (ic_*) to the closest SF Symbols, so the
/// menus and cells can keep referencing icons by their original keys.
enum AppIcons {

    static let map: [String: String] = [
        "ic_dashboard": "square.grid.2x2.fill",
        "ic_orders": "doc.text.fill",
        "ic_inventory": "shippingbox.fill",
        "ic_products": "bag.fill",
        "ic_shopping_bag": "bag.fill",
        "ic_stores": "storefront.fill",
        "ic_traders": "person.2.fill",
        "ic_promotions": "megaphone.fill",
        "ic_megaphone": "megaphone.fill",
        "ic_finances": "creditcard.fill",
        "ic_wallet": "wallet.pass.fill",
        "ic_reports": "chart.bar.doc.horizontal.fill",
        "ic_deliveries": "shippingbox.and.arrow.backward.fill",
        "ic_returns": "arrow.uturn.backward.circle.fill",
        "ic_notifications": "bell.fill",
        "ic_settings": "gearshape.fill",
        "ic_search": "magnifyingglass",
        "ic_filter": "line.3.horizontal.decrease",
        "ic_tune": "slider.horizontal.3",
        "ic_add": "plus",
        "ic_delete": "trash",
        "ic_close": "xmark",
        "ic_chevron_right": "chevron.right",
        "ic_hamburger": "line.3.horizontal",
        "ic_more": "ellipsis",
        "ic_more_vert": "ellipsis",
        "ic_person": "person.fill",
        "ic_person_add": "person.badge.plus",
        "ic_briefcase": "briefcase.fill",
        "ic_email": "envelope.fill",
        "ic_lock": "lock.fill",
        "ic_visibility": "eye.fill",
        "ic_visibility_off": "eye.slash.fill",
        "ic_eye": "eye.fill",
        "ic_calendar": "calendar",
        "ic_clock": "clock.fill",
        "ic_location_pin": "mappin.and.ellipse",
        "ic_copy": "doc.on.doc",
        "ic_check_circle": "checkmark.circle.fill",
        "ic_cancel_circle": "xmark.circle.fill",
        "ic_check_green": "checkmark.circle.fill",
        "ic_check_purple": "checkmark.seal.fill",
        "ic_shield": "shield.fill",
        "ic_shield_check": "checkmark.shield.fill",
        "ic_warning_box": "exclamationmark.triangle.fill",
        "ic_package": "shippingbox.fill",
        "ic_document": "doc.fill",
        "ic_pdf": "doc.richtext.fill",
        "ic_finance_report": "chart.line.uptrend.xyaxis",
        "ic_ctr": "cursorarrow.click",
        "ic_chat": "bubble.left.fill",
        "ic_vas": "antenna.radiowaves.left.and.right",
        // anokiX wallet screen
        "ic_arrow_down_left": "arrow.down",
        "ic_arrow_up_right": "arrow.up",
        "ic_arrow_right_line": "arrow.right",
        "ic_send": "paperplane.fill",
        "ic_bank": "building.columns.fill",
        "ic_qr_code": "qrcode",
        "ic_receipt": "doc.plaintext.fill",
        "ic_card": "creditcard.fill",
        "ic_wrench": "wrench.and.screwdriver.fill",
        "ic_dots_horizontal": "ellipsis",
        "ic_phone": "phone.fill",
        "ic_refresh": "arrow.clockwise",
        "ic_headset": "headphones",
        "ic_empty_inbox": "tray"
    ]

    static func symbol(_ name: String) -> UIImage? {
        if name == "ic_more_vert" { return moreVertIcon() }
        let symbolName = map[name] ?? name
        return UIImage(systemName: symbolName)
    }

    /// Android `ic_more_vert` — SF Symbols has no standalone vertical ellipsis; rotate `ellipsis` 90°.
    private static func moreVertIcon() -> UIImage? {
        guard let image = UIImage(systemName: "ellipsis"), let cgImage = image.cgImage else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .right)
            .withRenderingMode(.alwaysTemplate)
    }
}
