# Clear Mornings — iOS Development Guide

> Source: TR-20260917-澈晨ClearMornings-操作指南.MD (translated & expanded)
> Report date: 2026-09-17 ｜ Build date: 2026-09-30

## Executive Summary

**Clear Mornings** is a native iOS sobriety tracker built with SwiftUI + SwiftData + CloudKit — **zero custom backend** (privacy as architecture, zero server cost).

**One-line positioning**: *"The sobriety tracker that never punishes you."* — a private, fixable-history, AI-rescued, visually-healing quit-drinking app. No account, no shame, no $40 paywall.

**Target audience**: US market, adults quitting or reducing alcohol (28% of US adults report binge drinking; "sober curious" movement expanding TAM). Category: Health & Fitness, age rating 17+.

**Key differentiators** (built on the 4 pain points competitors admit but never fixed):
1. **Fix Anything** — any historical day can be edited/backfilled; streak recalculates instantly with a full audit log.
2. **Private by Design** — no account; iCloud (CloudKit private DB) sync visible only to the user; one-tap encrypted export; FaceID lock.
3. **SOS + Morn AI Coach** — a real conversational AI rescue line for 2 AM cravings (GLM-5.3-Flash via Cloudflare Worker proxy), with crisis escalation to 988/SAMHSA.
4. **Brave Restart** — a slip never zeroes your progress: total sober days, longest streak, and brave-restart count are all preserved; the slip day renders as neutral gray *data*, never red *shame*.

**Brand moment**: The app opens with "Morning, Day 47." — the name sells the reward (a clear morning), the subtitle sells the action: **Clear Mornings — Quit Drinking & Stay Sober**.

## Competitive Analysis

| App | Price | Strengths | Weaknesses (from 1-star reviews) | Our Advantage |
|-----|-------|-----------|----------------------------------|---------------|
| I Am Sober (4.5★, 170K+ ratings) | Free + Sober Plus $9.99/mo, $39.99/yr | Daily pledge ritual, community | Forced account + cloud sync (privacy); stats/private groups/backup/FaceID all paywalled; noisy feed; data loss on device change | No account, iCloud private sync, core features free forever, editable history |
| Sober Tracker (4.7★, our clone target) | Free + sub + lifetime | No account, local-only, savings calculator, recovery garden | No community/coach/AI; no taper mode; no cloud backup (device change = data loss); records not editable | Fix Anything + AI coach + CloudKit sync |
| Reframe | $13.99/mo, $79.99/yr | 120-day science course | Expensive; course-heavy, tracking weak | Tracker-first, 1/3 the annual price, real AI conversations |
| Sunnyside | ~$12/mo, $99/yr | Reduction (not abstinence) | Not designed for streak counting | Two Paths: quit OR taper |
| Nomo (4.0★) | Free | Multi-clock, 12-step | Dated UI; social requires account | Modern SwiftUI, no account |
| Sober Time | Free + ads | Second-precision timer, daily quotes | Ads; unstructured community | Zero ads, zero analytics SDKs |
| Rebuild | Free + sub | Body recovery timeline, no account | **No cloud backup** (local export only — data-loss anxiety); no AI | CloudKit sync + GLM coach + Recovery Mirror |

