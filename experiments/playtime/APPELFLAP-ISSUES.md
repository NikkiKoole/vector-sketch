# Appelflap — Issue List

Repo: https://github.com/NikkiKoole/appelflap (LÖVE 11.x fork with iOS in-app purchase support, based on Bruce Hill's 2016 IAP code).

Architecture (for reference): `IAPResponder` (Obj-C, `src/modules/purchase/InAppPurchase.{h,m}`) → `love::ios::*` C++ wrappers in `src/common/ios.{h,mm}` → Lua bindings exposed as `love.system.makePurchase / hasPurchase / restorePurchases` via `src/modules/system/{System,wrap_System}.{cpp,h}`.

---

## Bugs

### 1. First purchase ever is silently lost
**File:** `src/modules/purchase/InAppPurchase.m`, `-markOwned:`

```objc
NSArray *purchases = [defaults arrayForKey:@"purchases"];   // nil on first run
[defaults setObject:[purchases arrayByAddingObject:productIdentifier] forKey:@"purchases"];
```

`[nil arrayByAddingObject:x]` returns `nil`, so the very first purchase writes `nil` to `NSUserDefaults` and `hasPurchase` keeps returning `NO` forever after.

**Fix:** `purchases = purchases ?: @[];` before the `arrayByAddingObject:` call.

---

### 2. `restorePurchases` wipes entitlements before restoring
**File:** `src/modules/purchase/InAppPurchase.m`, `-restorePurchases`

```objc
[defaults setObject:@[] forKey:@"purchases"];           // wipes first
[paymentQueue restoreCompletedTransactions];            // then attempts restore
```

If restore returns nothing (network failure, different Apple ID, sandbox quirk), the user loses their local entitlement record. Subsequent `hasPurchase` calls return `NO` for things they've actually paid for.

**Fix:** Don't pre-clear. Let restored transactions append via the normal `markOwned:` path, same as a fresh purchase.

---

### 3. Transaction observer registered too late
**Files:** `src/modules/purchase/InAppPurchase.m` (added inside `restorePurchases` and `productsRequest:didReceiveResponse:`)

`[SKPaymentQueue addTransactionObserver:]` is only attached when the user kicks off a purchase or restore. Apple replays interrupted transactions (e.g. parental-control "Ask to Buy" approvals, payments that completed while the app was killed) **at app launch**, but only delivers them to observers registered at that point. As-is, those replays are lost.

**Fix:** Register the observer **once at app startup**, e.g. alongside `initAudioSessionInterruptionHandler` or in your own init hook. Never remove it.

---

### 4. Duplicate purchase logic / dead code
**Files:** `src/common/ios.mm` and `src/modules/purchase/InAppPurchase.m`

`ios.mm`'s `love::ios::makePurchase` builds its own `SKProductsRequest` and assigns the IAP responder as delegate. This duplicates `IAPResponder`'s own `-makePurchase:` method, which is now never called from anywhere — dead code.

**Fix:** Pick one path. Either call `[iap makePurchase:...]` from the C++ wrapper, or delete the `-makePurchase:` method on the Obj-C side.

---

## Design limitations (not bugs, but they'll bite the next app)

### A. No callbacks to Lua
Lua calls `love.system.makePurchase("x")` and learns nothing about the outcome — no success / fail / cancel / deferred event. The only signal is polling `hasPurchase`. This makes UI feedback (spinner, error toast, "thanks" screen) impossible without busy-loops.

**Suggested shape:** queue purchase events on the Obj-C side (purchase-state, product-id, error-code), drain from Lua via something like `love.system.pollPurchaseEvents()` returning an array of event tables.

### B. Consumables not supported
Everything is stored in one `purchases` array in `NSUserDefaults`; `hasPurchase` returns `YES` forever once an ID is in the list. Fine for non-consumables ("remove ads", "unlock level pack"). Broken for consumables (coin packs, hint packs) which need to be granted then forgotten.

### C. Single product per response
`productsRequest:didReceiveResponse:` does `objectAtIndex:0` on `response.products`. True today (each request is built with a single ID), brittle if you ever batch.

### D. No localized price exposed to Lua
There's no `fetchProducts` API surfaced — Lua can't display "€2.99" before the system confirmation sheet. The system sheet does show the price, so it's not catastrophic, but it limits the storefront UX you can build inside the game.

