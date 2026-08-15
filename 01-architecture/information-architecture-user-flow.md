# Information Architecture & User Flow — Coloring App

**Document ID:** IA-COLOR-001  
**Version:** 0.1  
**Status:** Draft  
**Related Documents:**  
- `00-product/product-brief.md`
- `00-product/competitor-analysis.md`
- `00-product/mvp-scope.md`

---

## 1. Purpose

Tài liệu này chuyển phạm vi MVP đã chốt thành:

- Danh sách màn hình chính thức.
- Kiến trúc điều hướng.
- Luồng người dùng chính.
- Luồng thay thế / ngoại lệ.
- Mapping từ Module → Feature → Screen → Flow.

Mục tiêu là tạo lớp trung gian rõ ràng giữa:

**Product Direction / MVP Scope**  
và  
**Requirement Catalog / UI Design / Test Cases**

Tài liệu này **không đi vào thiết kế visual chi tiết**, mà tập trung vào cấu trúc trải nghiệm.

---

## 2. IA Principles

Kiến trúc thông tin của app phải tuân theo các nguyên tắc sau:

### IA-001 — Fast Time to Color
Người dùng mới phải đi từ mở app tới hành động tô đầu tiên với số bước tối thiểu.

### IA-002 — Content First
Artwork và category là trọng tâm của discovery flow.

### IA-003 — Simple Navigation
Navigation tối giản, dễ hiểu, ít tầng sâu không cần thiết.

### IA-004 — Progress Always Recoverable
Luồng tiếp tục tác phẩm phải dễ tìm và rõ ràng.

### IA-005 — Monetization Must Not Break Core Flow
Paywall/ads nếu có không được phá hỏng flow tô màu cốt lõi.

### IA-006 — Cross-Age Clarity
Trẻ em và người lớn đều phải hiểu cách đi qua flow chính mà không cần học nhiều.

---

## 3. Information Architecture Overview

**Status: Updated — Re-baseline approved 2026-08-14.** This section reflects the current approved IA. The structure below supersedes the original Step 4 draft; the original is preserved in §3.1 for traceability.

Current approved high-level structure:

```text
App
│
├── Entry
│   ├── Splash
│   └── Optional Onboarding
│
├── Home (repeatable category sections; artwork tap → Coloring directly)
│
├── Library (NEW — browse all artwork, filter by category)
│   └── Drawing Grid (filtered)
│
├── Coloring Editor
│
├── Completion / Result (Share, Save/Download, Back to Home, Recommended for you)
│
├── Profile (NEW — personal artwork: All / In Progress / Completed)
│   └── Settings (entry point, unchanged screen)
│
├── Paywall
│
└── Settings

Legacy / not routed from approved MVP core flow (preserved, not deleted):
├── Category / Drawing List   (SCR-CATEGORY-001)
├── Drawing Preview           (SCR-PREVIEW-001)
└── My Works                  (SCR-WORKS-001)
```

### 3.1 Original Step 4 Draft Structure (superseded, preserved for traceability)

```text
App
│
├── Entry
│   ├── Splash
│   └── Optional Onboarding
│
├── Home
│   ├── Featured / New
│   ├── Categories
│   ├── Continue Coloring
│   └── Daily Drawing (optional)
│
├── Category
│   └── Drawing Grid
│
├── Drawing Preview
│
├── Coloring Editor
│
├── Completion / Result
│
├── My Works
│
├── Paywall
│
└── Settings
```

---

## 4. Official Screen Inventory

### 4.1 Root Screen List

**Status column added 2026-08-14 re-baseline.** `Legacy` = preserved for traceability, not deleted or renamed, not routed from the approved MVP core flow.

| Screen ID | Screen Name | Module | Priority | Status |
|---|---|---|---|---|
| SCR-ENTRY-001 | Splash | MOD-001 App Entry | MUST | Active |
| SCR-ENTRY-002 | Onboarding | MOD-001 App Entry | SHOULD | Active |
| SCR-HOME-001 | Home | MOD-002 Home & Discovery | MUST | Active |
| SCR-LIBRARY-001 | Library | MOD-009 Library & Discovery | MUST | Active — NEW |
| SCR-PROFILE-001 | Profile | MOD-010 Profile | MUST | Active — NEW |
| SCR-CATEGORY-001 | Category / Drawing List | MOD-003 Category & Drawing List | — | Legacy — not routed from approved Home flow |
| SCR-PREVIEW-001 | Drawing Preview | MOD-004 Drawing Preview | — | Legacy — not routed from approved MVP core flow |
| SCR-EDITOR-001 | Coloring Editor | MOD-005 Coloring Editor | MUST | Active |
| SCR-COMPLETE-001 | Completion / Result | MOD-005 Coloring Editor / MOD-006 My Works | SHOULD | Active — role updated |
| SCR-WORKS-001 | My Works | MOD-006 Progress & My Works | — | Legacy — superseded by SCR-PROFILE-001 |
| SCR-PAYWALL-001 | Paywall | MOD-007 Monetization | MUST if monetization in MVP | Active |
| SCR-SETTINGS-001 | Settings | MOD-008 Settings | MUST | Active — reached via Profile, not bottom nav |

---

## 5. Screen Specifications at IA Level

### 5.1 SCR-ENTRY-001 — Splash

**Purpose**  
Khởi tạo ứng dụng và đưa user vào flow phù hợp.

**Entry Points**
- App launch.

**Exit Points**
- `SCR-ENTRY-002` Onboarding (first-time if enabled)
- `SCR-HOME-001` Home

**Related Features**
- FE-ENTRY-001
- FE-ENTRY-002
- FE-ENTRY-003
- FE-ENTRY-004

**Notes**
- Không nên giữ splash quá lâu.
- Nếu có logic restore state hoặc preload content, xử lý ở đây ở mức tối thiểu.

---

### 5.2 SCR-ENTRY-002 — Onboarding

**Purpose**  
Giới thiệu ngắn giá trị cốt lõi của app nếu onboarding được giữ trong MVP.

**Entry Points**
- First launch after Splash.

**Exit Points**
- `SCR-HOME-001` Home

**Related Features**
- FE-ENTRY-005