**Category consensus**: streak tracking + milestones + savings calculator are table stakes. **Unsolved universal pain** (#1 review complaint source) = deceptive subscriptions + unfixable records + data loss + slip shaming + no help when cravings hit.

## Apple Design Guidelines Compliance

- **Liquid Glass / iOS 26 materials**: SwiftUI with `.ultraThinMaterial` and gradient accents; degrades gracefully on iOS 17.
- **Dynamic Type**: All text scales; the big streak number uses `scaledValue`-aware sizing (96pt base).
- **VoiceOver**: Every interactive element has an accessibility label; streak status uses shape + color dual encoding (color-blind safe).
- **Reduce Motion**: `@Environment(\.accessibilityReduceMotion)` respected — confetti/particle effects disabled.
- **Haptics**: CoreHaptics "heartbeat-thud" anchors for breathing; UIKit-style feedback on milestone unlock.
- **No dark patterns**: prices shown on buttons before trial; cancel path disclosed in 3 places (store page, trial sheet, settings).
- **Health category red lines**: never claim treatment/cure/medical effect (Guideline 1.4.1/1.4.5). Fixed disclaimer in onboarding + About: *"Not medical advice. Sudden alcohol withdrawal can be dangerous — talk to a doctor before quitting if you drink heavily daily."*

## Technical Architecture

- **Language**: Swift 5.10+, SwiftUI (primary), no UIKit except where needed (haptic engine config)
- **Min iOS**: 17.0 (Apple Intelligence/ FoundationModels features auto-degrade to rule engine below iOS 26)
- **Data**: SwiftData + CloudKit private database (`iCloud.com.clearmornings.app`), `NSPersistentCloudKitContainer`-style automatic mirroring, no account system
- **AI dual engine**:
  - **Light tasks** (daily affirmation, journal one-line summary, SOS 3-step guidance): Apple FoundationModels on-device (free, private, never leaves device). On iOS < 26 / unsupported devices → rule-engine fallback (fixed affirmation pool + template summaries).
  - **Heavy tasks** (deep craving conversations, weekly reports, mirror photo comparison): GLM-5.3-Flash via **Cloudflare Worker proxy** (built-in mode) or **user's own Z.ai key direct** (BYO mode).
- **Networking**: URLSession with SSE streaming for chat
- **Monetization**: StoreKit 2 — subscriptions + non-consumable lifetime
- **Notifications**: UNUserNotificationCenter local only (no push server)
- **Widgets**: WidgetKit + App Intents (interactive check-in from Home Screen / Lock Screen)

### GLM Access Configuration (verified working 2026-09-30)

**Built-in mode goes through the deployed Cloudflare Worker proxy — the GLM key NEVER ships in the app binary.**

```
POST https://cramjam-api.calcs.top          (main, works in US & CN)
     https://cramjam-proxy.iocompile67692.workers.dev   (backup line)
Content-Type: application/json

{
  "appId": "clearmornings",            // REQUIRED: app namespace, isolates rate limits per app
  "userId": "<UUID>",                  // REQUIRED: generated on first launch, stored in Keychain
  "devKey": "cramjam-dev-2026",        // TEST PERIOD ONLY — production: send "appTransaction" (StoreKit 2 JWS)
  "payload": {
    "model": "glm-5.3-flash",
    "messages": [ {"role":"system","content":"..."}, {"role":"user","content":"..."} ],
    "thinking": {"level": "low"},      // REQUIRED — model forces thinking; low|high|max
    "max_tokens": 4096,                // REQUIRED ≥4096 text / ≥8192 vision (reasoning tokens count into budget)
    "temperature": 0.3
  }
}
```

- Response 200: GLM raw response; use `choices[0].message.content`, **ignore `reasoning_content`**
- Errors: 400 bad_json/bad_request, 401 invalid_receipt, 405 method_not_allowed, 429 rate_limited (30/hour + 200/day per `appId:userId`) → show friendly "Too many requests, try again shortly"
- Vision (Recovery Mirror): send images as base64 `image_url` content parts inside `payload.messages`
- Free-tier quota is enforced **client-side too**: GLM deep SOS conversations 3/week + 1 monthly report for free users; Plus/BYO unlimited (fair-use 500/day)
- Degradation chain: GLM timeout 3s → retry 1× → fall back to Apple FM (rule engine) → fall back to fixed scripts. Offline: SOS toolbox (breathing/why/timer/hotline) 100% functional.

**Model behavior rules (mandatory)**:
1. `glm-5.3-flash` forces thinking — cannot be disabled (error 1210); always send `"thinking": {"level": "low"}`.
2. `max_tokens` must be generous — reasoning tokens count into the completion budget; short budgets return empty `content` with `finish_reason: "length"`.
3. Structured output: system-prompt constraint + `response_format: {"type":"json_object"}` when JSON is needed; always ignore `reasoning_content`.

## Module Structure

```
ClearMornings/
├── ClearMorningsApp.swift            // App entry, ModelContainer setup
├── Models/                           // SwiftData models
│   ├── Journey.swift
│   ├── DayRecord.swift
│   ├── EditLog.swift
│   ├── WhyItem.swift
│   ├── SavingConfig.swift
│   ├── MilestoneState.swift
│   ├── SOSLog.swift
│   ├── JournalEntry.swift
│   ├── PhotoCheckIn.swift
│   └── AIChatMessage.swift
├── Engines/
│   ├── StreakEngine.swift            // Pure-function streak computation (R1-R10)
│   ├── MilestoneEngine.swift         // 12 recovery milestones + streak badges
│   └── SavingsEngine.swift           // Money saved + real-world conversions
├── Services/
│   ├── CheckInService.swift          // Check-in write + recalc + widget reload
│   ├── GLMService.swift              // Proxy client (built-in) + BYO direct client
│   ├── AppleFMService.swift          // On-device AI (iOS 26+) + rule-engine fallback
│   ├── AIRouter.swift                // Route light→FM, heavy→GLM; entitlement + quota checks
│   ├── CrisisGuard.swift             // Local word-list screening BEFORE any AI call
│   ├── NotificationService.swift     // Morning ritual / milestone / fix reminder
│   ├── ExportService.swift           // JSON+CSV export / import
│   ├── KeychainStore.swift           // userId, BYO key storage
│   └── EntitlementManager.swift      // StoreKit 2: free/plus/byo
├── ViewModels/
│   ├── TodayViewModel.swift
│   ├── SOSViewModel.swift
│   ├── CalendarViewModel.swift       // Fix Anything
│   ├── MirrorViewModel.swift
│   ├── CoachViewModel.swift          // AI chat
│   └── SettingsViewModel.swift
├── Views/
│   ├── Onboarding/                   // 7-tap onboarding flow
│   ├── Today/                        // Big number + daily check-in + SOS ball
│   ├── SOS/                          // Breathing / Why wall / urge timer / AI chat / hotline
│   ├── Calendar/                     // Fix Anything calendar + day editor
│   ├── Mirror/                       // Recovery timeline + selfie compare + savings wall
│   ├── Coach/                        // Morn AI chat UI
│   ├── Paywall/
│   └── Settings/
├── ShareCard/                        // Milestone share card renderer
├── Widgets/                          // WidgetKit extension target
│   ├── StreakWidget.swift            // Home screen big number
│   ├── LockScreenWidget.swift
│   └── CheckInIntent.swift           // Interactive check-in App Intent
└── Resources/
    ├── Localizable.xcstrings         // String Catalog, en-US first
    └── Assets.xcassets               // App icon (dawn gradient on deep indigo)
```

## ⚠️ Feature Inventory (MANDATORY — Every Feature Must Be Listed)

### Primary Features

| # | Feature | User Operation Flow | Data Input | Processing | Data Output | Persistence | Acceptance Criteria |
|---|---------|--------------------|------------|------------|-------------|-------------|---------------------|
| 1 | Streak Tracking (P0) | Open app → big number visible in ≤0.5s | Journey start date, daily check-ins | StreakEngine.compute(): pure-function recalc from records; second-precision timer for today | Big number (96pt SF Pro Rounded) + live seconds timer + calendar heat view | SwiftData Journey/DayRecord + CloudKit | Number matches dayKey math across DST/travel; unknown days don't break streak (R3) |
| 2 | Daily Check-In (P0) | Today tab → tap status (sober/slip/skip) → optional mood 1-5 → optional craving 0-5 → save | Status + mood + craving (all optional) | Write/update DayRecord for today's dayKey; recalc streak; reload widget timeline | Confetti + haptic on sober; Brave Restart entry on slip; streak progress +1 | DayRecord (unique journeyID+dayKey) | ≤3 taps to complete; duplicate write = update not insert (R2) |
| 3 | SOS Rescue (P0) | Tap floating SOS ball (always bottom-right) or Lock Screen widget → 60s haptic breathing → "still craving?" → Why wall → 10-min urge timer → optional AI chat | Tap targets, optional craving 0-5 before/after | Breathing loop 4-4-4-4 with CoreHaptics anchors; urge countdown; CrisisGuard screens chat input | Calming circle animation, wave countdown ring, hotline cards | SOSLog (triggeredAt, resolvedBy, cravingBefore/After) | Works 100% offline; breathing + why + timer + hotline all functional without network |
| 4 | Savings Calculator (P0) | Onboarding slider sets daily spend → Mirror tab shows live "money back" | dailySpend ($0-50) | saved = soberDays × dailySpend; real-world conversions (gas/dinner/weekend trip) | Money wall cards with animated counter | SavingConfig | Updates instantly after every check-in edit |
| 5 | Recovery Timeline (P0) | Mirror tab → vertical timeline | Streak days | 12 science milestones: 24h blood sugar, 1wk sleep, 2wk liver, 30d clarity, 1yr heart… | Unlocked milestones with animation; next milestone countdown | MilestoneState (derived + persisted, idempotent R8) | Editing history correctly unlocks/rolls back uncelebrated milestones |
| 6 | Milestone Badges (P0) | Auto-unlock at 1/3/7/14/21/30/60/90/100/180/365/500/1000 days → celebration screen → share card | Streak math | Badge detection in recalc; celebration once (celebratedAt flag) | Particle confetti + haptic; shareable card "Day 100 · Clear Mornings ✨" | MilestoneState | Rate review prompt AFTER celebration (emotion peak) |
| 7 | Widgets & Lock Screen (P0) | Add widget → see streak; tap interactive button → check-in without opening app | Widget tap | CheckInIntent (AppIntents) writes DayRecord + recalcs + reloads timelines | Home big number widget + lock screen gauge | Same SwiftData store via App Group | Interactive check-in works from Lock Screen; widget updates ≤5s |
| 8 | Private iCloud Sync (P0) | Sign into iCloud on device → data syncs silently | SwiftData change sets | CloudKit private DB mirroring (user's own iCloud, invisible to us) | Same data on all user devices | CloudKit private database | Two-device concurrent edit of same day resolves by updatedAt (R9); export file includes EditLog |
| 9 | Morn AI Coach — Basic (P0) | Daily affirmation card on Today; journal summary; SOS 3-step guidance | Optional journal text | Apple FoundationModels on-device (iOS 26+); rule-engine fallback below | One affirmation/day, one-line journal summary, guided SOS steps | AIChatMessage (model=.appleFM) | Free tier unlimited; works offline (rule engine) |
| 10 | Brave Restart (P0) | Check-in "slip" → NEVER red/shame → shows preserved totals → AI 3-question micro review (when/where/emotion, 3 taps) → "next tripwire" line inserted top of Why wall → Day 1 restart card with confetti | Slip status + 3 tap-answers | Preserve totalSoberDays/longestStreak/restarts; generate tripwire via AI (or template fallback); restart streak | Gray data card (not red) + Fix button; "Day 1 × 3 = braver than most" card | DayRecord(.slip), EditLog, WhyItem | Slips never destroy history; calendar slip day = neutral gray data point |
| 11 | Morn AI Coach — Deep (P1) | SOS flow "want to talk?" → streaming chat with Morn; remembers Why top-3 + last 3 moods as context | Free text | AIRouter: Plus/BYO → GLM via proxy (streaming SSE); free → 3/week quota; CrisisGuard before send | Streaming warm replies (≤120 words, never judges); weekly report; trigger insights | AIChatMessage (model=.glmFlash), local only | Crisis words → NO AI call, hotline card immediately; GLM down → auto-fallback chain |
| 12 | Recovery Mirror (P1) | Mirror tab → opt-in (default OFF) → daily selfie → AI compares with day-1 photo | Two photos (base64) | GLM vision: 3 gentle observations (skin clarity, under-eye brightness, restedness); no medical claims | Trend curve + observations; photos never uploaded to any storage (API ephemeral) | PhotoCheckIn (assetLocalID, mirrorResult text only) | Fully optional; delete-all button purges photos + results |
| 13 | Two Paths (P1) | Onboarding or Settings: goal = quit completely OR weekly limit (taper) | Goal choice, taperWeeklyLimit | StreakEngine handles taper: weekly drink count vs limit | Taper progress UI ("3 of 7 this week") | Journey.goal, taperWeeklyLimit | Taper weeks with ≤limit count as success days |
| 14 | Multi-Journey (P1) | You tab → add journey (vape/sugar/social media) → separate streaks | Journey name/type/color | Independent streak/badges/savings per journey | Journey switcher; per-journey Today cards | Journey (isArchived supported) | Each journey's streak independent; Plus feature |
| 15 | FaceID Lock + Encrypted Export (P1) | Settings → enable FaceID; export → JSON+CSV (optionally encrypted with password) | FaceID biometrics, export format | LAContext evaluation; Keychain-stored flag; file writer | Lock screen on launch; share sheet with export file | UserDefaults flag + document folder | Locked app hides all content in app switcher snapshot |
| 16 | Onboarding (P0) | 7-tap 45s: welcome → goal 2-choice → start date (default now, backdatable) → daily spend slider (skippable) → Why wall 3 chips + custom (skippable) → Mirror opt-in (default off) → done "Day 1. Brave." confetti → 1 notification permission ask | Taps, slider, optional texts | Create Journey, WhyItems, SavingConfig; schedule morning notification | Main screen with big number + confetti | All entities | First screen shows own number; no account/email ever |
| 17 | Fix Anything Calendar (P0) | You tab → calendar → tap ANY past day → edit status/mood/note → save | Edits to any historical day | Write EditLog(old/new); full recalc (pure function R5); milestones idempotent update (R8) | Streak adjusts instantly; "edited" indicator on modified days | EditLog + DayRecord | Backfill yesterday → streak revives with animation; slip → streak restarts from that day |
| 18 | Local Notifications (P0) | Granted during onboarding | Streak state, milestone schedule | 3 schedules: morning ritual "Morning, Day N." (8:00 default); next-milestone heads-up; yesterday-fixable 9:30 (once, zero-shame wording) | Local notifications | UNUserNotificationCenter | Milestone schedule re-computed after any history edit |
| 19 | Paywall (P0) | Trigger points (3rd deep chat / enable Mirror / 2nd journey / weekly report) → paywall sheet | Product selection | StoreKit 2: monthly $4.99, yearly $29.99 (7-day trial), BYO Key $14.99 lifetime; BYO key validated by real API ping → unlock | Entitlement update; free tier never locked out of core | StoreKit 2 + Keychain (byo key) | Prices ON the buttons; trial discloses price+cancel before start; restore purchases works |
| 20 | Weekly Report (P1) | You tab → report card → generate | Week's records + SOS logs + moods | GLM (or FM fallback): trigger patterns, wins, gentle suggestions | Report view + save to JournalEntry | AIChatMessage/JournalEntry | Free 1/month; Plus unlimited |

### Sub-Features & Detail Interactions

| # | Parent | Sub-Feature | Detail | Interaction |
|---|--------|-------------|--------|-------------|
| 2.1 | Daily Check-In | 3-second flow | Status + mood + craving all optional; never blocks | Big pressable card, swipe-up alternative |
| 2.2 | Daily Check-In | Skip behavior | Untouched → gentle 21:30 reminder once, never nags more | Passive |
| 3.1 | SOS | Breathing | 60s box-breathing 4-4-4-4, circle expands/contracts, haptic per phase | Auto-runs on entry |
| 3.2 | SOS | Why wall | User's own reasons, large-type carousel | Swipe |
| 3.3 | SOS | Urge timer | 10-min countdown with breathing ring; "waves average 10 minutes" copy | Start/cancel |
| 3.4 | SOS | Win log | "You rode out 2 waves today" badge progress | Auto |
| 3.5 | SOS | Crisis card | 988 + SAMHSA 1-800-662-4357 one-tap dial, caring copy, red allowed ONLY here | Tap to call |
| 10.1 | Brave Restart | AI micro review | When? Where? What emotion? — 3 tap-chips, ≤15 seconds | Tap chips |
| 11.1 | Deep Coach | Context injection | Why top-3 + last 3 moods prepended locally; no server profile | Auto |
| 11.2 | Deep Coach | Streaming | SSE rendering token-by-token; ≤120 words; warm never preachy | Passive |
| 12.1 | Mirror | Photo pipeline | Photos stay local (assetLocalID); only base64 sent per-call; never stored remotely | Camera/photo picker |
| 17.1 | Fix Anything | Audit visibility | Edited days show subtle "edited" mark; tappable to view change history | Tap badge |
| 20.1 | Weekly Report | Scheduling | Generated locally on demand; stored for history | Button |

### Cross-Feature Dependencies

| Dependency | Source | Target | Data Passed | Trigger |
|------------|--------|--------|-------------|---------|
| Check-in → Streak | Daily Check-In | Streak/Widget | DayRecord write | Every check-in |
| Edit → Recalc → Milestones | Fix Anything | Recovery Timeline + Badges + Notifications | Full recompute | Any history edit |
| SOS → Coach quota | SOS AI chat | EntitlementManager | Usage count | Each deep chat |
| Slip → Why wall tripwire | Brave Restart | WhyItem | Generated tripwire line | Restart flow completes |
| Streak → Savings | StreakEngine | Savings wall | soberDays count | Recalc |
| Milestone → Share card | Badge unlock | ShareCard renderer | streak number + badge | Celebration |
| BYO key → direct GLM | Settings BYO entry | GLMService | Keychain key | Key saved & pinged OK |
| Paywall → Mirror/MultiJourney/DeepCoach | Purchase | Feature gates | Entitlement plan | Purchase success |

**VERIFICATION**: Chinese guide P0=10 features, P1=5 features → 15 core + onboarding + notifications + paywall orchestration = 20 primary features listed. P2 (Watch app, partner sharing, content site) are explicitly OUT of v1 scope per guide §11 W6+ plan. ✅ Match.

## ⚠️ Data Flow Diagram (MANDATORY)

```
Feature: Streak Tracking + Fix Anything (core loop)
┌───────────────────────────────────────────────────────────┐
│  User Input: check-in tap OR calendar day edit            │
│  └── TodayView / CalendarDayEditor                        │
│       │                                                   │
│  ViewModel: TodayViewModel / CalendarViewModel            │
│  └── CheckInService.markDay(journey, dayKey, status,…)    │
│      → upsert DayRecord (R2 unique) → append EditLog (R5) │
│       │                                                   │
│  Engine: StreakEngine.compute(journey, records)  [PURE]   │
│  └── StreakResult{current, unknownGap, total, longest,    │
│      restarts} → MilestoneEngine diff → MilestoneState    │
│       │                                                   │
│  Persistence: SwiftData → CloudKit private DB (auto)      │
│       │                                                   │
│  Display: big number + unknownGap amber card + savings +  │
│  timeline; WidgetCenter.reloadAllTimelines()              │
└───────────────────────────────────────────────────────────┘

Feature: SOS with AI chat
┌───────────────────────────────────────────────────────────┐
│  User Input: SOS ball → breathing → why → timer → chat    │
│       │                                                   │
│  ViewModel: SOSViewModel → CoachViewModel                 │
│  └── CrisisGuard.screen(text) FIRST:                      │
│      crisis words → hotline card (NO AI call)             │
│      withdrawal words → "talk to a doctor first" + care   │
│       │                                                   │
│  Service: AIRouter                                        │
│  └── entitlement check → quota check (free 3/wk)          │
│      → GLMService.stream (proxy: appId clearmornings,     │
│         userId from Keychain, devKey→appTransaction)      │
│      → SSE tokens → fallback chain on failure             │
│       │                                                   │
│  Persistence: AIChatMessage (text only, local; photos     │
│  never persisted remotely); SOSLog resolvedBy             │
└───────────────────────────────────────────────────────────┘
```

## StreakEngine Rules (R1-R10 — implement EXACTLY)

| Rule | Content |
|------|---------|
| R1 | `dayKey` = local calendar day at creation (`Calendar.current.startOfDay`), stored as `yyyy-MM-dd` string + journey timezone identifier; display interpreted in user's current timezone; records are the source of truth |
| R2 | Uniqueness: `(journeyID, dayKey)` unique; duplicate write = update, never insert |
| R3 | streak = consecutive `.sober` length walking from today (or yesterday if today unsigned) into the past; `.unknown` (missed days) does NOT break streak but shows amber "fix N days" card |
| R4 | `.unknown` → user one-tap fixes to `.sober` (streak revives instantly); change to `.slip` → streak restarts from that day |
| R5 | All edits append EditLog; recalc is a PURE FUNCTION (records in → streak/milestones/savings out), full recompute on any change (<100K rows = milliseconds) — no incremental sync bugs |
| R6 | Backdate: `startDate` earlier than earliest record is legal; streak floor = max(startDate, first .sober) |
| R7 | Daily 03:00 local day-rollover: backfill yesterday as `.unknown` if unsigned; refresh widget timelines |
| R8 | Milestones derived idempotently from recalc: achieved → persist MilestoneState; rollback (history edit) revokes un-celebrated badges; celebrated ones stay + marked "still achieved after correction" |
| R9 | iCloud conflicts: last-writer-wins on `updatedAt` field-level merge (small record granularity); export includes full EditLog for audit |
| R10 | Every displayed number is COMPUTED, never guessed: no records ≠ inferred records; `.unknown` always shown truthfully |

## Data Models (SwiftData)

```
Journey: id UUID(unique), name(default "Alcohol"), goal("quit"|"taper"), taperWeeklyLimit Int?,
         startDate Date, timezoneID String, colorHex, isArchived Bool, createdAt
DayRecord: dayKey String(unique, "journeyID|yyyy-MM-dd"), journeyID UUID, status(.sober|.slip|.skip|.unknown),
         mood Int? (1-5), craving Int? (0-5), note String?, updatedAt
EditLog: dayKey, field, oldValue, newValue, editedAt
WhyItem: id, text, order, isPinned, createdAt
SavingConfig: journeyID, dailySpend Double, currency String
MilestoneState: journeyID, milestoneID, achievedAt, celebratedAt
SOSLog: id, triggeredAt, resolvedBy(.breathing|.why|.timer|.ai|.hotline), cravingBefore?, cravingAfter?
JournalEntry: id, dayKey, text, aiSummary?
PhotoCheckIn: id, dayKey, assetLocalID, mirrorResult?, createdAt
AIChatMessage: id, sessionID, role, text, createdAt, model(.appleFM|.glmFlash)
Entitlement: plan(.free|.plus|.byo) — persisted via StoreKit 2 + UserDefaults flag; BYO key body ONLY in Keychain
```

## Morn AI System Prompt Skeleton (MUST embed)

1. Role: "Morn", warm, brief (≤120 words), never judgmental, never preachy.
2. Forbidden: medical/dosage/withdrawal-medication advice, diagnosis, calling the user "an alcoholic".
3. Suicide/self-harm vocabulary detected → stop generation, output fixed 988 + SAMHSA hotline script.
4. "Shaking/sweating/hallucinating withdrawal" descriptions → fixed output "please contact a doctor first — sudden withdrawal can be dangerous", then continue companioning.
5. Every conversation injects user's top-3 Why items + last 3 moods as local context (no server-side profile).

## Implementation Flow

1. Project scaffold (xcodegen): App target + Widget extension target + entitlements (CloudKit, App Groups, FaceID usage)
2. Data layer: SwiftData models + container with CloudKit private DB
3. StreakEngine + MilestoneEngine + SavingsEngine (pure functions + unit tests: cross-year streak, DST switch, flight timezone check-in, history-edit rollback)
4. Onboarding 7-tap flow
5. Today tab: big number + check-in + SOS floating ball
6. SOS toolbox: breathing (CoreHaptics) / Why wall / urge timer / hotline cards
7. Fix Anything calendar + Brave Restart flow
8. Savings wall + recovery timeline + badges + share card
9. CloudKit sync verification + export/import
10. Apple FM integration (iOS 26+) + rule-engine fallback
11. GLMService (proxy + BYO direct) + CrisisGuard + AIRouter + Coach chat UI
12. Recovery Mirror pipeline
13. StoreKit 2 products + paywall + BYO key validation flow
14. Notifications (morning/milestone/fixable)
15. Widget extension: streak widget + lock screen + interactive CheckInIntent
16. FaceID lock + encrypted export
17. Build verification on iPhone + iPad simulators

## UI/UX Design Specifications

- **Palette**: Night-first. Deep indigo base `#0F1222`; Dawn gradient `#FFB347 → #FF6B9D` (morning light); sober = amber gold; craving = deep sea blue; slip = **neutral gray, NEVER red** (red reserved exclusively for crisis hotline card)
- **Typography**: SF Pro Rounded for the big streak number (96pt); SF Pro body; full Dynamic Type
- **Motion**: number visible ≤0.5s after launch; milestone particle confetti + CoreHaptics "heartbeat-thud"; garden-calm animations (calm, not dopamine traps); respect Reduce Motion
- **Layout iron rules**: ① no infinite-scroll feeds anywhere ② SOS always in one-hand thumb zone ③ each tab ≤1.5 screens ④ slip day = gray data card + "Fix" button, not a red warning
- **Share card**: "Day 100 · Clear Mornings ✨" big-number poster, one-tap Instagram Story share
- **Localization**: en-US first via String Catalog; name never translated

## ⚠️ App Store Compliance — AI Features

### Apple Intelligence (Default Free AI Backend)
On-device Foundation Models power light AI tasks on iOS 26+ (iPhone 15 Pro+). Below iOS 26 or on unsupported devices, the app auto-degrades to the rule engine (affirmation pool + template summaries) — features NEVER break.

- `canGenerate` logic: `isPlus || hasBYOKey || appleFMAvailable || ruleEngineAvailable` — always true; **NO free-generation counters**
- Dead code forbidden: `freeGenerationsUsed`, `maxFreeGenerations`, `canGenerateFree` for Apple FM paths
- GLM deep-chat quota (3/week free) applies ONLY to the cloud AI tier and is a real server/client quota — permitted; UI must always offer the free Apple FM / rule-engine alternative in the same screen

### BYO Key mode
Settings → paste own GLM key (api.z.ai or open.bigmodel.cn) → validated by one real ping → unlock equal to Plus subscription. Key stored in Keychain only. Create `app_review_info.md` with reviewer instructions.

## ⚠️ App Store Compliance — Subscriptions

Guideline 3.1.2(c) requires in the Paywall: functional Privacy Policy link, functional Terms of Use (EULA) link, subscription title/length/price, auto-renewal disclosure. All present.

- Subscription value framing: "Unlock Clear+" (features) — prices on buttons: Monthly $4.99 / Yearly $29.99 (7-day free trial, ~$2.50/mo) / BYO Key $14.99 one-time
- Anti-dark-pattern promise (in store description + paywall footer): *"Price shown before trial. Cancel in two taps. Your data is yours — export anytime."*
- Trial-end reminder local notification 3 days before charge
- Free tier: core tracker FOREVER free; AI: Apple FM unlimited + GLM deep SOS 3/week + 1 monthly report

## Compliance & Listing Checklist

- Age rating 17+ (alcohol topic); no treatment/cure claims anywhere
- Medical disclaimer fixed in onboarding + About
- Crisis resources resident in SOS + AI crisis card: **988** and **SAMHSA 1-800-662-4357**
- Privacy label: **"Data Not Collected"** (no SDKs, no tracking, no accounts); privacy policy discloses Z.ai ephemeral API calls + iCloud private sync
- Subscription disclosure in 3 places (store page, trial sheet, settings)
- Name re-verification in App Store Connect before submission ("Clear Mornings")
- IAP Product IDs: `cm.plus.monthly`, `cm.plus.yearly`, `cm.byo.lifetime`

## Code Generation Rules

- Zero backend: only CloudKit + GLM proxy (both degrade offline)
- Privacy three-nevers: journal text never uploaded, selfies never persisted on any server (API ephemeral), zero analytics SDKs (this is a store-page selling point)
- Fix-first: every "failure state" screen must offer a Fix entry; red ONLY for crisis card
- Timezone safety: dayKey string comparison only; NEVER timestamp-difference day math
- Degradation chain: GLM 3s timeout → 1 retry → Apple FM → fixed scripts; offline SOS 100% functional
- Dynamic version display via `Bundle.main.infoDictionary` — never hardcode
- Swift 5.10+ / SwiftUI, semantic naming, no dead code, no placeholder fake data — real compute only

## Build & Deployment Checklist

1. xcodegen generate → build sim iPhone (iOS 18.4) → green
2. Unit tests: StreakEngine boundary suite (12 cases) green
3. iPad build green
4. Simulator cleanup (`cleanup_simulators.sh after_test <UDID>`)
5. Push to GitHub (single repo, docs in /docs later)
6. StoreKit sandbox purchase flow test (requires App Store Connect products)
7. TestFlight → store submission (user-driven)
