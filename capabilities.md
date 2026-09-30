# Capabilities Configuration

## Analysis
Based on operation guide analysis (TR-20260917-澈晨ClearMornings-操作指南.MD + us.md):
- "私有 iCloud 同步 / CloudKit 私有库" → iCloud (CloudKit) capability
- "Widget/锁屏组件 + 交互式打卡" → WidgetKit extension target + App Groups
- "面容锁 FaceID" → FaceID usage description (Info.plist)
- "本地通知 晨间打卡/里程碑/修复提醒" → UNUserNotificationCenter (no push server — no push certificates needed)
- "每日自拍 Mirror" → Camera + Photo Library usage descriptions
- "订阅 + BYO 买断" → In-App Purchase (StoreKit 2, no explicit entitlement required)
- No HealthKit / Location / Siri / Watch / Background Modes needed (day rollover computed on launch + widget refresh by design — R7)

## Project (auto-created with xcodegen 2.44.1)
- No .xcodeproj existed in the folder → project.yml authored and `xcodegen generate` run (authorized)
- Targets: **ClearMornings** (application, iOS 17.0+, iPhone+iPad) + **ClearMorningsWidgets** (app-extension, WidgetKit)
- Bundle IDs: com.zzoutuo.ClearMornings / com.zzoutuo.ClearMornings.Widgets
- DEVELOPMENT_TEAM: JP4TN5PTS3 baked at project level (all targets inherit)

## Auto-Configured Capabilities
| Capability | Status | Method |
|------------|--------|--------|
| iCloud (CloudKit, container iCloud.com.clearmornings.app) | ✅ Entitlements configured | xcodegen entitlements properties (auto-provisioning verified by real signing) |
| App Groups (group.com.zzoutuo.ClearMornings) | ✅ Configured (App + Widget) | xcodegen entitlements properties |
| FaceID | ✅ Configured | Info.plist NSFaceIDUsageDescription (generated) |
| Camera | ✅ Configured | Info.plist NSCameraUsageDescription (generated) |
| Photo Library | ✅ Configured | Info.plist NSPhotoLibraryUsageDescription (generated) |
| Local Notifications | ✅ No capability needed | UNUserNotificationCenter requires no entitlement |
| In-App Purchase | ✅ No entitlement needed | StoreKit 2 (products configured in App Store Connect by user later) |
| PrivacyInfo.xcprivacy | ✅ Present in BOTH targets | App: UserDefaults CA92.1 + FileTimestamp C617.1; Widget: UserDefaults CA92.1; NSPrivacyTracking=false, no collected data |

## Manual Configuration Required
| Capability | Status | Steps |
|------------|--------|-------|
| CloudKit container schema in Apple Developer portal / CloudKit Dashboard | ⏳ Pending (non-blocking) | Xcode auto-provisioned the App ID + entitlements with team JP4TN5PTS3 (verified by device signing). First run of the app on a signed device auto-creates the container schema during development. For production: CloudKit Dashboard → confirm schema deployed to Production. |
| App Group registration | ⏳ Pending (non-blocking) | Auto-created by Xcode during provisioning (same as above). Verify in Developer portal if adding devices manually. |
| StoreKit products (cm.plus.monthly / cm.plus.yearly / cm.byo.lifetime) | ⏳ Pending | Create in App Store Connect (PHASE 8.5 checklist covers steps) |

All ⏳ items are non-blocking: the app degrades gracefully (local SwiftData storage works without CloudKit; widget works via App Group snapshot; StoreKit falls back to free tier).

## No Configuration Needed
- Push Notifications (local notifications only — no server)
- HealthKit / Location / Siri / Apple Watch (P2, out of v1 scope)
- Background Modes (day rollover on launch; no BGTask)

## Verification
- Build succeeded after configuration: ✅ (sim iPhone 16, iOS 18.4, 8.7s)
- All entitlements correct: ✅ (CloudKit + App Groups on App; App Groups on Widget)
- Signing verification (generic/platform=iOS): ✅ PASSED — "Apple Development: he zhou", all targets signed, BUILD SUCCEEDED
- DEVELOPMENT_TEAM: JP4TN5PTS3 baked at project level; embedded provisioning profile confirmed TeamIdentifier=JP4TN5PTS3
- PrivacyInfo.xcprivacy: App + Widgets both covered