**Notes**
- Tối đa 2–3 màn.
- Không làm cản trở first-color experience.
- Có thể bỏ ở MVP nếu không cần.

---

### 5.3 SCR-HOME-001 — Home

**Status: Updated — 2026-08-14 re-baseline.**

**Purpose**  
Điểm vào chính để user khám phá nội dung.

**Entry Points**
- Splash
- Onboarding
- Back from child screens
- Bottom navigation
- App re-open

**Exit Points**
- `SCR-LIBRARY-001` (via "See all" on any category section, filter pre-applied; also via Bottom Nav → Library with All active)
- `SCR-PROFILE-001` (via Bottom Nav)
- `SCR-EDITOR-001` (direct — any artwork card tap; resume-or-create rule applies)
- `SCR-PAYWALL-001` (via PRO entry)

**Legacy exit points (preserved, no longer routed in approved MVP core flow):**
- `SCR-CATEGORY-001` — superseded by `SCR-LIBRARY-001`
- `SCR-PREVIEW-001` — artwork tap no longer routes through Preview
- `SCR-WORKS-001` — superseded by `SCR-PROFILE-001`
- `SCR-SETTINGS-001` — no longer a direct Home exit; reached via Profile → Settings icon

**Related Features**
- FE-HOME-001
- FE-HOME-002
- FE-HOME-003
- FE-HOME-004
- FE-HOME-005 *(legacy — see below)*
- FE-HOME-006
- FE-HOME-007 *(legacy — see below)*
- FE-HOME-008
- FE-HOME-009 *(legacy — see below)*
- FE-LIB-001, FE-LIB-004 *(new — See all → Library)*
- FE-HOME-010, FE-HOME-011 *(new — direct-to-Coloring resolution, bottom nav)*

**Home Content Blocks (approved)**
- Repeatable category sections (title + "See all" + horizontally scrollable artwork cards), e.g. Manga, Animal, Nature
- PRO entry
- Bottom navigation (Home / Library / Profile)

**Legacy Home Content Blocks (preserved, not part of approved structure — see §15 UXD-008)**
- Featured / New block
- Continue Coloring block
- Daily Drawing block
- Icon-based Categories grid

**Notes**
- Đây là màn discovery quan trọng nhất.
- Artwork phải nổi bật; category sections thay thế cho category grid + featured + daily blocks trước đây.
- Artwork tap always resolves progress state (resume vs. create) before opening Editor — see FLOW-COLOR-001 and FLOW-RESUME-001.

---

### 5.4 SCR-CATEGORY-001 — Category / Drawing List

**Status: LEGACY — not routed from approved Home flow (2026-08-14 re-baseline).**  
Preserved for traceability. Do not delete or rename. Its browse/filter concept is represented in `SCR-LIBRARY-001`, which uses a new, distinct Screen ID — `SCR-CATEGORY-001` itself is not reused or repurposed.

**Purpose**  
Hiển thị tranh thuộc một category hoặc một collection logic tương đương.

**Entry Points**
- Home → category tap
- Home → “See all”
- Home → Daily/Featured section expanded

**Exit Points**
- `SCR-PREVIEW-001`
- Back → `SCR-HOME-001`

**Related Features**
- FE-CAT-001
- FE-CAT-002
- FE-CAT-003
- FE-CAT-004
- FE-CAT-005
- FE-CAT-006
- FE-CAT-007

**Notes**
- Nên hiển thị trạng thái cơ bản của từng tranh:
  - New
  - In progress
  - Completed
  - Locked/Premium

---

### 5.5 SCR-PREVIEW-001 — Drawing Preview

**Status: LEGACY — not routed from approved MVP core flow (2026-08-14 re-baseline).**  
Preserved for traceability, not deleted or renamed. Functionality previously owned exclusively by this screen has been explicitly reassigned:
- Locked/unlocked artwork resolution → reassigned to the artwork-tap resolver on `SCR-HOME-001` / `SCR-LIBRARY-001` / `SCR-PROFILE-001` (see `REQ-HOME-009`, `REQ-LIB-003`, `REQ-PROFILE-005` in `requirements.md`).
- Resume/Start CTA resolution logic (`REQ-PREVIEW-002`, `REQ-PREVIEW-003`) → reassigned to the same resume-or-create rule, now evaluated before opening `SCR-EDITOR-001` directly instead of being expressed as a CTA on this screen.

**Purpose**  
Cho user xem tranh trước khi bắt đầu hoặc tiếp tục tô.

**Entry Points**
- Category / Drawing List
- Home featured/daily/direct artwork tap
- My Works tap

**Exit Points**
- `SCR-EDITOR-001`
- `SCR-PAYWALL-001` (if locked)
- Back → previous discovery screen

**Related Features**
- FE-PREVIEW-001
- FE-PREVIEW-002
- FE-PREVIEW-003
- FE-PREVIEW-004
- FE-PREVIEW-005

**Primary Actions**
- Start Coloring
- Resume Coloring
- Unlock / See Premium
- Back

**Notes**
- Nếu tranh đã có progress thì CTA chính nên là “Continue”.
- Nếu locked thì state phải rõ.

---

### 5.6 SCR-EDITOR-001 — Coloring Editor

**Status: Updated — 2026-08-14 re-baseline (entry points expanded).**

**Purpose**  
Thực hiện toàn bộ trải nghiệm tô màu cốt lõi.

**Entry Points**
- `SCR-HOME-001` — artwork card tap (direct, resume-or-create)
- `SCR-LIBRARY-001` — artwork card tap (direct, resume-or-create)
- `SCR-PROFILE-001` — artwork card tap (direct, resume — Profile artwork always has progress)
- `SCR-COMPLETE-001` — "Recommended for you" artwork tap (direct, resume-or-create)
- *Legacy:* Drawing Preview, My Works resume (preserved paths, not routed in approved MVP core flow)

**Exit Points**
- Back → originating screen (Home / Library / Profile / Completion), with autosave
- `SCR-COMPLETE-001`
- App background/close (with autosave)
- `SCR-PAYWALL-001` only if user taps locked tool/content (không nên chặn flow đang tô)

