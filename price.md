# Pricing Configuration

## Monetization Model: Subscription (IAP) with Non-Consumable BYO Key Buyout

Free-forever core tracker + auto-renewable "Clear+" subscription (monthly/yearly, 7-day free trial on yearly) + a one-time non-consumable "BYO Key" unlock for users who bring their own GLM API key. Radical pricing promise: *"Price shown before trial. Cancel in two taps. Your data is yours — export anytime."* No dark patterns, no deceptive tiers.

**Scoping resolution (guide §3.3 vs §8.1 conflict)**: iCloud private sync is listed as P0 in the feature spec and costs zero marginal (user's own iCloud) — it ships FREE for everyone. The paid tier sells AI depth, Mirror, multi-journey, FaceID lock, and themes.

## Subscription Group
- **Group Name**: Clear Mornings Plus
- **Reference Name**: Clear Mornings Plus
- **Products in group**: cm.plus.monthly, cm.plus.yearly (auto-renewable ONLY)

## Subscription Tiers (Auto-Renewable)

⚠️ IAP Type Purity: non-consumable BYO Key lives in its own section below.

### 1. Monthly Subscription
- **Reference Name**: Clear+ Monthly
- **Product ID**: `cm.plus.monthly`
- **Type**: Auto-renewable subscription
- **Price**: $4.99 USD per month
- **Display Name**: `Clear+ Monthly` (14 chars, ≤35 ✅)
- **Description**: `Unlimited AI coach, Mirror, journeys, lock, themes` (50 chars, ≤55 ✅)
- **Localization**: English (US)
- **Subscription Group**: Clear Mornings Plus
- **Restore Purchases**: ✅ Required

### 2. Yearly Subscription
- **Reference Name**: Clear+ Yearly
- **Product ID**: `cm.plus.yearly`
- **Type**: Auto-renewable subscription
- **Price**: $29.99 USD per year (~$2.50/month — 50% savings vs monthly)
- **Display Name**: `Clear+ Yearly` (13 chars, ≤35 ✅)
- **Description**: `Everything in Clear+. 7 days free, then $29.99/yr` (49 chars, ≤55 ✅)
- **Localization**: English (US)
- **Subscription Group**: Clear Mornings Plus (same group as monthly)
- **Restore Purchases**: ✅ Required

## One-Time Purchases (Non-Consumable)

### 1. BYO Key Unlock
- **Reference Name**: Clear Mornings BYO Key
- **Product ID**: `cm.byo.lifetime`
- **Type**: Non-consumable (one-time purchase, permanently unlocked)
- **Price**: $14.99 USD (one-time)
- **Display Name**: `BYO Key Unlock` (14 chars, ≤35 ✅)
- **Description**: `Use your own GLM key. Unlocks all AI features.` (46 chars, ≤55 ✅)
- **Localization**: English (US)
- **Restore Purchases**: ✅ Required
- **Differentiation Note**: BYO Key = same entitlements as Clear+ subscription, forever, but cloud AI calls run on the USER'S OWN GLM key (stored in Keychain, validated by one real API ping). Choose it if you already have a Z.ai/BigModel key or prefer paying the AI provider directly. Clear+ subscription runs AI on the app's built-in service. BYO Key does NOT include anything the subscription lacks — the tiers are feature-identical; they differ only in who pays the AI provider.

## Free Tier (Default)

- **Price**: Free
- **Features**:
  - Streak tracking (second-precision) + calendar
  - Fix Anything (edit any historical day, full audit log)
  - Daily check-in (status + mood + craving, all optional)
  - Brave Restart (slips never zero progress)
  - SOS toolbox: haptic breathing, Why wall, 10-min urge timer, 988/SAMHSA hotline cards — 100% offline
  - Savings calculator + real-world conversions
  - 12-milestone body recovery timeline + streak badges + share cards
  - Home Screen + Lock Screen widgets + interactive check-in
  - Private iCloud (CloudKit) sync — free, P0 core
  - Local JSON+CSV export/import
  - 1 Journey (alcohol)
  - AI: Apple Intelligence on-device unlimited (iOS 26+) with rule-engine fallback + GLM deep SOS conversations 3/week + 1 monthly report (built-in service, real quota)
- **Conversion hooks** (own value only, no competitor prices):
  - After the 3rd deep AI conversation in a week: "Morn can keep talking as long as you need."
  - On enabling Recovery Mirror or adding a 2nd Journey: feature intro → paywall
  - On weekly report screen: "See your full week — every trigger, every win."

## Pro Features Unlocked (All Paid Tiers: Clear+ subscription OR BYO Key)

| Feature | Free | Clear+ ($4.99/mo · $29.99/yr) / BYO Key ($14.99 once) |
|---------|:----:|:----------------------:|
| Streak tracking, calendar, Fix Anything, daily check-in | ✅ | ✅ |
| SOS toolbox + crisis hotlines | ✅ | ✅ |
| Savings wall, recovery timeline, badges, share cards | ✅ | ✅ |
| Widgets + interactive check-in | ✅ | ✅ |
| Private iCloud sync + export | ✅ | ✅ |
| Apple Intelligence on-device AI (affirmations, summaries) | ✅ Unlimited | ✅ Unlimited |
| GLM deep AI coach conversations | 3/week | ✅ Unlimited (fair use 500/day) |
| Recovery Mirror (selfie AI compare) | ❌ | ✅ |
| Weekly report + trigger-pattern insights | 1/month | ✅ Every week |
| Multiple Journeys (vape, sugar, social media…) | 1 | ✅ Unlimited |
| FaceID app lock | ❌ | ✅ |
| Color themes | ❌ | ✅ |

## Free Trial
- **Duration**: 7 days
- **Type**: Free trial (auto-converts to $29.99/year), attached to the YEARLY tier only
- **Available for**: cm.plus.yearly
- **Disclosure**: price + cycle + cancel path shown on the paywall button AND in a pre-trial confirmation sheet; local notification reminder 3 days before trial ends

## Policy Pages Required
- Support Page: ✅ (must include subscription management + cancellation instructions)
- Privacy Policy: ✅
- Terms of Use (EULA): ✅ (REQUIRED — auto-renewable subscriptions present)
- **Total policy pages**: 3

## Apple IAP Compliance Checklist
- [x] Auto-renewal terms included in Terms of Use
- [x] Cancellation instructions included in Support Page (and paywall footer: "Cancel in two taps")
- [x] Pricing clearly stated in PaywallView — prices ON the buttons
- [x] Free trial terms included (7-day, yearly tier, pre-trial disclosure)
- [x] Restore purchases functionality implemented (StoreKit 2 `Transaction.currentEntitlements`)
- [x] No external payment links (Guideline 3.1.1)
- [x] No price references to outside-App-Store options (no competitor price comparison in paywall)
- [x] All IAP descriptions ≤ 55 characters
- [x] All IAP display names ≤ 35 characters
- [x] BYO Key model: AI generation unlimited with own key; no `freeGenerationsUsed`/`maxFreeGenerations` dead code; GLM free-tier weekly quota (3/week) is a REAL built-in-service quota backed by the deployed proxy — always paired with a free on-device alternative in the same screen
