# Git Repositories

## Main App (iOS Application)

| Item | Value |
|------|-------|
| **Repository Name** | ClearMornings |
| **Git URL** | git@github.com:asunnyboy861/ClearMornings.git |
| **Repo URL** | https://github.com/asunnyboy861/ClearMornings |
| **Visibility** | Public |
| **Primary Language** | Swift |
| **GitHub Pages** | ✅ **ENABLED** (from `/docs` folder) |

## Policy Pages (Deployed from Main Repository /docs)

| Page | URL | Status |
|------|-----|--------|
| Landing Page | https://asunnyboy861.github.io/ClearMornings/ | ✅ Active |
| Support | https://asunnyboy861.github.io/ClearMornings/support.html | ✅ Active |
| Privacy Policy | https://asunnyboy861.github.io/ClearMornings/privacy.html | ✅ Active |
| Terms of Use | https://asunnyboy861.github.io/ClearMornings/terms.html | ✅ Active |

## Repository Structure

```
ClearMornings/
├── ClearMornings.xcodeproj/       # Xcode Project (xcodegen-generated)
├── ClearMornings/                 # iOS App Source Code
│   ├── App/                       # Entry + RootView
│   ├── Views/                     # Today/SOS/FixAnything/Mirror/Paywall/Settings/ContactSupport
│   ├── Services/                  # GLM/AIRouter/Purchase/Notification/Export/Contact
│   ├── Models/                    # SwiftData entities (CloudKit-compatible)
│   ├── Engines/                   # Streak/Milestone/Savings/Theme
│   └── Assets.xcassets
├── ClearMorningsWidgets/          # Widget extension (interactive check-in + lock screen)
├── Shared/                        # StreakEngine R1-R10 + AppGroupStore (app + widget)
├── docs/                          # Policy Pages (PHASE 7 — GitHub Pages source)
├── project.yml
├── us.md
├── capabilities.md
├── icon.md
├── price.md
├── app_review_info.md
├── improvement_plan_1.md
├── nowgit.md
├── keytext.md                     # ⚠️ EXCLUDED from repo (.gitignore — confidential ASO strategy)
└── GLMSecret.txt                  # ⚠️ EXCLUDED from repo (.gitignore — dev key)
```

## Notes

- Git operations for this project MUST run on a local-volume clone (e.g. `/private/tmp/ClearMornings-git`) — the ORICO external volume rejects `.git` writes (EXDEV). Remote is source of truth.
- Secret scan before push: 4/4 CLEAN (staged content, tracked files, credential URLs, hardcoded devKey).