**Related Features**
- FE-EDITOR-001 → FE-EDITOR-020 (theo phạm vi đã chốt)
- FE-WORK-001
- FE-WORK-005

**Primary Actions**
- Select color
- Fill region
- Brush
- Eraser
- Undo
- Redo
- Zoom
- Pan
- Reset
- Complete
- Back / autosave

**Notes**
- Đây là màn ưu tiên cao nhất về UX và QA.
- Ads không nên bật giữa session tô.

---

### 5.7 SCR-COMPLETE-001 — Completion / Result

**Status: Updated — role revised, 2026-08-14 re-baseline.**

**Purpose**  
Hiển thị trạng thái hoàn thành và các hành động sau khi hoàn tất tranh.

**Entry Points**
- Editor → Done action

**Exit Points**
- `SCR-HOME-001` (Back to Home — primary action button)
- `SCR-EDITOR-001` (via top-left header Back — **corrected 2026-08-15**: reopens the *same* just-completed artwork, latest state/progress restored, no new session, status remains `COMPLETED`)
- `SCR-EDITOR-001` (via "Recommended for you" artwork tap, direct, resume-or-create — a *different* artwork than the one just completed)
- System share sheet (native, production)
- Save-to-device flow (rendered colored artwork image)

**Legacy exit points (preserved, no longer part of approved Completion content):**
- `SCR-WORKS-001` — "View in My Works" is no longer part of the approved Completion action set
- `SCR-PREVIEW-001`

**Related Features**
- FE-EDITOR-014
- FE-EDITOR-022 *(new — Recommended for you; corrected 2026-08-14, was mistakenly FE-EDITOR-017)*
- FE-WORK-006
- FE-WORK-007
- FE-WORK-008

**Primary Actions (approved)**
- Header Back (top-left) → same just-completed artwork, `SCR-EDITOR-001`, state restored, status stays `COMPLETED` — **corrected 2026-08-15**, distinct control from Back to Home
- Share → native device share sheet
- Save/Download → save rendered colored artwork image to device
- Back to Home (bottom action button) → `SCR-HOME-001`, unchanged
- Recommended for you → artwork cards, tap opens `SCR-EDITOR-001` directly (resume-or-create)

**Notes**
- Completion screen retained (not reduced to a modal).
- "Recommended for you" replaces the previous "Color another drawing" / "View in My Works" exits.
- **2026-08-15 correction:** the header Back control and the "Back to Home" button are two separate, independently-approved exits — header Back must not be treated as a synonym for Back to Home. See `REQ-EDITOR-018`.

---

### 5.8 SCR-WORKS-001 — My Works

**Status: LEGACY — superseded by `SCR-PROFILE-001` (2026-08-14 re-baseline).**  
Not deleted or renamed; not routed from bottom navigation or Home in the approved MVP core flow. `SCR-PROFILE-001` is a new, distinct screen — it does not reuse this Screen ID. The personal-artwork retention/resume purpose this screen served is now owned by `SCR-PROFILE-001`.

**Purpose**  
Truy cập các tranh đang tô và đã hoàn thành.

**Entry Points**
- Home shortcut
- Bottom navigation
- Completion flow

**Exit Points**
- `SCR-PREVIEW-001`
- `SCR-EDITOR-001` (resume direct if supported)
- Back / Home

**Related Features**
- FE-WORK-001
- FE-WORK-002
- FE-WORK-003
- FE-WORK-004
- FE-WORK-005
- FE-WORK-006
- FE-WORK-007
- FE-WORK-008

**Sections Recommended**
- In Progress
- Completed

**Notes**
- Đây là màn rất quan trọng cho retention và resume flow.
- Superseded by `SCR-PROFILE-001`, which carries the equivalent All / In Progress / Completed segmentation forward — see §5.12.

---

### 5.9 SCR-PAYWALL-001 — Paywall

**Purpose**  
Thuyết phục user nâng cấp Premium hoặc unlock nội dung.

**Entry Points**
- Tap Premium CTA
- Locked drawing
- Locked tool
- Premium upsell entry

**Exit Points**
- Purchase success → previous relevant screen
- Restore success → previous relevant screen
- Close → previous relevant screen

**Related Features**
- FE-MON-001
- FE-MON-002
- FE-MON-003
- FE-MON-004
- FE-MON-005
- FE-MON-006
- FE-MON-007
- FE-MON-008

**Notes**
- Không nên hiển thị quá sớm trước khi user cảm nhận được giá trị sản phẩm.
- Phải có đường quay lại rõ ràng.

---

### 5.10 SCR-SETTINGS-001 — Settings

**Purpose**  
Cung cấp điều khiển cấu hình cơ bản và thông tin pháp lý.

**Entry Points**
- Home
- Bottom nav
- Overflow/menu entry

**Exit Points**
- Back → previous/root screen

**Related Features**
- FE-SET-001
- FE-SET-002
- FE-SET-003
- FE-SET-004
- FE-SET-005
- FE-SET-006
- FE-SET-007
- FE-SET-008

**Notes**
- MVP chỉ nên để settings cơ bản.
- Không làm cồng kềnh.

---

### 5.11 SCR-LIBRARY-001 — Library (NEW — 2026-08-14 re-baseline)

**Purpose**  
Browse/explore all available coloring artworks, filterable by category.

**Entry Points**
- `SCR-HOME-001` — "See all" on a category section (opens with that category filter active)
- Bottom navigation — Library tab (opens with "All" filter active)
- `SCR-PROFILE-001` — "Explore Library" CTA (empty state)

**Exit Points**
- `SCR-EDITOR-001` (direct — artwork card tap, resume-or-create rule)
- Back → Home (if entered via See all) or standard root-tab behavior (if entered via Bottom Nav)

**Related Features**
- FE-LIB-001 — Library Screen
- FE-LIB-002 — Category Filter (All, Manga, Animal, Nature, Food, etc.)
- FE-LIB-003 — Open Artwork from Library
- FE-LIB-004 — Entry with Pre-Applied Filter (from Home See all)

**Content**
- Category filter control (All / Manga / Animal / Nature / Food / …)
- Filtered artwork grid