### E. Fetch-and-buy conflated
`makePurchase` fetches the product, then *immediately* adds the payment to the queue. There's no "fetched, ready to buy — confirm?" intermediate step. Splitting fetch from purchase is what enables (D) above.

### F. Auto-renewable subscriptions not supported
The current `markOwned:` model writes a product ID to a `purchases` array in `NSUserDefaults` and `hasPurchase` returns `YES` forever. That's correct for non-consumables and broken for subscriptions:

- No expiration check, no renewal event handling, no cancellation reflection. A canceled user reads as still subscribed.
- No `appStoreReceiptURL` parsing, no `originalTransactionDate` / `expiresDate` extraction.
- StoreKit 1 receipt parsing is gnarly (PKCS#7 signed binary, Apple recommends server-side validation). StoreKit 2 makes this dramatically easier (`Transaction.currentEntitlements` returns live state) — the strongest argument for migrating if subscriptions become part of the strategy.

If subscriptions ever become part of the plan, budget a StoreKit 2 migration as a separate piece of work; don't try to bolt subscription handling onto the current Obj-C layer. **Currently the plan is one-time IAP / individual app purchases plus an Apple App Bundle, so this gap is documented but not blocking.**

---

## Non-issues / context

- **StoreKit 1 vs 2:** code uses StoreKit 1, which Apple still supports. StoreKit 2 (iOS 15+, Swift-only) is the modern path but bridging Swift→Lua is more work. StoreKit 1 is fine for one more app cycle.
- **`NSUserDefaults` as entitlement store:** trivially editable on jailbroken devices; acceptable risk for indie scope. Server-side receipt validation is the bulletproof path but overkill here.
- **iCloud backup:** `NSUserDefaults` is included in iCloud Backup, so entitlements follow the user's device backup. Fine — usually desirable.
- **Apple guideline 3.1.1:** Apple requires a visible "Restore Purchases" button in-app for any non-consumable. The C++/Lua infrastructure is there; exposing it in your game's UI is on you.

---

## Next steps — testing the IAP layer

Three fidelity levels, pick based on what you're trying to catch.

### 1. StoreKit Configuration File (fastest — simulator + device, no servers)
- Xcode → File → New → StoreKit Configuration File → save as `Products.storekit` in the project
- Define products inline (id, type, price, locale) in the editor
- Scheme → Run → Options → StoreKit Configuration → select the file
- `SKProductsRequest` now resolves locally — no App Store Connect, no Apple ID, no network
- Iteration is seconds. Toggle "Fail Transactions" in the editor to test failure paths.
- **Catches:** bug 1 (first-purchase-lost), bug 2 (restore-wipes), bug 4 (dead code), all design limitations.
- **Misses:** bug 3 (observer-registered-too-late) — simulator doesn't replay interrupted transactions across launches the way real sandbox does.

### 2. Sandbox on real device (canonical pre-ship test)
- **App Store Connect** → app → In-App Purchases → create product with the same product ID used in Lua. Pick consumable / non-consumable / subscription.
- **Users & Access → Sandbox → Testers** → create a fake Apple ID (use a `+sandbox@` email alias)
- **On device:** Settings → App Store → Sandbox Account → sign in with the tester
- Run from Xcode — purchases hit Apple's sandbox servers. Real flow, real "Ask to Buy" deferrals, real restore, real receipt.
- **Catches:** everything including bug 3 — you can force an "Ask to Buy" deferral from sandbox account settings to verify interrupted-transaction replay on next launch.

### 3. TestFlight (last sanity check before submission)
- Same sandbox infra under the hood; distributes to other testers.
- Mostly useful to confirm the flow works on devices you don't own.

### Recommended order
1. Fix bugs 1–3 in the appelflap source (each is a one-liner).
2. Build a small Lua test harness — a scene that calls `love.system.makePurchase`, polls `hasPurchase`, calls `restorePurchases`, and logs what happens.
3. Run against a `.storekit` file in the simulator until the local logic is solid.
4. Set up an App Store Connect product + sandbox tester. Run on device. Force a deferred transaction to verify bug 3 is fixed.
5. Only then start designing the IAP UI and product catalogue for the next app.
