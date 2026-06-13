# anokiX Distributor — iOS

A native iOS (UIKit) port of the **AnokiXDistributorV2** Android app. Same bundle id
(`com.anokix.distributor`), same backend (`http://155.117.20.51/ax/`), same screens,
data models, and visual design system.

## Requirements

- macOS with **Xcode 15** or newer
- **iOS 16.0+** deployment target
- [XcodeGen](https://github.com/yonsei/XcodeGen) to generate the `.xcodeproj`
- [CocoaPods](https://cocoapods.org/) for third-party libraries

## Generating & running

```bash
brew install xcodegen cocoapods   # one-time
cd AnokiXDistributoriOS
xcodegen generate                 # creates AnokiXDistributor.xcodeproj
pod install                       # installs Alamofire + SwiftyJSON, creates .xcworkspace
open AnokiXDistributor.xcworkspace
```

Select a simulator (or your device — set a Development Team in *Signing & Capabilities*
the first time) and **Run**. Regenerate the project after adding files:

```bash
xcodegen generate && pod install
```

Always open **`AnokiXDistributor.xcworkspace`** (not the `.xcodeproj`) after `pod install`.

### Build error: `Pods-AnokiXDistributor-frameworks.sh: Permission denied`

This happens when the project was copied from Windows and CocoaPods shell scripts lose the executable bit.

**Quick fix (on Mac, in the project folder):**

```bash
chmod +x scripts/fix-pods-permissions.sh
./scripts/fix-pods-permissions.sh
```

Or manually:

```bash
find "Pods/Target Support Files" -name "*.sh" -exec chmod +x {} \;
```

Then run `pod install` again (the `Podfile` post-install hook also restores permissions and uses `/bin/bash` for embed scripts).

## Dependencies (CocoaPods)

| Pod | Purpose |
|-----|---------|
| **Alamofire** ~> 5.9 | HTTP client (`Network/Http.swift`) |
| **SwiftyJSON** ~> 5.0 | API envelope parsing (`Network/ApiClient.swift`) |

Domain models still decode with `Codable`; SwiftyJSON handles the `{ status, message, data }` wrapper.

## Architecture (mirrors the Android project)

**UI approach:** Interface Builder first — `Main.storyboard` defines Splash, Login, and the tab bar shell. Reusable headers live in XIB files (`DashboardHeaderView.xib`, `LogoHeaderView.xib`, `PageTitleSectionView.xib`). Swift code wires actions, API calls, and dynamic list content only.

**List rows = XIB templates (Android `item_*.xml` parity).** Every dynamic list row has its layout defined in its own `.xib` — the iOS analogue of an Android per-row XML layout — so rows are edited visually and stay easy to maintain:

| Android row layout | iOS XIB + cell class |
|---|---|
| `item_trader.xml` | `TraderCell.xib` + `TraderCell.swift` |
| `item_product.xml` | `ProductCell.xib` + `ProductCell.swift` |
| `item_store.xml` | `StoreCell.xib` + `StoreCell.swift` |
| `item_inventory.xml` | `InventoryCell.xib` + `InventoryCell.swift` |
| `item_order.xml` | `OrderCell.xib` + `OrderCell.swift` |
| `drawer_content.xml` row | `DrawerMenuCell.xib` + `DrawerMenuCell.swift` |

Each XIB holds **structure + Auto Layout + outlets**; the cell's `awakeFromNib()` applies fonts/colors/radii from the theme (`AppColors`/`AppFonts`/`StyleKit`) so Swift stays the single source of truth for styling (same split as `DashboardHeaderView`). Adapters register and dequeue rows by class name via the `registerNib(_:)` / `dequeue(_:for:)` helpers in `Theme/UITableView+Nib.swift`, so a `cellForRowAt` reads like a RecyclerView adapter referencing a layout. **A new row XIB is picked up automatically on `xcodegen generate`** (the target globs the `AnokiXDistributor` folder) — no manual project edits.

**Tablet: adaptive card grids (RecyclerView `GridLayoutManager` parity).** The four card lists — **Products** (tab + standalone), **Stores**, **Traders**, **Inventory** — render in a `UICollectionView` driven by `Theme/AdaptiveGridLayout.swift`, a compositional layout whose column count comes from the available width: **1 column on iPhone (compact), 2 on iPad portrait, 3 on iPad landscape**. The same horizontal card XIB is reused at every column count — the cells are `UICollectionViewCell`s and the inter-card spacing (16pt edges, 8pt row gap, 16pt column gap) lives in the layout, not the cell, so cards never stretch full-width on iPad. It recomputes on rotation and iPad split-view resize. `OrderCell` (full-width action card) and the drawer stay single-column `UITableView`s.

| Android (Java) | iOS (Swift) |
|---|---|
|---|---|
| `res/values/colors.xml`, `dimens.xml`, `text_styles.xml` | `Theme/AppColors`, `AppMetrics`, `UILabel+Styles`, `StyleKit` |
| `ui/views/Roboto*` custom views | `Theme/AppFonts` (system font; drop-in Inter supported) |
| `network/Http`, `ApiClient` | `Network/Http` (Alamofire), `ApiClient` (SwiftyJSON envelope + Codable) |
| `session/SessionManager` | `Network/SessionManager` |
| `LoginActivity` | `SplashViewController` → `LoginViewController` (**Main.storyboard**) |
| `MainActivity` (bottom nav + drawer) | `MainTabBarController` (**Main.storyboard**) + `DrawerMenuViewController` |
| `include_logo_header` / dashboard header | `Common/AppChrome.swift` (`LogoHeaderView`, `DashboardHeaderView`) |
| Bottom tabs: Home, Orders, Inventory, Products | Same four tabs in `MainTabBarController` |
| Secondary Activities | Pushed on tab nav stack; tab bar hidden via `hidesBottomBarWhenPushed` |
| Drawer screens | Stores, Traders, Products, Promotions, Finances, Reports, Deliveries, Returns, Notifications, Settings |

### UI parity with Android

- **Splash / Launch:** dark navy `#000920` gradient, anokiX logo, “Distributor App” subtitle
- **Login:** gradient top + white bottom sheet, Email/Phone tabs, icon inputs, purple Login + outlined Join
- **Home tab:** white header with hamburger, welcome message, notifications badge, profile initials
- **Inventory / Products tabs:** logo header + page title (matches `include_logo_header`)
- **Orders tab:** white page title header (no purple bar)
- **Bottom navigation:** four labeled tabs with purple selected / grey unselected styling (`tabBarMinimizeBehavior = .never` on iOS 26 so the bar stays visible like Android)
- **Drawer:** dark navy panel, logo, “Distributor Portal” badge, purple selected menu pill

### Notes

- **Maps:** MapKit pin picker in `AddEditStoreViewController` (Android uses Google Maps).
- **Icons:** SF Symbols via `Theme/AppIcons.swift`; swap in asset catalog icons for pixel parity.
- **Fonts:** system font by default; add Inter `.ttf` files and set `useInter = true` in `AppFonts.swift`.
- **Live vs mock:** Dashboard, Stores, Traders, Products, Inventory summary use the real API; Orders list and most drawer screens use mock data (same as Android).

## Status

All Android screens are implemented. Build on a Mac with `pod install` before running.
The splash → login → main tab flow and bottom navigation now match the Android app structure.