**Notes**
- Not a rename or repurpose of `SCR-CATEGORY-001` or `SCR-WORKS-001` — a new discovery destination.
- Browse/filter concepts previously expressed on `SCR-CATEGORY-001` may inform this screen's design but do not carry its Screen ID forward.

---

### 5.12 SCR-PROFILE-001 — Profile (NEW — 2026-08-14 re-baseline)

**Purpose**  
User-centric screen for personal artwork (in progress / completed) and settings entry.

**Entry Points**
- Bottom navigation — Profile tab

**Exit Points**
- `SCR-LIBRARY-001` — "Explore Library" CTA (shown in empty state, and generally available)
- `SCR-EDITOR-001` (direct — personal artwork tap; always resume, since Profile artwork always has progress)
- `SCR-SETTINGS-001` — Settings icon

**Related Features**
- FE-PROFILE-001 — Profile Screen
- FE-PROFILE-002 — Empty State with Explore Library CTA
- FE-PROFILE-003 — Segmented View (All / Completed / In Progress)
- FE-PROFILE-004 — Personal Artwork Grid
- FE-PROFILE-005 — Open Artwork from Profile
- FE-PROFILE-006 — Settings Icon Entry

**Content**
- Empty state (no personal artwork) with "Explore Library" CTA
- Segments: All / Completed / In Progress
- Personal artwork grid
- Settings icon

