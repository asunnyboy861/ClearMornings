# Clear Mornings — Improvement Plan #1 (QA Step 11)

Date: 2026-09-30
Scope: PHASE 4+5 code generation QA. Build verified with `xcodebuild -scheme ClearMornings -destination 'generic/platform=iOS Simulator'` → BUILD SUCCEEDED.

## 1. Fixes applied during QA build loop

| # | Issue | Fix |
|---|---|---|
| 1 | SwiftData `@Model` default values used implicit member syntax (`.now`, `.distantPast`) — macro requires fully qualified names | Replaced with `Date.now` / `Date.distantPast` in all 10 model entities |
| 2 | `NotificationService.rescheduleDailyRitual` awaited `pendingNotificationRequests()` in a sync function | Removed the async query; removes the fixed 7 ritual identifiers directly |
| 3 | `PhotosPicker` + `UIImage` — `loadTransferable(type: UIImage.self)` requires `Transferable` conformance | Load `Data.self` then decode `UIImage(data:)` |
| 4 | Ternary type mismatch (`Color` vs `LinearGradient`) in Onboarding button background | Wrapped both branches in `AnyShapeStyle` |
| 5 | `Calendar.range(of:in:for:)` returns `Range<Int>?` — wrong fallback literal | Fallback `1..<29` |
| 6 | `Product.subscription?.period` does not exist | Use `product.displayName` only |
| 7 | Five `let` Sets mutated in `ExportService.importJSON` | Changed to `var` |
| 8 | Non-exhaustive switch on dictionary lookup in `StreakEngine.compute` | Added `.none` case |
| 9 | Widget target referenced `SavingsEngine`/`Theme` from app-only folder | Added `ClearMornings/Engines/Engines.swift` to Widget target sources in `project.yml` |

## 2. Architecture decisions recorded

- **AI module**: the `ios-openai-module` 6-file architecture is fully covered by existing, stricter modules — `GLMService` (dual-mode GLM client, SSE streaming, proxy envelope), `AppleFMService` (FoundationModels + RuleEngine fallback), `AIRouter` (quota, prompts, degradation chain), `KeychainStore` (BYO key + userId). No duplicate files generated.
- **CloudKit**: no `@Attribute(.unique)` anywhere; all properties have defaults; uniqueness enforced via fetch-then-upsert in `CheckInService`.
- **Widget concurrency**: snapshot + pendingOps merge (no SwiftData access from the extension process).

## 3. Compliance validation (ios-custom-ai-config) — 13/13 PASS

1. No free generation counting ✓ 2. canUse logic ✓ 3. Button state ✓ 4. Empty-state guidance ✓ 5. Paywall legal links (privacy.html + terms.html below subscribe) ✓ 6. `app_review_info.md` created ✓ 7. Friendly error messages ✓ 8. Paywall leads with features, not "AI generations" ✓ 9. HealthKit N/A ✓ 10. No OpenAI/ChatGPT user-facing references ✓ 11. Review Notes written ✓ 12. IAP reactive (currentEntitlement + environmentObject) ✓ 13. BYO key in Keychain only ✓

## 4. Known items before submission (not code defects)

| Item | Owner | When |
|---|---|---|
| Replace Worker `devKey` with StoreKit `appTransaction` JWS + remove `DEV_MODE`/`DEV_KEY` on the CramJam proxy (production hardening per CramJam guide §6) | Developer (Cloudflare side) | Before public launch |
| Deploy policy pages (privacy / terms / support) to `https://asunnyboy861.github.io/ClearMornings/` — URLs are already wired in Paywall/Settings | PHASE 7 (ios-policy-deployer) | Before submission |
| App Store metadata + ASO keytext | PHASE 8 (ios-keytext-optimizer) | Before submission |
| iCloud container `iCloud.com.clearmornings.app` must exist in the developer portal and be selected for the App ID | Developer (portal) | Before submission |
| Verify IAP products `cm.plus.monthly` / `cm.plus.yearly` (7-day intro trial on yearly) / `cm.byo.lifetime` in App Store Connect | Developer (ASC) | Before submission |
| SOS AI uses on-device Apple Intelligence/RuleEngine by design (SOS is always free, works offline); deep-chat upgrade is future enhancement | Backlog | Post-launch |

## 5. Post-launch backlog

- JournalEntry editing UI (entries currently created from Morn chat persistence)
- Multi-journey management UI (data model ready)
- Dawn themes beyond default (Paywall mentions themes; ship 2 extra palettes)
- Local notifications for streak-safe timezones when user travels (currently uses device timezone)
