# App Review Information — Clear Mornings

App: Clear Mornings (澈晨)
Bundle ID: com.zzoutuo.ClearMornings
Version: 1.0 (1)
Category: Health & Fitness · Age Rating: 17+

## What the app does

Clear Mornings is a private quit-drinking tracker. Users check in daily (sober / slip / skip), see their streak, savings, and recovery timeline, and can fix any historical day (Fix Anything) or restart kindly (Brave Restart). An optional AI companion ("Morn") offers craving support. Everything works offline; data syncs via the user's own private iCloud (CloudKit). No account, no ads, no data collection.

## Review Notes

### No account / no sign-in
- The app has no login system. All data is stored locally in SwiftData and synced privately through the reviewer's own iCloud account (optional — the app works fully without iCloud).

### AI features (dual engine, BYO Key model)
- Light AI features (daily affirmation, SOS steps) use on-device Apple Intelligence when available, with a deterministic rule-based fallback — these work on any device and require no key.
- Deep AI chat ("Morn") uses the developer's built-in cloud engine (GLM-5.3-Flash via our own proxy). Free users get 3 deep chats per week; Clear+ subscribers get unlimited. No separate purchase or key is required to test this — simply launch the app and chat.
- Optional "Bring Your Own Key": users may enter their own GLM (Z.ai) API key in Settings → AI engine. The key is stored only in the iOS Keychain and is never sent to our servers. The app does NOT sell API keys or AI usage, and no specific AI provider is promoted in the UI.
- For review testing: the built-in engine works out of the box after onboarding. No demo key needed. If the sandbox device has no network, all core tracking features remain fully functional offline.

### Crisis safety (important for 17+ rating)
- Before any AI call, a local keyword guard (CrisisGuard) screens user input. If self-harm intent is detected, the app stops AI generation and shows the 988 Suicide & Crisis Lifeline and SAMHSA 1-800-662-4357 with tap-to-call links.
- The SOS screen permanently displays both hotlines and does not require any AI or network.
- The AI system prompt forbids medical advice, diagnosis, and judgmental language; withdrawal-symptom keywords trigger a "contact a doctor first" message.

### Subscriptions (StoreKit 2)
- Products: `cm.plus.monthly` ($4.99/month), `cm.plus.yearly` ($29.99/year with 7-day free trial), `cm.byo.lifetime` ($14.99 one-time BYO-Key unlock).
- Paywall shows prices, lengths, auto-renewal disclosure, and functional Privacy Policy and Terms of Use links below the subscribe button.
- Purchase unlocks features immediately (reactive entitlement via `Transaction.currentEntitlement`). "Restore purchases" is available in Paywall and Settings.
- Sandbox testing: standard sandbox account works. If products fail to load, features remain usable in the free tier — the paywall is only shown when the crown icon is tapped.

### HealthKit
- Not used.

### Camera / Photos
- The optional Recovery Mirror lets users compare a "Day 1" photo with a current photo. Photos are stored on-device only. Camera and photo library usage descriptions are in Info.plist. AI comparison is opt-in and clearly labeled.

### Notifications
- Morning ritual reminder, milestone heads-up, and a "yesterday is still fixable" nudge. Permission is requested once during onboarding and can be declined — the app works normally without it.

### Data deletion
- Settings → Data → export (JSON/CSV) or simply delete the app. No server-side user data exists.

## Policy URLs

- Privacy Policy: https://asunnyboy861.github.io/ClearMornings/privacy.html
- Terms of Use (EULA): https://asunnyboy861.github.io/ClearMornings/terms.html
- Support: https://asunnyboy861.github.io/ClearMornings/support.html

## Contact

- Developer: he zhou (ZHOU HE)
- Email: asunnyboy168@icloud.com
- Phone: +86 178 9671 0346

## China App Store Compliance

This app does NOT reference ChatGPT/OpenAI in any user-facing UI or metadata. The AI feature uses a generic "Bring Your Own API Key" model plus the developer's own cloud engine; no specific AI provider is promoted or bundled. The app does not distribute user-generated content publicly (no community feed), so deep synthesis regulations do not apply to content moderation beyond the local crisis guard.