**Notes**
- Not `SCR-SETTINGS-001` — Settings remains a separate screen, reached via the Settings icon on this screen.
- Supersedes `SCR-WORKS-001` as the retention/resume destination; carries the equivalent segmentation forward with revised naming (All / Completed / In Progress vs. the legacy screen's In Progress / Completed).
- Artwork state rule: leaving Editor without Done → `IN_PROGRESS` (appears in All + In Progress); tapping Done → `COMPLETED` (appears in All + Completed, removed from In Progress). See `BR-PROFILE-001` in `requirements.md`.

---

## 6. Navigation Architecture

### 6.1 Recommended Root Navigation

**Status: Updated — approved 2026-08-14.**

Approved bottom navigation:

```text
Home | Library | Profile
```

**Rationale**
- Home = discovery (category sections)
- Library = full browse/explore, filterable by category
- Profile = personal artwork (resume/retention) + Settings entry point

**Legacy (superseded, preserved for traceability):**

```text
Home | My Works | Settings
```
Settings remains a screen (`SCR-SETTINGS-001`) but is no longer a root bottom-nav tab — it is reached via Profile → Settings icon.

---

### 6.2 Navigation Types

| Navigation Type | Use Case |
|---|---|
| Launch Route | Splash / Onboarding / Home |
| Push Navigation | Home → Editor (direct); Home → See all → Library → Editor (direct) |
| Modal / Sheet | Paywall, system dialogs, confirmation |
| Bottom Navigation | Home, Library, Profile |
| System Flow | Share sheet, save permission |
| *Legacy Push Navigation (preserved, not routed)* | *Home → Category → Preview → Editor* |

---

### 6.3 Back Behavior Principles

### NAV-001 *(legacy — applies only if SCR-CATEGORY-001 is reached via a non-approved/legacy path)*
Back từ Category → Home.

### NAV-002 *(legacy — applies only if SCR-PREVIEW-001 is reached via a non-approved/legacy path)*
Back từ Preview → previous discovery screen.

### NAV-003
Back từ Editor:
- autosave;
- confirm reset only if required for destructive action;
- return to originating screen (Home / Library / Profile / Completion).

### NAV-004
Back từ Paywall → previous screen without losing context.

### NAV-005 *(corrected 2026-08-15)*
Completion có hai control điều hướng riêng biệt, không được gộp chung:
- Header Back (top-left, ‹) → mở lại **đúng artwork vừa hoàn thành** tại `SCR-EDITOR-001`, restore state/progress hiện tại, không tạo session mới, không đổi status khỏi `COMPLETED`, không đi qua Preview/Category.
- "Back to Home" (primary action button) → `SCR-HOME-001`, không đổi.
- "Recommended for you" → `SCR-EDITOR-001` cho một artwork **khác** (resume-or-create), không đổi.

**Superseded:** bản trước ghi "Back từ Completion → Home" như một hành vi duy nhất — điều này không còn đúng vì header Back và Back to Home nay là hai control khác nhau với đích khác nhau.

### NAV-006 *(new — 2026-08-14)*
Back từ Library:
- if entered via Home "See all" → Home;
- if entered via Bottom Nav → standard root-tab back behavior (no forced navigation).

### NAV-007 *(new — 2026-08-14)*
Back từ Profile → standard root-tab back behavior (Profile is a root bottom-nav destination).

### NAV-008 *(new — 2026-08-14)*
Back từ Editor khi mở trực tiếp từ Home / Library / Profile / Completion → autosave, return to the originating screen (not to Preview).

---

## 7. Flow Inventory

### Main Flow IDs

| Flow ID | Flow Name | Priority | Status |
|---|---|---|---|
| FLOW-ENTRY-001 | Launch & Enter App | MUST | Active |
| FLOW-COLOR-001 | First Coloring Journey | MUST | Active — updated 2026-08-14 |
| FLOW-LIBRARY-001 | Browse Library & Filter by Category | MUST | Active — NEW |
| FLOW-PROFILE-001 | Access Profile / Personal Artwork | MUST | Active — NEW |
| FLOW-DISCOVER-001 | Browse Category & Select Drawing | — | Legacy — superseded by FLOW-LIBRARY-001 |
| FLOW-RESUME-001 | Resume Coloring | MUST | Active — updated 2026-08-14 |
| FLOW-COMPLETE-001 | Complete & Save Artwork | MUST | Active — updated 2026-08-14 |
| FLOW-WORKS-001 | Access My Works | — | Legacy — superseded by FLOW-PROFILE-001 |
| FLOW-PREMIUM-001 | Locked Drawing → Paywall | SHOULD/MUST if monetization in MVP | Active |
| FLOW-REWARD-001 | Rewarded Unlock Flow | SHOULD if used | Active |
| FLOW-SETTINGS-001 | Open Settings / Restore Purchase | MUST | Active |
| FLOW-ERROR-001 | Asset / Content Load Error | MUST | Active |
| FLOW-EMPTY-001 | Empty My Works | — | Legacy — see FLOW-PROFILE-001 empty state |
| FLOW-OFFLINE-001 | Offline / Limited Connectivity Handling | SHOULD | Active |

---

## 8. Primary Flows

### 8.1 FLOW-ENTRY-001 — Launch & Enter App

```text
App Launch
↓
SCR-ENTRY-001 Splash
↓
[If first time and onboarding enabled]
SCR-ENTRY-002 Onboarding
↓
SCR-HOME-001 Home
```

**Success Criteria**
- User đến Home thành công.
- Không có blocker.
- Không có splash delay bất thường.

---

### 8.2 FLOW-DISCOVER-001 — Browse Category & Select Drawing

**Status: LEGACY — superseded by `FLOW-LIBRARY-001` (2026-08-14). Preserved, not routed in approved MVP core flow.**

```text
SCR-HOME-001 Home
↓
Tap Category
↓
SCR-CATEGORY-001 Category / Drawing List
↓
Tap Drawing
↓
SCR-PREVIEW-001 Drawing Preview
```

**Success Criteria**
- User dễ tìm tranh theo sở thích.
- Thumbnail đủ rõ để ra quyết định.

---

### 8.3 FLOW-COLOR-001 — First Coloring Journey

**Status: Updated — 2026-08-14 re-baseline.**

```text
SCR-HOME-001 Home
↓
Tap Artwork Card (any category section)
↓
Resolve Progress:
- has progress → restore
- no progress   → create new progress
↓
SCR-EDITOR-001 Coloring Editor
↓
Select Color
↓
Tap Region
↓
Color Applied
```

**Legacy path (preserved, not part of approved MVP core flow):**
```text
SCR-HOME-001 Home → SCR-CATEGORY-001 Category → SCR-PREVIEW-001 Preview → Tap Start → SCR-EDITOR-001
```

**Success Criteria**
- User tô thành công vùng đầu tiên nhanh chóng.
- Không bị yêu cầu học nhiều.
- Không bị chặn bởi paywall sớm nếu tranh free.

---

### 8.4 FLOW-RESUME-001 — Resume Coloring

**Status: Updated — 2026-08-14 re-baseline.**

```text
SCR-HOME-001 Home / SCR-LIBRARY-001 Library / SCR-PROFILE-001 Profile
↓
Tap In-Progress Artwork Card
↓
SCR-EDITOR-001 Coloring Editor (direct)
↓
Progress Restored
```

**Legacy path (preserved, not part of approved MVP core flow):**
```text
SCR-HOME-001 Home → Tap Continue Coloring or Open SCR-WORKS-001 My Works → Select In-Progress Drawing → SCR-PREVIEW-001 or direct SCR-EDITOR-001
```

**Success Criteria**
- Trạng thái tô được restore chính xác.
- User không phải tìm kiếm quá sâu.

---

### 8.5 FLOW-COMPLETE-001 — Complete & Save Artwork

**Status: Updated — 2026-08-15 correction (header Back behavior).**

```text
SCR-EDITOR-001 Coloring Editor
↓
Tap Done
↓
Save current state, mark artwork COMPLETED
↓
SCR-COMPLETE-001 Completion / Result
↓
Choose:
- Header Back (top-left) → SCR-EDITOR-001, SAME artwork, state restored, status stays COMPLETED
- Share (native device share sheet)
- Save/Download (save rendered colored artwork image to device)
- Back to Home → SCR-HOME-001
- Recommended for you → tap artwork → SCR-EDITOR-001 (a DIFFERENT artwork, direct, resume-or-create)

[If header Back taken]
↓
SCR-EDITOR-001 Coloring Editor (same artwork, status still COMPLETED)
↓
User may edit further
↓
Tap Done again
↓
SCR-COMPLETE-001 (status remains COMPLETED — not reverted to IN_PROGRESS)
```

**Legacy actions (preserved, not part of approved Completion content):**
- View in My Works
- Start another drawing (undifferentiated) — replaced by "Recommended for you"

**Success Criteria**
- User nhận được cảm giác hoàn thành.
- Tác phẩm được lưu thành công nếu user chọn save.

---

### 8.6 FLOW-WORKS-001 — Access My Works

**Status: LEGACY — superseded by `FLOW-PROFILE-001` (2026-08-14). Preserved, not routed from bottom navigation in approved MVP core flow.**

```text
SCR-HOME-001 Home
or Bottom Nav
↓
SCR-WORKS-001 My Works
↓
Choose In Progress or Completed
↓
Open Drawing
↓
SCR-PREVIEW-001 or SCR-EDITOR-001
```

**Success Criteria**
- User truy cập dễ dàng tranh đang tô / đã tô.
- Resume và completed states được tách rõ.

---

### 8.7 FLOW-LIBRARY-001 — Browse Library & Filter by Category (NEW — 2026-08-14)

```text
SCR-HOME-001 Home
↓
Tap "See all" on a category section
↓
SCR-LIBRARY-001 Library (that category filter active)
↓
Tap Artwork Card
↓
Resolve Progress (resume or create)
↓
SCR-EDITOR-001 Coloring Editor
```

**Alternative entry:**
```text
Bottom Nav → Library tab → SCR-LIBRARY-001 (All filter active)
```

**Success Criteria**
- Filter reflects the originating category when entered via "See all".
- Artwork tap always opens Coloring directly — no Preview hop.

---

### 8.8 FLOW-PROFILE-001 — Access Profile / Personal Artwork (NEW — 2026-08-14)

```text
Bottom Nav → Profile tab
↓
SCR-PROFILE-001 Profile
↓
[If no personal artwork]
Empty State → "Explore Library" CTA → SCR-LIBRARY-001
[If personal artwork exists]
Choose All / Completed / In Progress
↓
Tap Artwork Card
↓
SCR-EDITOR-001 Coloring Editor (direct, resume)
```

**Alternative:**
```text
SCR-PROFILE-001 → Settings icon → SCR-SETTINGS-001
```

**Success Criteria**
- Artwork state (IN_PROGRESS / COMPLETED) reflects the most recent Editor exit accurately.
- Empty state clearly redirects to discovery (Library).

---

## 9. Alternative / Exception Flows

### 9.1 FLOW-PREMIUM-001 — Locked Drawing → Paywall

```text
SCR-CATEGORY-001 or SCR-PREVIEW-001
↓
Tap Locked Drawing / Premium CTA
↓
SCR-PAYWALL-001 Paywall
↓
[Purchase Success]
Return to previous screen with unlocked access
or
[Close]
Return to previous screen unchanged
```

**Success Criteria**
- Không làm user mất context.
- Unlock/purchase phản ánh đúng trạng thái.

---

### 9.2 FLOW-REWARD-001 — Rewarded Unlock

```text
Locked Drawing
↓
Choose Watch Ad to Unlock
↓
Rewarded Ad
↓
[Ad Completed]
Unlock drawing
↓
SCR-PREVIEW-001 / SCR-EDITOR-001
```

**Alternative**
- Ad failed / canceled → remain locked.

---

### 9.3 FLOW-EMPTY-001 — Empty My Works

**Status: LEGACY — superseded by the Profile empty state (see `FLOW-PROFILE-001`, §8.8), which routes to `SCR-LIBRARY-001` instead of `SCR-HOME-001`. Preserved for traceability.**

```text
SCR-WORKS-001 My Works
↓
No artworks found
↓
Empty State
↓
CTA: Explore Drawings
↓
SCR-HOME-001 Home
```

**Goal**
- Empty state phải kéo user quay lại discovery.

---

### 9.4 FLOW-ERROR-001 — Asset / Content Load Error

```text
User opens Drawing / Category
↓
Content fails to load
↓
Error State
↓
Retry
or
Back
```

**Error Scenarios**
- Missing asset
- Corrupted local file
- Remote content unavailable
- Restore data invalid

---

### 9.5 FLOW-OFFLINE-001 — Offline Handling

```text
Open App
↓
Offline / limited connectivity
↓
Home available with cached/local content as possible
↓
Open local artwork
↓
Editor works
```

**Notes**
- Exact offline capability depends on Product Decision.
- Nếu daily/remote sections không tải được, phải degrade gracefully.

---

### 9.6 FLOW-SETTINGS-001 — Settings / Restore Purchase

```text
Open Settings
↓
SCR-SETTINGS-001
↓
Tap Restore Purchase
↓
System restore flow
↓
Success / Fail state
↓
Return to Settings or previous monetization context
```

---

## 10. State Architecture by Screen

### SCR-HOME-001
- Loading
- Loaded
- Empty Featured
- Partial content available
- Error / retry

### SCR-CATEGORY-001
- Loading
- Loaded
- Empty category
- Error

### SCR-PREVIEW-001
- Free drawing
- In-progress drawing
- Completed drawing
- Locked drawing
- Error loading preview

### SCR-EDITOR-001
- Initializing
- Editing
- Autosaving
- Saved
- Error save
- Restore successful
- Restore error

### SCR-WORKS-001 *(legacy — superseded by SCR-PROFILE-001)*
- Loading
- Empty
- In-progress list
- Completed list
- Error

### SCR-LIBRARY-001 *(new)*
- Loading
- Loaded (filtered)
- Empty filter result
- Error / retry

### SCR-PROFILE-001 *(new)*
- Loading
- Empty (no personal artwork) → Explore Library CTA
- All / In Progress / Completed loaded
- Error

### SCR-PAYWALL-001
- Default
- Loading products
- Purchase in progress
- Purchase success
- Purchase fail
- Restore success
- Restore fail

---

## 11. Module → Screen Mapping

| Module ID | Module | Screen IDs | Status |
|---|---|---|---|
| MOD-001 | App Entry | SCR-ENTRY-001, SCR-ENTRY-002 | Active |
| MOD-002 | Home & Discovery | SCR-HOME-001 | Active |
| MOD-003 | Category & Drawing List | SCR-CATEGORY-001 | Legacy — not routed from Home |
| MOD-004 | Drawing Preview | SCR-PREVIEW-001 | Legacy — not routed |
| MOD-005 | Coloring Editor | SCR-EDITOR-001, SCR-COMPLETE-001 | Active |
| MOD-006 | Progress & My Works | SCR-WORKS-001, SCR-COMPLETE-001 | SCR-WORKS-001 Legacy — superseded by MOD-010 |
| MOD-007 | Monetization | SCR-PAYWALL-001 | Active |
| MOD-008 | Settings | SCR-SETTINGS-001 | Active |
| MOD-009 | Library & Discovery *(new)* | SCR-LIBRARY-001 | Active |
| MOD-010 | Profile *(new)* | SCR-PROFILE-001 | Active |

---

## 12. Feature → Screen Mapping

| Feature ID | Feature | Screen IDs | Status |
|---|---|---|---|
| FE-HOME-001 | Home Screen | SCR-HOME-001 | Active |
| FE-HOME-002 | Category List | SCR-HOME-001 | Active — now category sections |
| FE-HOME-005 | Open Category | SCR-HOME-001 → SCR-CATEGORY-001 | Legacy — superseded by FE-LIB-004 |
| FE-HOME-006 | Open Drawing from Home | SCR-HOME-001 → SCR-PREVIEW-001 | Legacy — superseded by FE-HOME-010 |
| FE-HOME-007 | Continue Coloring | SCR-HOME-001, SCR-WORKS-001, SCR-EDITOR-001 | Legacy — superseded by FE-HOME-010 |
| FE-HOME-010 *(new)* | Open Artwork from Home Direct (resume-or-create) | SCR-HOME-001 → SCR-EDITOR-001 | Active |
| FE-HOME-011 *(new)* | Bottom Navigation (Home/Library/Profile) | SCR-HOME-001, SCR-LIBRARY-001, SCR-PROFILE-001 | Active |
| FE-CAT-001 | Category Screen | SCR-CATEGORY-001 | Legacy — not routed |
| FE-CAT-002 | Drawing Grid | SCR-CATEGORY-001 | Legacy — not routed |
| FE-PREVIEW-001 | Preview Artwork | SCR-PREVIEW-001 | Legacy — not routed |
| FE-PREVIEW-002 | Start Coloring | SCR-PREVIEW-001, SCR-EDITOR-001 | Legacy — logic reassigned to FE-HOME-010/FE-LIB-003/FE-PROFILE-005 |
| FE-PREVIEW-003 | Resume Coloring | SCR-PREVIEW-001, SCR-EDITOR-001 | Legacy — logic reassigned |
| FE-EDITOR-002 | Color Selection | SCR-EDITOR-001 | Active |
| FE-EDITOR-003 | Tap-to-Fill | SCR-EDITOR-001 | Active |
| FE-EDITOR-004 | Basic Brush | SCR-EDITOR-001 | Active |
| FE-EDITOR-006 | Undo | SCR-EDITOR-001 | Active |
| FE-EDITOR-007 | Redo | SCR-EDITOR-001 | Active |
| FE-EDITOR-008 | Zoom | SCR-EDITOR-001 | Active |
| FE-EDITOR-009 | Pan | SCR-EDITOR-001 | Active |
| FE-EDITOR-011 | Autosave | SCR-EDITOR-001 | Active |
| FE-EDITOR-012 | Restore | SCR-EDITOR-001 | Active |
| FE-EDITOR-014 | Completion | SCR-EDITOR-001, SCR-COMPLETE-001 | Active — role updated |
| FE-EDITOR-022 *(new)* | Completion Recommended Artwork | SCR-COMPLETE-001 → SCR-EDITOR-001 | Active — corrected 2026-08-14 (was mistakenly FE-EDITOR-017) |
| FE-WORK-002 | My Works | SCR-WORKS-001 | Legacy — superseded by FE-PROFILE-003/004 |
| FE-WORK-006 | Save Final Image | SCR-COMPLETE-001 | Active |
| FE-WORK-008 | Share | SCR-COMPLETE-001 | Active |
| FE-MON-002 | Paywall | SCR-PAYWALL-001 | Active |
| FE-MON-004 | Restore Purchase | SCR-PAYWALL-001, SCR-SETTINGS-001 | Active |
| FE-SET-001 | Settings Screen | SCR-SETTINGS-001 | Active |
| FE-LIB-001 *(new)* | Library Screen | SCR-LIBRARY-001 | Active |
| FE-LIB-002 *(new)* | Category Filter | SCR-LIBRARY-001 | Active |
| FE-LIB-003 *(new)* | Open Artwork from Library | SCR-LIBRARY-001 → SCR-EDITOR-001 | Active |
| FE-LIB-004 *(new)* | See all → Library with Filter | SCR-HOME-001 → SCR-LIBRARY-001 | Active |
| FE-PROFILE-001 *(new)* | Profile Screen | SCR-PROFILE-001 | Active |
| FE-PROFILE-002 *(new)* | Empty State + Explore Library CTA | SCR-PROFILE-001 → SCR-LIBRARY-001 | Active |
| FE-PROFILE-003 *(new)* | Segmented View (All/Completed/In Progress) | SCR-PROFILE-001 | Active |
| FE-PROFILE-004 *(new)* | Personal Artwork Grid | SCR-PROFILE-001 | Active |
| FE-PROFILE-005 *(new)* | Open Artwork from Profile | SCR-PROFILE-001 → SCR-EDITOR-001 | Active |
| FE-PROFILE-006 *(new)* | Settings Icon Entry | SCR-PROFILE-001 → SCR-SETTINGS-001 | Active |

**Note:** Feature IDs (`FE-*`) are formally owned by `00-product/mvp-scope.md` (Step 3). The `FE-LIB-*`, `FE-PROFILE-*`, `FE-HOME-010/011`, and `FE-EDITOR-022` IDs above have been synchronized into `mvp-scope.md` (2026-08-14). The Completion Recommended Artwork feature was originally mis-assigned `FE-EDITOR-017` — an ID already owned by the pre-existing "Visual Tool Preview" feature — and has been corrected to `FE-EDITOR-022` throughout; `FE-EDITOR-017` is unchanged and still means Visual Tool Preview.

---

## 13. Screen Depth & Complexity

**Status: Updated — 2026-08-14 re-baseline.**

Current approved screen depth:

```text
Level 0
- Splash / Home / Library / Profile (root tabs)

Level 1
- Settings (via Profile)
- Paywall

Level 2
- Editor
- Completion

Legacy (preserved, not part of approved depth):
Level 1 — Category, My Works
Level 2 — Preview
```

**Principle**
- Không nên có discovery depth quá sâu.
- Từ Home đến Editor hiện tại là 1 bước (direct); từ Home → See all → Library → Editor là 2 bước.

---

## 14. Recommended Root Sitemap

**Status: Updated — 2026-08-14 re-baseline.**

```text
ROOT
├── Splash
├── Onboarding (optional)
└── Main App (Bottom Nav: Home | Library | Profile)
    ├── Home
    │   ├── Category Sections (Manga, Animal, Nature, ...)
    │   │   ├── Artwork Card → Editor (direct, resume-or-create)
    │   │   └── See all → Library (category filter active)
    │   └── PRO → Paywall
    │
    ├── Library
    │   ├── Category Filter (All / Manga / Animal / Nature / Food / ...)
    │   └── Artwork Card → Editor (direct, resume-or-create)
    │
    ├── Profile
    │   ├── Empty State → Explore Library
    │   ├── All / Completed / In Progress
    │   ├── Artwork Card → Editor (direct, resume)
    │   └── Settings Icon → Settings
    │
    └── Editor → Completion
        ├── Share (native share sheet)
        ├── Save/Download
        ├── Back to Home
        └── Recommended for you → Editor (direct, resume-or-create)
```

### 14.1 Legacy Root Sitemap (superseded, preserved for traceability)

```text
ROOT
├── Splash
├── Onboarding (optional)
└── Main App
    ├── Home
    │   ├── Category
    │   │   └── Drawing Preview
    │   │       └── Editor
    │   │           └── Completion
    │   ├── Featured Drawing Preview
    │   ├── Continue Coloring → Editor
    │   └── Premium CTA → Paywall
    │
    ├── My Works
    │   ├── In Progress → Preview / Editor
    │   └── Completed → Preview / Completion
    │
    └── Settings
        └── Restore Purchase / Legal
```

---

## 15. Critical UX Decisions Carried Forward

### UXD-001 *(SUPERSEDED — 2026-08-14, see UXD-006)*
Giữ Drawing Preview như một màn riêng.

**Reason:**  
Giảm việc user vào thẳng editor khi chưa sẵn sàng, đồng thời tạo chỗ đặt trạng thái:
- Start
- Continue
- Locked
- Completed

**Superseded by:** Explicit product decision (2026-08-14) — artwork tap goes directly to Coloring with a resume-or-create resolution rule; Preview is no longer part of the approved core flow. See §5.5, UXD-006.

### UXD-002 *(SUPERSEDED — 2026-08-14, see UXD-007)*
Giữ My Works như tab hoặc entry chính thức.

**Reason:**  
Resume flow là retention-critical.

**Superseded by:** Profile (`SCR-PROFILE-001`) is now the bottom-nav retention/resume destination. See §5.12, UXD-007.

### UXD-003
Không tạo tab Category riêng cho MVP.

**Reason:**  
Category là một phần của Home discovery, không cần tách quá sớm.

**Status:** Still valid — reinforced by the 2026-08-14 re-baseline. Category browsing now lives inline on Home (category sections) and in Library (filtered browse), not as its own bottom-nav tab.

### UXD-004
Paywall phải là child flow, không phải root destination chính.

### UXD-005
Editor không nên bị gián đoạn bởi interstitial.

### UXD-006 *(new — 2026-08-14)*
Artwork tap (Home / Library / Profile / Completion "Recommended for you") opens Coloring directly — no Preview screen in the approved MVP core flow.

**Reason:**  
Explicit product decision to reduce time-to-color; aligns with IA-001 (Fast Time to Color).

**Preserves:** `SCR-PREVIEW-001` remains for traceability; its resolution logic (locked/unlocked, resume/start) is reassigned to the artwork-tap resolver — see §5.5.

### UXD-007 *(new — 2026-08-14)*
Profile (`SCR-PROFILE-001`), not My Works, is the bottom-nav destination for personal artwork retention/resume.

**Reason:**  
Explicit product decision; Profile also unifies personal-artwork access with the Settings entry point.

**Preserves:** `SCR-WORKS-001` remains for traceability, marked Legacy/Superseded.

### UXD-008 *(new — 2026-08-14)*
Home is composed of repeatable category sections only — no separate Featured, Daily Pick, icon-based Categories grid, or dedicated Continue Coloring block.

**Reason:**  
Explicit product decision for a simpler, content-first Home structure.

**Preserves:** Legacy Home content blocks and their component/requirement IDs remain defined, marked Legacy/Superseded — see §5.3.

---

## 16. Open IA Decisions

### IA-DEC-001 — Onboarding
Có giữ onboarding ở MVP không?

**Recommendation:** Optional / lightweight only.

### IA-DEC-002 — Direct Resume — **RESOLVED 2026-08-14**
Continue Coloring từ Home mở:
- trực tiếp Editor
- hay qua Preview

**Resolution:** Direct Editor, for all artwork taps (not only Continue Coloring), via resume-or-create rule. No Preview hop. See UXD-006, FLOW-COLOR-001.

### IA-DEC-003 — Completion Screen
Có screen riêng hay modal/result state?

**Recommendation:**  
Screen riêng nếu timeline cho phép.

### IA-DEC-004 — Daily Drawing
Daily là block trên Home hay collection logic riêng?

### IA-DEC-005 — Paywall Entry Timing
Khi nào hiện paywall lần đầu?

### IA-DEC-006 — Rewarded Unlock Placement
Rewarded unlock nằm ở Preview hay locked tile?

---

## 17. Step 4 Deliverables Summary

Tài liệu này đã xác định:

- Screen inventory chính thức.
- Screen IDs.
- Navigation structure.
- Root sitemap.
- Primary flows.
- Alternative/exception flows.
- Screen states ở mức IA.
- Module → Screen mapping.
- Feature → Screen mapping.
- Open IA decisions.

Đây là nền tảng để viết Requirement chi tiết và thiết kế UI ở các bước tiếp theo.

---

# AI EXECUTION INSTRUCTIONS — STEP 4 HANDOFF

## Step Identity

**Step 4 = Information Architecture & User Flow**

### Required Input
- `product-brief.md`
- `competitor-analysis.md`
- `mvp-scope.md`
- Any new confirmed product decisions from boss/user.

### AI Role
Act as:
- Senior Product Architect
- Senior Business Analyst
- UX Flow Designer

### AI Responsibilities
1. Read all approved artifacts from previous steps.
2. Preserve all confirmed product decisions.
3. Convert MVP scope into official screens.
4. Assign stable Screen IDs and Flow IDs.
5. Define root navigation and movement between screens.
6. Define primary, secondary, premium, empty, error, resume, and offline flows.
7. Map:
   - Module → Screen
   - Feature → Screen
   - Flow → Screen
8. Avoid detailed UI layout or visual design choices at this stage.
9. Keep the IA simple and MVP-aligned.

### Required Output
Create/update `information-architecture-user-flow.md` containing:
- IA overview
- Screen inventory
- Screen purposes
- Entry/exit points
- Navigation architecture
- Flow inventory
- Primary flows
- Alternative flows
- States
- Module → Screen mapping
- Feature → Screen mapping
- IA decisions and open questions

## Next Step Handoff

**Next Step = Step 5 — Requirement Catalog & Acceptance Criteria**

In a new chat, the user may say:

> Read `project-workflow.md`, `product-brief.md`, `competitor-analysis.md`, `mvp-scope.md`, and `information-architecture-user-flow.md`, then continue Step 5.

The AI must:
1. Read all previous artifacts first.
2. Preserve confirmed product decisions and IA decisions.
3. Generate structured requirements with stable IDs.
4. Include:
   - Functional Requirements
   - Business Rules
   - Non-functional Requirements
   - Acceptance Criteria
   - Preconditions
   - Postconditions
   - Edge cases
   - Error behavior
5. Maintain traceability:
   - Module ID
   - Feature ID
   - Screen ID
   - Flow ID
6. Produce `requirements.md`.
