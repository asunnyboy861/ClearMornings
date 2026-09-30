# Clear Mornings — 配置文档

生成时间：2026-09-30（PHASE 8.5 ios-launch-checklist 重写）

---

## 一、⚠️ 手动配置（增强功能 — 不配置不影响基本使用）

> **重要说明**：以下配置项均为**增强功能**，不配置这些项，App 仍可正常使用所有核心功能（打卡、连续天数、Fix Anything、Brave Restart、SOS 工具箱、省钱计算、里程碑、小组件、导出全部免费可用）。配置后可获得更好体验（跨设备同步、订阅购买、AI 深聊等）。

### 🟡 Capabilities 增强配置

#### 1. iCloud CloudKit 生产 Schema 部署

**增强功能**：用户多设备间私密数据同步（走用户自己的 iCloud，开发者零成本零接触）
**不配置的影响**：App 使用本地 SwiftData 存储完全正常运行；仅无法跨设备同步
**当前状态**：App 已使用本地存储作为默认方案，无需配置即可正常使用

**已自动配置部分**：
- ✅ Xcode Signing & Capabilities 中已启用 iCloud（CloudKit）
- ✅ .entitlements 已添加容器 `iCloud.com.clearmornings.app`（Team JP4TN5PTS3，真机签名验证通过）
- ✅ App Groups `group.com.zzoutuo.ClearMornings` 已配置（App + Widgets 双 target）
- ✅ 代码已实现优雅降级（CloudKit 不可用时自动本地存储）

