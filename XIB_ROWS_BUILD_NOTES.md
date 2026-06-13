# List rows → XIB migration — Mac build & verification

These changes were authored on Windows (no Xcode), so please build on the Mac and
sanity-check the items below. Layouts were ported 1:1 from the previous programmatic
cells, so any difference is a wiring bug, not a redesign.

## Regenerate & run

```bash
cd AnokiXDistributoriOS
xcodegen generate      # picks up the 6 new *.xib + *.swift automatically
pod install
open AnokiXDistributor.xcworkspace
```

## What changed

- New helper `Theme/UITableView+Nib.swift` — `registerNib(_:)` / `dequeue(_:for:)`
  (plus `UICollectionView` variants for the upcoming tablet/grid work).
- New `StyleKit.styleCard(_:)` and `StyleKit.styleBadge(_:)` apply the existing card /
  badge look to an outlet (the factory methods now call them — no visual change).
- Six rows moved from programmatic cells to XIB + class:
  `TraderCell`, `ProductCell`, `StoreCell`, `InventoryCell`, `DrawerMenuCell`, `OrderCell`.
  The inline cell classes were deleted from their view controllers and each cell now
  lives in its own file next to its `.xib`.
- **Tablet grids:** `TraderCell`, `ProductCell`, `StoreCell`, `InventoryCell` are now
  `UICollectionViewCell`s, and their screens (Traders, Stores, Inventory, Products tab +
  standalone Products) use a `UICollectionView` with `AdaptiveGridLayout` — 1 column on
  iPhone, 2–3 on iPad. The Products tab's list in `Main.storyboard` was changed from a
  `UITableView` to a `UICollectionView` (outlet renamed `productsTableView` →
  `productsCollectionView`). `OrderCell` and the drawer remain `UITableView`s.

## Verify per screen (should look identical to before)

- [ ] **Traders** — avatar colour, name/location/phone stack, "New" badge on the right.
- [ ] **Products** (tab + standalone screen) — thumbnail, name, `SKU · Category`,
      purple price, stock pill; async image still loads.
- [ ] **Stores** — purple icon tile, name/address, Followers/Reviews columns,
      status pill + chevron; tapping a row still opens the editor.
- [ ] **Inventory** — name, `SKU · units`, **stock bar fills to the right %** and
      takes the status colour, status pill.
- [ ] **Drawer** — icon + label rows, selected row shows the purple pill + bold label.
- [ ] **Orders** — ribbon (NEW ORDER/PROCESSING) + time, avatar/trader/order-id with
      copy button, location row (hidden when empty), product summary (hidden when empty),
      Order Value + PAID/payment badges, and the View/Accept/Reject buttons fire
      their toasts. Copy button copies the order id.

## Verify on iPad (grid)

- [ ] Run on an **iPad simulator**: Products / Stores / Traders / Inventory show **2
      columns** in portrait, **3** in landscape; cards keep the same design, just narrower.
- [ ] **iPhone** still shows a single column identical to before.
- [ ] Rotate and try **Split View / Slide Over** on iPad — column count adjusts to the
      window width without clipping.
- [ ] Card spacing looks even (16pt from screen edges, 8pt between rows, 16pt between
      columns); cards self-size to their content height.

## If a cell is blank or crashes

- A crash like *"this class is not key value coding-compliant for key X"* means an
  outlet name in the `.xib` doesn't match the `@IBOutlet` — the names were cross-checked,
  but that's the first place to look.
- Auto Layout console warnings about the inventory **fill** width are expected at design
  time (its width multiplier is set in code per row); they resolve at runtime.