**如需启用增强功能，请手动配置**：
1. 在已登录开发者账号（Team: JP4TN5PTS3）的 Mac 上，Xcode 打开项目并 Run 一次 App（模拟器或真机）
2. 首次运行会自动在 **Development** 环境创建 CloudKit Schema（SwiftData 自动镜像）
3. 打开 [CloudKit Console](https://icloud.developer.apple.com) → 选择容器 `iCloud.com.clearmornings.app`
4. 确认 Development 环境下各 Record Type（CD_Journey、CD_DayRecord 等）已出现
5. 点击 **Deploy Schema Changes to Production** → 确认部署
6. ⚠️ 上架前必须完成此步：未部署 Production Schema 的 App，App Store 版本将无法同步
7. ⚠️ 配置完成后重新 Build 验证

#### 2. App Group 注册确认（非阻塞）

**增强功能**：主 App 与小组件共享数据
**不配置的影响**：Xcode 自动预置时已创建；仅当手动在开发者门户增删设备时需确认
**已自动配置部分**：
- ✅ Entitlements 双 target 已写入
- 如需人工确认：[Apple Developer](https://developer.apple.com) → **Certificates, Identifiers & Profiles** → **Identifiers** → 搜 `group.com.zzoutuo.ClearMornings`

---

### 🔵 IAP StoreKit 配置

**影响功能**：不创建 IAP 产品则用户无法完成订阅/买断购买（免费层功能不受影响；Paywall 会显示空产品列表）
**当前状态**：StoreKit 2 代码已完成（PurchaseManager.swift，Product ID 与 price.md 完全一致），本地测试配置文件 `ClearMornings.storekit` 已创建

**本地测试（已完成，可直接用）**：
- ✅ 项目根目录已创建 `ClearMornings.storekit`（三产品 + 7 天试用）
- 在 Xcode 中启用：**Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration** → 选择 `ClearMornings.storekit` → Run 即可测试完整购买/恢复/试用流程

**生产配置（需手动，必须做）**：
1. 打开 [App Store Connect](https://appstoreconnect.apple.com) → 我的 App → Clear Mornings → **Features** → **In-App Purchases**
2. 点击 **"+"** → **Auto-Renewable Subscription**，创建订阅组：

| 项目 | 值 |
|------|-----|
| Subscription Group Name | `Clear Mornings Plus` |
| Group Reference Name | `Clear Mornings Plus` |

3. 在组内创建两个订阅产品：

| 产品 | Reference Name | Product ID | 价格 | 试用 |
|------|---------------|-----------|------|------|
| 月付 | Clear+ Monthly | `cm.plus.monthly` | $4.99/月 | 无 |
| 年付 | Clear+ Yearly | `cm.plus.yearly` | $29.99/年 | 7 天免费试用（Free trial: 7 days，仅挂 Yearly） |

4. 点击 **"+"** → **Non-Consumable** 创建买断：

| 产品 | Reference Name | Product ID | 价格 |
|------|---------------|-----------|------|
| 买断 | Clear Mornings BYO Key | `cm.byo.lifetime` | $14.99（一次性） |

5. 每个产品的 Display Name / Description 从 `price.md` 复制（已按要求 ≤35 / ≤55 字符）：
   - `Clear+ Monthly` — `Unlimited AI coach, Mirror, journeys, lock, themes`
   - `Clear+ Yearly` — `Everything in Clear+. 7 days free, then $29.99/yr`
   - `BYO Key Unlock` — `Use your own GLM key. Unlocks all AI features.`
6. 本地化语言选 English (US)；所有产品勾选 **Restore Purchases** 支持（代码已实现）
7. ⚠️ 创建后需等 Apple 处理（通常 1-2 小时）才会出现在 Paywall
8. Product ID 必须与上表**逐字符一致**（代码硬编码：PurchaseManager.swift L15-17）

---

### 🟢 App Store Connect 审核信息配置

**影响功能**：不配置则审核员无法理解 BYO Key 模式，有 Guideline 2.1(a) / 3.1.2 拒审风险
**配置步骤**：
1. 打开 [App Store Connect](https://appstoreconnect.apple.com) → Clear Mornings → **App Review Information**
2. 本 App **无账号系统**：Demo Account 的 Sign-In Information 字段填写 "No account required - the app works immediately after launch."
3. **Notes** 字段粘贴项目根目录 `app_review_info.md` 的完整内容（含：三档 IAP 说明、BYO Key 测试步骤、免费层说明、CrisisGuard 危机词拦截机制、医疗免责声明）
4. ⚠️ BYO Key 模式：在 Notes 中说明审核员**无需任何 API Key** 即可审核 —— 免费层（设备端 AI + 规则引擎 + 3 次/周内置云聊）无需配置即可完整测试；BYO Key 是用户自选增强项
5. **Privacy Policy URL**：`https://asunnyboy861.github.io/ClearMornings/privacy.html`
6. **Terms of Use (EULA) URL**：`https://asunnyboy861.github.io/ClearMornings/terms.html`（订阅 App 必填，Guideline 3.1.2）
7. **Support URL**：`https://asunnyboy861.github.io/ClearMornings/support.html`
8. Marketing URL（可选）：`https://asunnyboy861.github.io/ClearMornings/index.html`

---

### 🔐 内置 AI 云引擎生产化决策（上架前决策项）

**背景**：Morn 深聊的内置云引擎经 Cloudflare Worker 代理（`cramjam-api.calcs.top`，备线 `cramjam-proxy.iocompile67692.workers.dev`）。当前 App 内 `GLMSecret.txt` 携带测试期 devKey `cramjam-dev-2026`（该文件**未入 Git**，仅本地打包用）。
**当前保护**：Worker 侧限频 30 次/时 + 200 次/天（按 appId:userId 隔离），App 侧免费层 3 次深聊/周 + 1 报告/月双重限制。
**不处理的影响**：可以上架（限频兜底），但测试 devKey 为共享值，理论上可被提取滥用消耗配额。

**两个选项**：
- **选项 A（推荐，上架前做）**：Worker 端启用 StoreKit 2 `appTransaction` JWS 验签（GLM-Cloudflare 仓库配置文档），App 端把 `GLMSecret.txt` 的 devKey 行删除（文件内已留注释说明格式）
- **选项 B（临时）**：维持 devKey + 限频上线，观察滥用后再切 JWS
- ⚠️ 无论选哪个：确认 Worker 已把 `clearmornings` appId 加入白名单（自助注册或手动添加）

---

## 二、✅ 自动配置记录（已由系统完成，无需操作）

### Capabilities 自动配置

| Capability | 说明 | 状态 |
|------------|------|------|
| iCloud (CloudKit) | entitlements 已配置容器 iCloud.com.clearmornings.app，真机签名验证通过 | ✅ 已配置 |
| App Groups | group.com.zzoutuo.ClearMornings，App + Widgets 双 target | ✅ 已配置 |
| FaceID | Info.plist NSFaceIDUsageDescription 已生成 | ✅ 已配置 |
| Camera / Photo Library | Mirror 功能所需 Info.plist 描述已生成 | ✅ 已配置 |
| Local Notifications | 无需 entitlement，UNUserNotificationCenter 本地通知 | ✅ 已配置 |
| In-App Purchase | StoreKit 2 无需 entitlement | ✅ 已配置 |
| PrivacyInfo.xcprivacy | 双 target 覆盖：UserDefaults CA92.1 + FileTimestamp C617.1；NSPrivacyTracking=false、零收集 | ✅ 已配置 |
| StoreKit 本地测试配置 | ClearMornings.storekit（三产品 + 7 天试用）已生成于项目根目录 | ✅ 已创建 |

### 后端服务

| 服务 | 说明 | 状态 |
|------|------|------|
| 意见反馈后端 | Cloudflare Worker：`https://msg.calcs.top/feedback`（ContactSupportView.swift L96 硬编码） | ✅ 已部署 |
| GLM 云 AI 代理 | `https://cramjam-api.calcs.top`（主）+ `cramjam-proxy.iocompile67692.workers.dev`（备），appId=clearmornings | ✅ 已部署 |
| 危机词本地拦截 | CrisisGuard.swift 纯本地词表，AI 调用前拦截，命中显示 988/SAMHSA | ✅ 已实现 |
| 出站网络 | 仅 HTTPS 标准连接，NSAppTransportSecurity 无需豁免 | ✅ 已配置 |

### 代码生成

| 模块 | 说明 | 状态 |
|------|------|------|
| 核心功能 | SwiftUI + SwiftData，Streak/Milestone/Savings 三引擎纯函数 | ✅ 已完成 |
| AI 双引擎 | AppleFMService（设备端 iOS 26+，规则兜底）+ GLMService（代理 + BYO 直连）+ AIRouter 分流 | ✅ 已完成 |
| BYO Key | SettingsView 输入 → KeychainStore 存储 → 真实 ping 校验 | ✅ 已完成 |
| PurchaseManager | StoreKit 2，三产品 ID 与 price.md 一致，恢复购买已实现 | ✅ 已完成 |
| ContactSupportView | 后端对接 + 7 主题 | ✅ 已完成 |
| SettingsView | 三个政策页链接均已验证（privacy/terms/support，HTTP 200） | ✅ 已完成 |
| QA 迭代 | Step 10 质量循环 + PHASE 6 修复（4 警告清零 + 存储启动 bug 修复） | ✅ 已完成 |

### 💡 使用提示（非开发者配置，App 内操作即可）

**AI 功能分层**：
- 设备端 AI（每日肯定语、日志摘要）：Apple Intelligence（iOS 26+ 设备）自动可用，免费无限；低版本自动降级规则引擎，功能不中断
- 内置云引擎（Morn 深聊、周报）：开箱即用，免费层 3 次深聊/周 + 1 报告/月
- BYO Key（可选）：Settings → 粘贴自己的 GLM Key（Z.ai）→ Keychain 存储 → 解锁无限深聊。这是**用户操作**，非开发者配置

### 部署

| 项目 | 说明 | 状态 |
|------|------|------|
| GitHub 仓库 | https://github.com/asunnyboy861/ClearMornings（main，devKey 未入库） | ✅ 已完成 |
| GitHub Pages | privacy/terms/support/index 四页全部 HTTP 200 | ✅ 已完成 |
| App Store 元数据 | keytext.md 通过官方验证 19/19（ASO 优化：Subtitle + 97/100 Keywords） | ✅ 已完成 |
| 定价配置 | price.md（订阅 $4.99/$29.99+7天试用 / 买断 $14.99） | ✅ 已完成 |
| 审核资料 | app_review_info.md 已生成 | ✅ 已完成 |

---

## 三、能力检测详情

> 以下为 PHASE 2 原始检测数据。"Auto-Configured Capabilities" 与 "Manual Configuration Required" 已重组到上方 Section 一 与 Section 二。

### Analysis

Based on operation guide analysis (TR-20260917-澈晨ClearMornings-操作指南.MD + us.md):
- "私有 iCloud 同步 / CloudKit 私有库" → iCloud (CloudKit) capability
- "Widget/锁屏组件 + 交互式打卡" → WidgetKit extension target + App Groups
- "面容锁 FaceID" → FaceID usage description (Info.plist)
- "本地通知 晨间打卡/里程碑/修复提醒" → UNUserNotificationCenter (no push server — no push certificates needed)
- "每日自拍 Mirror" → Camera + Photo Library usage descriptions
- "订阅 + BYO 买断" → In-App Purchase (StoreKit 2, no explicit entitlement required)
- No HealthKit / Location / Siri / Watch / Background Modes needed (day rollover computed on launch + widget refresh by design — R7)

### No Configuration Needed

- Push Notifications (local notifications only — no server)
- HealthKit / Location / Siri / Apple Watch (P2, out of v1 scope)
- Background Modes (day rollover on launch; no BGTask)

### Verification

- Build succeeded after configuration: ✅ (sim iPhone 16, iOS 18.4, 8.7s；PHASE 6 复验 iOS 26.4 runtime 零警告)
- All entitlements correct: ✅ (CloudKit + App Groups on App; App Groups on Widget)
- Signing verification (generic/platform=iOS): ✅ PASSED — "Apple Development: he zhou", TeamIdentifier=JP4TN5PTS3
- PrivacyInfo.xcprivacy: App + Widgets both covered
- 模拟器实测：iPhone 16 + iPad Pro 13" (M5) Onboarding → "Morning, Day 1." 渲染正常（PHASE 6）
