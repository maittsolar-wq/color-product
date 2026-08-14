# Requirement Catalog & Acceptance Criteria — Coloring App

**Document ID:** REQ-COLOR-001  
**Version:** 0.1  
**Status:** Draft  
**Related Documents:**  
- `00-product/product-brief.md`
- `00-product/competitor-analysis.md`
- `00-product/mvp-scope.md`
- `01-architecture/information-architecture-user-flow.md`

---

# 1. Purpose

Tài liệu này chuyển Product Brief, MVP Scope và Information Architecture thành tập requirement có thể dùng trực tiếp cho:

- UI/UX Design
- Development
- Functional Specification
- Test Case Generation
- Automation
- Regression
- Traceability

Mỗi requirement phải có ID ổn định và liên kết tới:

`Module → Feature → Screen → Flow → Requirement`

---

# 2. Requirement Rules

## 2.1 Requirement Types

### Functional Requirement
Format:

`REQ-<MODULE>-XXX`

Ví dụ:

- `REQ-HOME-001`
- `REQ-EDITOR-001`
- `REQ-MON-001`

### Business Rule
Format:

`BR-<MODULE>-XXX`

### Non-Functional Requirement
Format:

`NFR-<AREA>-XXX`

Ví dụ:

- `NFR-PERF-001`
- `NFR-REL-001`
- `NFR-UX-001`

---

## 2.2 Requirement Status

Mỗi requirement ở tài liệu này mặc định:

**Status: Draft**

cho tới khi Product/BA review và chuyển thành:

**Status: Approved**

---

# 3. Global Product Rules

## BR-GLOBAL-001 — No Art Knowledge Required

Ứng dụng không được yêu cầu người dùng hiểu kiến thức mỹ thuật hoặc quy tắc phối màu để hoàn thành core coloring flow.

**Source:** Product Principle PP-002

---

## BR-GLOBAL-002 — No Wrong Color

Ứng dụng không được đánh giá màu người dùng chọn là đúng/sai trong core coloring experience.

**Source:** PP-003

---

## BR-GLOBAL-003 — Content First

Artwork phải là thành phần visual chính trong discovery và editor.

**Source:** PP-005

---

## BR-GLOBAL-004 — Progress Preservation

Ứng dụng phải ưu tiên bảo toàn progress của artwork đang tô.

**Source:** PP-007

---

## BR-GLOBAL-005 — Cross-Age Friendly

Core navigation và editor phải đủ rõ cho cả casual adult user và trẻ em có khả năng sử dụng mobile app cơ bản.

**Source:** PP-008

---

# 4. MOD-001 — App Entry Requirements

## REQ-ENTRY-001 — Launch Application

**Feature:** FE-ENTRY-001  
**Screen:** SCR-ENTRY-001  
**Flow:** FLOW-ENTRY-001  

Ứng dụng phải có thể launch thành công từ trạng thái chưa chạy.

### Acceptance Criteria

**AC-ENTRY-001-01**

Given app đã được cài đặt hợp lệ  
When user mở app  
Then ứng dụng phải khởi động mà không crash.

**AC-ENTRY-001-02**

Given app đang ở cold start  
When launch hoàn tất  
Then user phải được chuyển tới Splash hoặc route phù hợp.

---

## REQ-ENTRY-002 — Splash Display

**Feature:** FE-ENTRY-002  
**Screen:** SCR-ENTRY-001  
**Flow:** FLOW-ENTRY-001  

Ứng dụng phải hiển thị Splash trong quá trình initialize.

### Acceptance Criteria

**AC-ENTRY-002-01**

Given user launch app  
When initialization đang diễn ra  
Then Splash phải hiển thị.

**AC-ENTRY-002-02**

Given initialization hoàn tất  
When routing được xác định  
Then Splash phải tự đóng.

---

## REQ-ENTRY-003 — First-Time Routing

**Feature:** FE-ENTRY-003  
**Screen:** SCR-ENTRY-001, SCR-ENTRY-002  
**Flow:** FLOW-ENTRY-001  

Ứng dụng phải xác định user đã hoàn thành onboarding hay chưa.

### Acceptance Criteria

**AC-ENTRY-003-01**

Given user chưa hoàn thành onboarding  
When app launch  
Then app có thể điều hướng tới Onboarding nếu feature này được bật.

**AC-ENTRY-003-02**

Given user đã hoàn thành onboarding  
When app launch  
Then app phải bỏ qua onboarding.

---

## REQ-ENTRY-004 — Home Routing

**Feature:** FE-ENTRY-004  
**Screen:** SCR-HOME-001  
**Flow:** FLOW-ENTRY-001  

Sau entry flow hợp lệ, user phải được đưa tới Home.

---

# 5. MOD-002 — Home & Discovery Requirements

**Status: Updated — 2026-08-14 re-baseline.** Home content model changed from Featured/Daily/Continue/Category-grid blocks to repeatable category sections. Legacy requirements below are preserved, not deleted, and marked accordingly.

## REQ-HOME-001 — Display Home Content

**Feature:** FE-HOME-001  
**Screen:** SCR-HOME-001  

Home phải hiển thị các khối discovery chính đã được bật trong MVP.

### Minimum Content Blocks (approved 2026-08-14)

- Repeatable category sections (e.g. Manga, Animal, Nature), each with title + See all + horizontally scrollable artwork cards
- PRO entry
- Bottom navigation (Home / Library / Profile)

### Legacy Content Blocks (preserved, superseded — not part of approved structure)

- Categories (icon grid)
- Featured/New
- Continue Coloring
- Daily

### Acceptance Criteria

**AC-HOME-001-01**

Given Home load thành công  
When user mở Home  
Then ít nhất một category section phải hiển thị.

---

## REQ-HOME-002 — Display Categories

**Feature:** FE-HOME-002  
**Screen:** SCR-HOME-001  
**Flow:** FLOW-LIBRARY-001 *(updated — was FLOW-DISCOVER-001, legacy)*

Home phải hiển thị category sections khả dụng (title + See all + horizontal artwork list), thay cho icon-based category grid trước đây.

### Acceptance Criteria

Given category data tồn tại  
When Home load  
Then category section phải hiển thị với tên và artwork cards phù hợp.

---

## REQ-HOME-003 — Open Category

**Status: LEGACY — superseded by `REQ-HOME-008` (2026-08-14). Preserved, not routed from approved Home flow.**

**Feature:** FE-HOME-005  
**Screen:** SCR-HOME-001 → SCR-CATEGORY-001  
**Flow:** FLOW-DISCOVER-001  

User phải có thể tap một category để mở danh sách artwork tương ứng.

### Acceptance Criteria

Given user đang ở Home  
When user tap category X  
Then Category Screen phải mở  
And chỉ artwork thuộc category X hoặc collection mapping hợp lệ được hiển thị.

---

## REQ-HOME-004 — Display Drawing Thumbnail

**Feature:** FE-HOME-004  
**Screen:** SCR-HOME-001  

Artwork được hiển thị trên Home phải có thumbnail rõ ràng và đúng asset.

---

## REQ-HOME-005 — Open Drawing from Home

**Status: LEGACY — superseded by `REQ-HOME-009` (2026-08-14). Preserved, not routed from approved Home flow.**

**Feature:** FE-HOME-006  
**Screen:** SCR-HOME-001 → SCR-PREVIEW-001  

Nếu artwork xuất hiện trực tiếp trên Home, user phải có thể tap để mở Drawing Preview.

---

## REQ-HOME-006 — Continue Coloring

**Status: LEGACY — superseded by `REQ-HOME-009` (2026-08-14), which applies the resume-or-create rule to every artwork card, not just a dedicated Continue Coloring block. Preserved, not part of approved Home structure.**

**Feature:** FE-HOME-007  
**Screen:** SCR-HOME-001  
**Flow:** FLOW-RESUME-001  

Nếu tồn tại artwork đang tô, Home nên hiển thị entry Continue Coloring.

### Acceptance Criteria

Given user có ít nhất một artwork In Progress  
When Home load  
Then Continue Coloring phải hiển thị nếu feature được bật.

---

## REQ-HOME-007 — Empty/Partial Content Handling

**Screen:** SCR-HOME-001  
**Flow:** FLOW-ERROR-001  

Home phải xử lý graceful khi một số block content không load được.

### Acceptance Criteria

Given một category section lỗi  
But các category sections khác vẫn khả dụng  
When Home load  
Then các sections còn lại vẫn phải sử dụng được  
And app không được chuyển toàn Home sang trạng thái unusable.

---

## REQ-HOME-008 — See All → Library With Category Filter *(new — 2026-08-14)*

**Feature:** FE-LIB-004  
**Screen:** SCR-HOME-001 → SCR-LIBRARY-001  
**Flow:** FLOW-LIBRARY-001  

User phải có thể tap "See all" trên một category section để mở Library với filter của category đó đang active.

### Acceptance Criteria

Given user đang ở Home, category section "Manga"  
When user tap "See all"  
Then SCR-LIBRARY-001 phải mở  
And filter "Manga" phải active.

---

## REQ-HOME-009 — Open Artwork From Home Direct (Resume-or-Create) *(new — 2026-08-14)*

**Feature:** FE-HOME-010  
**Screen:** SCR-HOME-001 → SCR-EDITOR-001  
**Flow:** FLOW-COLOR-001, FLOW-RESUME-001  

User phải có thể tap bất kỳ artwork card nào trên Home để mở Coloring Editor trực tiếp, không qua Preview.

### Acceptance Criteria

**AC-HOME-009-01**

Given artwork đã có progress (In Progress)  
When user tap artwork card  
Then progress hiện có phải được restore  
And SCR-EDITOR-001 phải mở với đúng artwork.

**AC-HOME-009-02**

Given artwork chưa có progress  
When user tap artwork card  
Then một progress record mới phải được tạo  
And SCR-EDITOR-001 phải mở với đúng artwork.

---

## REQ-HOME-010 — Bottom Navigation: Home / Library / Profile *(new — 2026-08-14)*

**Feature:** FE-HOME-011  
**Screen:** SCR-HOME-001, SCR-LIBRARY-001, SCR-PROFILE-001  

App phải cung cấp bottom navigation gồm 3 tab: Home, Library, Profile.

### Acceptance Criteria

Given user tap tab Library  
When điều hướng hoàn tất  
Then SCR-LIBRARY-001 phải mở với filter "All" active.

Given user tap tab Profile  
When điều hướng hoàn tất  
Then SCR-PROFILE-001 phải mở.

### Business Rule

Settings không còn là bottom-nav tab; Settings được truy cập qua Profile → Settings icon (`REQ-PROFILE-006`).

---

# 6. MOD-003 — Category & Drawing List Requirements

**Status: LEGACY — 2026-08-14 re-baseline.** `SCR-CATEGORY-001` is no longer a Home navigation destination in the approved MVP core flow. All requirements below are preserved for traceability, not deleted or renamed. Browse/filter concepts may inform `SCR-LIBRARY-001` (MOD-009), which uses new, distinct IDs.

## REQ-CAT-001 — Display Category Screen

**Feature:** FE-CAT-001  
**Screen:** SCR-CATEGORY-001  

Category Screen phải hiển thị category đang được chọn.

---

## REQ-CAT-002 — Display Drawing Grid

**Feature:** FE-CAT-002  
**Screen:** SCR-CATEGORY-001  

Artwork phải hiển thị ở dạng grid/list phù hợp mobile.

---

## REQ-CAT-003 — Drawing State Indicator

**Feature:** FE-CAT-003  
**Screen:** SCR-CATEGORY-001  

Mỗi artwork phải có khả năng phản ánh state tương ứng:

- New / untouched
- In Progress
- Completed
- Locked/Premium nếu có

---

## REQ-CAT-004 — Select Drawing

**Feature:** FE-CAT-004  
**Screen:** SCR-CATEGORY-001 → SCR-PREVIEW-001  
**Flow:** FLOW-DISCOVER-001  

User phải có thể tap artwork để mở Drawing Preview.

---

## REQ-CAT-005 — Empty Category

**Screen:** SCR-CATEGORY-001  
**Flow:** FLOW-EMPTY-001  

Nếu category không có artwork, app phải hiển thị empty state thay vì màn trắng.

---

## REQ-CAT-006 — Category Load Error

**Screen:** SCR-CATEGORY-001  
**Flow:** FLOW-ERROR-001  

Nếu artwork list không load được, app phải hiển thị error state và Retry.

---

# 7. MOD-004 — Drawing Preview Requirements

**Status: LEGACY — 2026-08-14 re-baseline.** `SCR-PREVIEW-001` is no longer routed from the approved MVP core discovery flow. All requirements below are preserved for traceability, not deleted or renamed. Locked/unlocked resolution and resume/start CTA logic previously owned exclusively here are reassigned to the artwork-tap resolver on Home/Library/Profile — see `REQ-HOME-009`, `REQ-LIB-003`, `REQ-PROFILE-005`.

## REQ-PREVIEW-001 — Display Artwork Preview

**Feature:** FE-PREVIEW-001  
**Screen:** SCR-PREVIEW-001  

Preview phải hiển thị đúng artwork user vừa chọn.

---

## REQ-PREVIEW-002 — Start Coloring

**Feature:** FE-PREVIEW-002  
**Screen:** SCR-PREVIEW-001 → SCR-EDITOR-001  
**Flow:** FLOW-COLOR-001  

User phải có thể bắt đầu tô một artwork khả dụng.

### Acceptance Criteria

Given artwork free/unlocked  
When user tap Start  
Then Editor phải mở với đúng artwork.

---

## REQ-PREVIEW-003 — Resume Coloring

**Feature:** FE-PREVIEW-003  
**Screen:** SCR-PREVIEW-001 → SCR-EDITOR-001  
**Flow:** FLOW-RESUME-001  

Nếu artwork có progress, CTA chính phải cho phép tiếp tục.

---

## REQ-PREVIEW-004 — Locked Artwork

**Feature:** FE-PREVIEW-004  
**Screen:** SCR-PREVIEW-001 → SCR-PAYWALL-001  
**Flow:** FLOW-PREMIUM-001  

Artwork locked không được mở Editor trực tiếp nếu user chưa có quyền.

---

## REQ-PREVIEW-005 — Completed Artwork

**Feature:** FE-PREVIEW-005  
**Screen:** SCR-PREVIEW-001  

Nếu artwork Completed, user phải có thể xem trạng thái hoàn thành và có entry để xem hoặc tô lại nếu business cho phép.

---

# 8. MOD-005 — Coloring Editor Requirements

## REQ-EDITOR-001 — Load Canvas

**Feature:** FE-EDITOR-001  
**Screen:** SCR-EDITOR-001  

Editor phải load đúng artwork với canvas rõ ràng.

---

## REQ-EDITOR-002 — Select Color

**Feature:** FE-EDITOR-002  
**Screen:** SCR-EDITOR-001  

User phải có thể chọn một màu từ palette.

### Acceptance Criteria

Given palette đang hiển thị  
When user chọn màu X  
Then X phải trở thành active color.

---

## REQ-EDITOR-003 — Tap-to-Fill Region

**Feature:** FE-EDITOR-003  
**Screen:** SCR-EDITOR-001  
**Flow:** FLOW-COLOR-001  

User phải có thể tap vào một vùng khép kín để fill active color.

### Acceptance Criteria

Given active color = Red  
And region A chưa tô  
When user tap bên trong region A  
Then toàn bộ region A phải chuyển thành Red  
And region B liền kề không được thay đổi.

### Edge Cases

- Tap trực tiếp trên outline.
- Tap gần ranh giới.
- Tap vùng rất nhỏ.
- Tap liên tục nhiều lần.

---

## REQ-EDITOR-004 — Basic Brush

**Feature:** FE-EDITOR-004  
**Screen:** SCR-EDITOR-001  

Nếu hybrid coloring nằm trong MVP, user phải có thể dùng brush để tô tự do.

---

## REQ-EDITOR-005 — Eraser

**Feature:** FE-EDITOR-005  
**Screen:** SCR-EDITOR-001  

User phải có thể dùng eraser cho các thao tác brush/free coloring.

---

## REQ-EDITOR-006 — Undo

**Feature:** FE-EDITOR-006  
**Screen:** SCR-EDITOR-001  

Undo phải hoàn tác thao tác có thể hoàn tác gần nhất.

### Acceptance Criteria

Given user vừa fill một vùng  
When user tap Undo  
Then trạng thái trước action đó phải được restore.

---

## REQ-EDITOR-007 — Redo

**Feature:** FE-EDITOR-007  
**Screen:** SCR-EDITOR-001  

Redo phải restore action vừa Undo nếu chưa phát sinh action mới phá redo stack.

---

## REQ-EDITOR-008 — Zoom

**Feature:** FE-EDITOR-008  
**Screen:** SCR-EDITOR-001  

User phải có thể pinch để zoom canvas.

---

## REQ-EDITOR-009 — Pan

**Feature:** FE-EDITOR-009  
**Screen:** SCR-EDITOR-001  

Khi canvas đang zoom, user phải có thể pan để di chuyển vùng nhìn.

---

## REQ-EDITOR-010 — Prevent Accidental Progress Loss

**Feature:** FE-EDITOR-010  
**Screen:** SCR-EDITOR-001  

Thoát Editor không được làm mất progress đã tạo.

---

## REQ-EDITOR-011 — Autosave

**Feature:** FE-EDITOR-011  
**Screen:** SCR-EDITOR-001  
**Flow:** FLOW-RESUME-001  

Progress phải được autosave ở các trigger phù hợp.

### Minimum Save Triggers

- User thực hiện thay đổi có ý nghĩa.
- User back khỏi Editor.
- App chuyển background.
- App close/terminate nếu platform cho phép xử lý.
- User Complete.

---

## REQ-EDITOR-012 — Restore Progress

**Feature:** FE-EDITOR-012  
**Screen:** SCR-EDITOR-001  
**Flow:** FLOW-RESUME-001  

Khi mở lại artwork In Progress, state phải restore đúng.

### Acceptance Criteria

Given user đã tô region A = Red  
And region B = Blue  
When app bị đóng và artwork được mở lại  
Then region A phải vẫn Red  
And region B phải vẫn Blue.

---

## REQ-EDITOR-013 — Reset Drawing

**Feature:** FE-EDITOR-013  
**Screen:** SCR-EDITOR-001  

User có thể reset artwork về trạng thái ban đầu sau confirmation.

### Business Rule

Reset là destructive action và phải có confirmation.

---

## REQ-EDITOR-014 — Complete Drawing

**Feature:** FE-EDITOR-014  
**Screen:** SCR-EDITOR-001 → SCR-COMPLETE-001  
**Flow:** FLOW-COMPLETE-001  

User phải có thể đánh dấu artwork là Completed.

---

## REQ-EDITOR-015 — Multiple Palettes

**Feature:** FE-EDITOR-015  
**Screen:** SCR-EDITOR-001  
**Priority:** SHOULD  

Nếu có nhiều palette, user phải có thể chuyển palette mà không mất active artwork state.

---

## REQ-EDITOR-016 — Brush Size

**Feature:** FE-EDITOR-016  
**Screen:** SCR-EDITOR-001  
**Priority:** SHOULD  

Nếu brush nằm trong MVP, user nên có thể thay đổi brush size.

---

## REQ-EDITOR-017 — Completion Recommended Artwork *(new — 2026-08-14)*

**Feature:** FE-EDITOR-022 *(corrected 2026-08-14 — was mistakenly FE-EDITOR-017, which is the pre-existing "Visual Tool Preview" feature; see mvp-scope.md)*  
**Screen:** SCR-COMPLETE-001 → SCR-EDITOR-001  
**Flow:** FLOW-COMPLETE-001  

Completion screen phải hiển thị "Recommended for you" — danh sách artwork cards. Tap vào một artwork phải mở Coloring Editor trực tiếp, áp dụng resume-or-create rule giống `REQ-HOME-009`.

### Acceptance Criteria

Given user đang ở SCR-COMPLETE-001  
When user tap một artwork trong "Recommended for you"  
Then app phải resolve progress (restore nếu có, tạo mới nếu chưa có)  
And SCR-EDITOR-001 phải mở với đúng artwork.

---

# 9. MOD-006 — Progress & My Works Requirements

**Status: Partially LEGACY — 2026-08-14 re-baseline.** `SCR-WORKS-001` (My Works) is superseded by `SCR-PROFILE-001` (MOD-010) as the bottom-nav personal-artwork destination. Requirements describing persistence behavior (data-layer, not screen-specific) remain fully active; requirements describing the `SCR-WORKS-001` screen itself are marked Legacy below.

## REQ-WORK-001 — Persist Artwork Progress

**Feature:** FE-WORK-001  
**Screen:** SCR-EDITOR-001, SCR-WORKS-001  

Artwork đã thay đổi phải được lưu vào local persistence.

---

## REQ-WORK-002 — Display My Works

**Status: LEGACY — superseded by `REQ-PROFILE-003`/`REQ-PROFILE-004` (2026-08-14). Preserved, not routed from bottom navigation.**

**Feature:** FE-WORK-002  
**Screen:** SCR-WORKS-001  
**Flow:** FLOW-WORKS-001  

My Works phải hiển thị artwork user đã bắt đầu hoặc hoàn thành.

---

## REQ-WORK-003 — Resume from My Works

**Status: LEGACY — superseded by `REQ-PROFILE-005` (2026-08-14). Preserved, not routed.**

**Feature:** FE-WORK-003  
**Screen:** SCR-WORKS-001 → SCR-EDITOR-001 / SCR-PREVIEW-001  
**Flow:** FLOW-RESUME-001  

User phải có thể tiếp tục artwork In Progress từ My Works.

---

## REQ-WORK-004 — Completed State

**Status: LEGACY — superseded by `REQ-PROFILE-003` (2026-08-14). Preserved, not routed.**

**Feature:** FE-WORK-004  
**Screen:** SCR-WORKS-001  

Artwork Completed phải được phân biệt với In Progress.

---

## REQ-WORK-005 — Local Persistence After Relaunch

**Feature:** FE-WORK-005  

Progress phải tồn tại sau app relaunch.

---

## REQ-WORK-006 — Save Final Image

**Status: Updated — 2026-08-14, promoted to core Completion behavior.**

**Feature:** FE-WORK-006  
**Screen:** SCR-COMPLETE-001  
**Priority:** SHOULD  

User phải có thể save rendered colored artwork image xuống thiết bị ("Save/Download" trên Completion).

---

## REQ-WORK-007 — Save to Gallery

**Feature:** FE-WORK-007  
**Priority:** SHOULD  

Nếu user chọn Save to Device, app phải yêu cầu quyền hệ thống phù hợp khi cần.

---

## REQ-WORK-008 — Share

**Status: Updated — 2026-08-14, production implementation invokes native device share sheet.**

**Feature:** FE-WORK-008  
**Screen:** SCR-COMPLETE-001  
**Priority:** SHOULD  

App phải hỗ trợ native device share sheet cho artwork hoàn thành ("Share" trên Completion).

---

# 10. MOD-007 — Monetization Requirements

> Các requirement dưới đây chỉ được kích hoạt nếu Monetization nằm trong MVP.

## BR-MON-001 — Premium Entitlement

User có Premium entitlement hợp lệ phải được cấp quyền Premium tương ứng.

---

## REQ-MON-001 — Free/Premium Content State

**Feature:** FE-MON-001  

System phải phân biệt content Free và Premium.

---

## REQ-MON-002 — Display Paywall

**Feature:** FE-MON-002  
**Screen:** SCR-PAYWALL-001  
**Flow:** FLOW-PREMIUM-001  

Paywall phải hiển thị quyền lợi Premium rõ ràng.

---

## REQ-MON-003 — Purchase Subscription / IAP

**Feature:** FE-MON-003  
**Screen:** SCR-PAYWALL-001  

User phải có thể bắt đầu purchase flow.

---

## REQ-MON-004 — Restore Purchase

**Feature:** FE-MON-004  
**Screen:** SCR-PAYWALL-001, SCR-SETTINGS-001  

User phải có thể restore purchase hợp lệ.

---

## REQ-MON-005 — Apply Premium State

**Feature:** FE-MON-005  

Sau purchase/restore thành công, Premium state phải được áp dụng mà không yêu cầu user reinstall app.

---

## REQ-MON-006 — Premium Removes Ads

**Feature:** FE-MON-006  

Nếu Premium package bao gồm No Ads, app không được hiển thị ad format bị loại trừ cho Premium user.

---

## REQ-MON-007 — Rewarded Unlock

**Feature:** FE-MON-007  
**Flow:** FLOW-REWARD-001  
**Priority:** SHOULD  

Nếu rewarded unlock được bật:

Given user hoàn thành rewarded ad hợp lệ  
When reward callback thành công  
Then artwork/tool tương ứng phải được unlock theo business rule.

---

## BR-MON-002 — No Interstitial During Active Coloring

Interstitial không được hiển thị trong active coloring session khi user đang thao tác trên canvas.

---

## BR-MON-003 — Preserve Context Around Paywall

Sau khi user đóng Paywall hoặc purchase xong, app phải đưa user về context hợp lý trước đó.

---

# 11. MOD-008 — Settings Requirements

## REQ-SET-001 — Settings Screen

**Feature:** FE-SET-001  
**Screen:** SCR-SETTINGS-001  

App phải có Settings screen cơ bản.

---

## REQ-SET-002 — Privacy Policy

**Feature:** FE-SET-003  

User phải có thể truy cập Privacy Policy.

---

## REQ-SET-003 — Terms

**Feature:** FE-SET-004  

User phải có thể truy cập Terms nếu business/legal yêu cầu.

---

## REQ-SET-004 — App Version

**Feature:** FE-SET-005  

Settings phải hiển thị version/build nếu cần cho support/debug.

---

## REQ-SET-005 — Restore Purchase Entry

Nếu monetization được bật, Settings phải cung cấp entry Restore Purchase.

---

# 12. MOD-009 — Library & Discovery Requirements *(new — 2026-08-14)*

## REQ-LIB-001 — Display Library Screen

**Feature:** FE-LIB-001  
**Screen:** SCR-LIBRARY-001  

Library phải hiển thị artwork grid với category filter.

### Acceptance Criteria

Given Library load thành công  
When user mở Library  
Then artwork grid và filter control phải hiển thị.

---

## REQ-LIB-002 — Filter By Category

**Feature:** FE-LIB-002  
**Screen:** SCR-LIBRARY-001  

User phải có thể filter artwork theo category (All, Manga, Animal, Nature, Food, v.v.).

### Acceptance Criteria

Given user chọn filter "Nature"  
When filter áp dụng  
Then chỉ artwork thuộc category Nature được hiển thị.

---

## REQ-LIB-003 — Open Artwork From Library

**Feature:** FE-LIB-003  
**Screen:** SCR-LIBRARY-001 → SCR-EDITOR-001  
**Flow:** FLOW-LIBRARY-001  

User phải có thể tap artwork trong Library để mở Coloring Editor trực tiếp, áp dụng resume-or-create rule giống `REQ-HOME-009`.

---

## REQ-LIB-004 — Entry With Pre-Applied Filter

**Feature:** FE-LIB-004  
**Screen:** SCR-HOME-001 → SCR-LIBRARY-001  
**Flow:** FLOW-LIBRARY-001  

Khi Library được mở từ Home "See all", filter tương ứng phải active mặc định. Khi mở từ Bottom Nav, filter "All" phải active mặc định.

---

## REQ-LIB-005 — Empty Filter Result

**Feature:** FE-LIB-002  
**Screen:** SCR-LIBRARY-001  
**Flow:** FLOW-EMPTY-001  

Nếu filter không có artwork tương ứng, app phải hiển thị empty state thay vì màn trắng.

---

## REQ-LIB-006 — Library Load Error

**Feature:** FE-LIB-001  
**Screen:** SCR-LIBRARY-001  
**Flow:** FLOW-ERROR-001  

Nếu artwork list không load được, app phải hiển thị error state và Retry.

---

# 13. MOD-010 — Profile Requirements *(new — 2026-08-14)*

## BR-PROFILE-001 — Personal Artwork State Rule

User rời Coloring Editor mà không nhấn Done:
- artwork status = `IN_PROGRESS`
- artwork xuất hiện ở Profile / All
- artwork xuất hiện ở Profile / In Progress
- artwork không xuất hiện ở Profile / Completed

User nhấn Done trong Coloring Editor:
- artwork status = `COMPLETED`
- artwork xuất hiện ở Profile / All
- artwork xuất hiện ở Profile / Completed
- artwork không còn xuất hiện ở Profile / In Progress

**Source:** Explicit product decision, 2026-08-14.

---

## REQ-PROFILE-001 — Display Profile Screen

**Feature:** FE-PROFILE-001  
**Screen:** SCR-PROFILE-001  

Profile phải hiển thị personal artwork của user, phân đoạn theo All / Completed / In Progress.

---

## REQ-PROFILE-002 — Empty State

**Feature:** FE-PROFILE-002  
**Screen:** SCR-PROFILE-001  
**Flow:** FLOW-PROFILE-001  

Nếu user chưa có personal artwork, Profile phải hiển thị empty state kèm CTA "Explore Library".

### Acceptance Criteria

Given user chưa có artwork nào (In Progress hoặc Completed)  
When Profile load  
Then empty state phải hiển thị  
And CTA "Explore Library" phải mở SCR-LIBRARY-001.

---

## REQ-PROFILE-003 — Segmented View

**Feature:** FE-PROFILE-003  
**Screen:** SCR-PROFILE-001  

Profile phải cung cấp 3 segment: All, Completed, In Progress. Xem `BR-PROFILE-001` cho quy tắc phân loại.

---

## REQ-PROFILE-004 — Personal Artwork Grid

**Feature:** FE-PROFILE-004  
**Screen:** SCR-PROFILE-001  

Mỗi segment phải hiển thị artwork grid tương ứng với trạng thái đã chọn.

---

## REQ-PROFILE-005 — Open Artwork From Profile

**Feature:** FE-PROFILE-005  
**Screen:** SCR-PROFILE-001 → SCR-EDITOR-001  
**Flow:** FLOW-PROFILE-001  

User phải có thể tap artwork trong Profile để mở Coloring Editor trực tiếp. Vì artwork trong Profile luôn có progress, hành vi luôn là restore (không có nhánh tạo mới).

---

## REQ-PROFILE-006 — Settings Icon Entry

**Feature:** FE-PROFILE-006  
**Screen:** SCR-PROFILE-001 → SCR-SETTINGS-001  

Profile phải cung cấp Settings icon để mở `SCR-SETTINGS-001`. `SCR-SETTINGS-001` vẫn là màn hình riêng biệt, không bị gộp vào Profile.

---

## REQ-PROFILE-007 — Artwork State Sync

**Feature:** FE-PROFILE-004  
**Screen:** SCR-PROFILE-001  

Profile phải phản ánh chính xác trạng thái artwork (`IN_PROGRESS` / `COMPLETED`) ngay sau khi user rời Coloring Editor, theo `BR-PROFILE-001`.

---

# 14. Content Requirements

## REQ-CONTENT-001 — Artwork Metadata

Mỗi artwork phải có ít nhất:

- ID duy nhất
- Title
- Category ID
- Thumbnail
- Coloring asset
- Lock state
- Premium state nếu có

---

## REQ-CONTENT-002 — Category Metadata

Mỗi category phải có:

- ID duy nhất
- Name
- Thumbnail/icon
- Display order
- Active state

---

## BR-CONTENT-001 — Artwork Standard

Artwork MVP phải tuân thủ:

- Black & white
- 1:1
- Không border frame
- Outer contour dày hơn
- Inner lines vừa phải
- Vùng tô rõ
- Không text
- Không watermark
- Thumbnail readable
- Dễ thao tác bằng touch

---

## REQ-CONTENT-003 — Missing Asset Handling

Nếu artwork asset bị thiếu hoặc lỗi, app không được crash.

App phải:
- hiển thị fallback/error state;
- cho phép Retry hoặc quay lại.

---

# 15. Non-Functional Requirements

## NFR-PERF-001 — App Launch Performance

App launch không được tạo cảm giác treo hoặc unresponsive trong điều kiện thiết bị hỗ trợ.

---

## NFR-PERF-002 — Editor Interaction Responsiveness

Các thao tác:

- Tap-to-fill
- Undo
- Redo
- Zoom
- Pan

phải phản hồi đủ nhanh để trải nghiệm tô không bị gián đoạn rõ rệt.

---

## NFR-REL-001 — No Progress Corruption

Progress persistence không được tạo state corrupt khiến artwork không thể mở lại.

---

## NFR-REL-002 — Autosave Reliability

Autosave phải hoạt động ổn định qua:
- navigation back;
- app background;
- relaunch.

---

## NFR-STAB-001 — Core Flow Crash-Free

Core flow:

`Launch → Home → Category → Preview → Editor → Color → Save/Resume`

không được có crash blocker.

---

## NFR-UX-001 — Touch Target Clarity

Các control chính phải đủ lớn và dễ tap bằng ngón tay.

---

## NFR-UX-002 — Low Cognitive Load

Editor không được hiển thị quá nhiều tool cùng lúc nếu chúng không cần thiết cho core task.

---

## NFR-UX-003 — First Coloring Clarity

User mới phải có thể hiểu cách bắt đầu tô mà không cần tutorial dài.

---

## NFR-OFFLINE-001 — Local Progress Availability

Progress đã lưu local phải xem/restore được khi không có mạng, nếu asset tương ứng đã có trên device.

---

## NFR-SEC-001 — Purchase Integrity

Premium entitlement không được cấp nếu purchase/restore chưa được xác nhận hợp lệ.

---

## NFR-CONTENT-001 — Thumbnail Readability

Artwork thumbnail phải đủ rõ để user nhận biết subject trên mobile list/grid.

---

# 16. Preconditions & Postconditions

## Coloring Flow

### Preconditions
- Artwork tồn tại.
- Asset load được.
- User có quyền truy cập artwork.

### Postconditions
- Editor mở đúng artwork.
- Mọi thay đổi hợp lệ được đưa vào progress state.

---

## Resume Flow

### Preconditions
- Artwork có progress data hợp lệ.

### Postconditions
- Editor restore đúng state gần nhất.

---

## Premium Flow

### Preconditions
- Product configuration khả dụng.
- Monetization enabled.

### Postconditions — Purchase Success
- Entitlement cập nhật.
- Locked content/tool trở nên accessible.

### Postconditions — Failure
- User không bị cấp Premium sai.
- Context cũ được bảo toàn.

---

# 17. Error Behavior Catalog

## ERR-001 — Category Load Failure

Expected:
- Show error state.
- Retry available.
- Back usable.

## ERR-002 — Artwork Asset Missing

Expected:
- No crash.
- Error/fallback.
- Retry/back.

## ERR-003 — Save Failure

Expected:
- User được thông báo nếu progress chưa save thành công.
- App không được giả định Saved khi chưa xác nhận.

## ERR-004 — Restore Failure

Expected:
- App không crash.
- Cho phép fallback hoặc retry.
- Không tự reset progress mà không thông báo.

## ERR-005 — Purchase Failure

Expected:
- No entitlement granted.
- Error feedback.
- User remains in valid navigation state.

## ERR-006 — Rewarded Ad Failure

Expected:
- Không unlock reward nếu ad completion không hợp lệ.
- User vẫn có thể quay lại.

---

# 18. Edge Case Catalog

## EDGE-EDITOR-001
User tap cùng vùng nhiều lần.

Expected:
- Không tạo lỗi state.

## EDGE-EDITOR-002
User zoom tối đa rồi pan liên tục.

Expected:
- Canvas không biến mất khỏi vùng sử dụng hoàn toàn.

## EDGE-EDITOR-003
User Undo tới state đầu tiên.

Expected:
- Undo disabled hoặc không làm state sai.

## EDGE-EDITOR-004
User Redo sau action mới.

Expected:
- Redo stack xử lý đúng.

## EDGE-EDITOR-005
App background ngay sau một fill action.

Expected:
- Progress không mất.

## EDGE-WORK-001
My Works có rất nhiều artwork.

Expected:
- List/grid vẫn usable.

## EDGE-MON-001
Purchase thành công nhưng UI callback chậm.

Expected:
- Không double purchase prompt.
- Entitlement sync khi xác nhận.

## EDGE-CONTENT-001
Category mapping chứa artwork bị thiếu asset.

Expected:
- Item lỗi không làm crash cả category.

---

# 19. Traceability Matrix — Core Requirements

**Status column added 2026-08-14.**

| Requirement | Module | Feature | Screen | Flow | Status |
|---|---|---|---|---|---|
| REQ-ENTRY-001 | MOD-001 | FE-ENTRY-001 | SCR-ENTRY-001 | FLOW-ENTRY-001 | Active |
| REQ-HOME-003 | MOD-002 | FE-HOME-005 | SCR-HOME-001 / SCR-CATEGORY-001 | FLOW-DISCOVER-001 | Legacy — superseded by REQ-HOME-008 |
| REQ-HOME-008 | MOD-002 | FE-LIB-004 | SCR-HOME-001 / SCR-LIBRARY-001 | FLOW-LIBRARY-001 | Active — NEW |
| REQ-HOME-009 | MOD-002 | FE-HOME-010 | SCR-HOME-001 / SCR-EDITOR-001 | FLOW-COLOR-001 / FLOW-RESUME-001 | Active — NEW |
| REQ-HOME-010 | MOD-002 | FE-HOME-011 | SCR-HOME-001 / SCR-LIBRARY-001 / SCR-PROFILE-001 | — | Active — NEW |
| REQ-CAT-004 | MOD-003 | FE-CAT-004 | SCR-CATEGORY-001 / SCR-PREVIEW-001 | FLOW-DISCOVER-001 | Legacy — not routed |
| REQ-PREVIEW-002 | MOD-004 | FE-PREVIEW-002 | SCR-PREVIEW-001 / SCR-EDITOR-001 | FLOW-COLOR-001 | Legacy — not routed |
| REQ-EDITOR-003 | MOD-005 | FE-EDITOR-003 | SCR-EDITOR-001 | FLOW-COLOR-001 | Active |
| REQ-EDITOR-006 | MOD-005 | FE-EDITOR-006 | SCR-EDITOR-001 | FLOW-COLOR-001 | Active |
| REQ-EDITOR-011 | MOD-005 | FE-EDITOR-011 | SCR-EDITOR-001 | FLOW-RESUME-001 | Active |
| REQ-EDITOR-012 | MOD-005 | FE-EDITOR-012 | SCR-EDITOR-001 | FLOW-RESUME-001 | Active |
| REQ-EDITOR-017 | MOD-005 | FE-EDITOR-022 | SCR-COMPLETE-001 / SCR-EDITOR-001 | FLOW-COMPLETE-001 | Active — NEW (Feature ID corrected 2026-08-14) |
| REQ-WORK-002 | MOD-006 | FE-WORK-002 | SCR-WORKS-001 | FLOW-WORKS-001 | Legacy — superseded by REQ-PROFILE-003/004 |
| REQ-MON-002 | MOD-007 | FE-MON-002 | SCR-PAYWALL-001 | FLOW-PREMIUM-001 | Active |
| REQ-MON-007 | MOD-007 | FE-MON-007 | SCR-PAYWALL-001 / PREVIEW | FLOW-REWARD-001 | Active |
| REQ-SET-001 | MOD-008 | FE-SET-001 | SCR-SETTINGS-001 | FLOW-SETTINGS-001 | Active |
| REQ-LIB-001 | MOD-009 | FE-LIB-001 | SCR-LIBRARY-001 | FLOW-LIBRARY-001 | Active — NEW |
| REQ-LIB-003 | MOD-009 | FE-LIB-003 | SCR-LIBRARY-001 / SCR-EDITOR-001 | FLOW-LIBRARY-001 | Active — NEW |
| REQ-PROFILE-001 | MOD-010 | FE-PROFILE-001 | SCR-PROFILE-001 | FLOW-PROFILE-001 | Active — NEW |
| REQ-PROFILE-005 | MOD-010 | FE-PROFILE-005 | SCR-PROFILE-001 / SCR-EDITOR-001 | FLOW-PROFILE-001 | Active — NEW |
| REQ-PROFILE-006 | MOD-010 | FE-PROFILE-006 | SCR-PROFILE-001 / SCR-SETTINGS-001 | — | Active — NEW |

---

# 20. Requirement Coverage Summary

## App Entry
Covered:
- Launch
- Splash
- First-time route
- Home route

## Discovery
Covered:
- Home (category sections)
- Artwork thumbnails
- Direct-to-Coloring resolution (resume-or-create)
- See all → Library with filter
- Partial/error state

Legacy (preserved, not part of approved coverage):
- Category screen navigation
- Featured/Daily/Continue blocks

## Library *(new)*
Covered:
- Category filter (All/Manga/Animal/Nature/Food/...)
- Filtered artwork grid
- Direct-to-Coloring resolution
- Empty/error state

## Profile *(new)*
Covered:
- Empty state → Explore Library
- All/Completed/In Progress segmentation
- Personal artwork grid
- Direct-to-Coloring resolution (resume)
- Settings icon entry
- Artwork state sync rule (BR-PROFILE-001)

## Drawing Selection *(legacy — Category/Preview screens)*
Covered:
- Drawing grid
- Drawing states
- Preview
- Locked
- Resume

## Editor
Covered:
- Canvas
- Color
- Fill
- Brush
- Eraser
- Undo/Redo
- Zoom/Pan
- Autosave
- Restore
- Reset
- Completion

## Progress
Covered:
- Local save
- Resume
- Completed state (via Profile, MOD-010)
- Export/share
- Artwork state sync (BR-PROFILE-001)

Legacy (preserved, not routed):
- My Works screen (SCR-WORKS-001)

## Monetization
Covered conditionally:
- Premium state
- Paywall
- Purchase
- Restore
- Rewarded
- No Ads rule

## Settings
Covered:
- Settings
- Privacy
- Terms
- Version
- Restore Purchase

---

# 21. Open Requirement Decisions

Các điểm sau vẫn cần xác nhận để chuyển một số requirement từ conditional → final.

## RD-001 — Platform
Android only / iOS / both?

## RD-002 — Audience Classification
General Audience hay Child-Directed?

## RD-003 — Onboarding
Có nằm trong MVP không?

## RD-004 — Monetization
Ads + Subscription có nằm trong MVP launch không?

## RD-005 — Rewarded Unlock
Có dùng trong MVP không?

## RD-006 — Daily Drawing
MVP hay Version 1.1?

## RD-007 — Share
MVP hay Version 1.1?

## RD-008 — Brush
Hybrid Fill + Brush hay Fill-focused?

## RD-009 — Offline Scope
Toàn bộ bundled content hay chỉ local progress?

## RD-010 — Completion — **RESOLVED 2026-08-14**
Completion là dedicated screen hay modal/result state?

**Resolution:** Dedicated screen (`SCR-COMPLETE-001`) retained, with revised content: Share, Save/Download, Back to Home, Recommended for you.

---

# 22. Definition of Requirement Complete

Step 5 được xem là hoàn thành khi:

- Mỗi MUST feature có ít nhất một functional requirement.
- Core business rules đã được định nghĩa.
- Critical NFR đã được ghi nhận.
- Core flows có Acceptance Criteria.
- Edge cases quan trọng đã được liệt kê.
- Error behavior đã được định nghĩa.
- Requirement có traceability tới Feature / Screen / Flow.
- Open decisions được tách riêng, không bị giả định thành final.

---

# AI EXECUTION INSTRUCTIONS — STEP 5 HANDOFF

## Step Identity

**Step 5 = Requirement Catalog & Acceptance Criteria**

### Required Input
- `product-brief.md`
- `competitor-analysis.md`
- `mvp-scope.md`
- `information-architecture-user-flow.md`
- Any latest confirmed boss/user decisions.

### AI Role
Act as:
- Senior Business Analyst
- Product Requirements Owner

### AI Responsibilities
1. Read all approved previous artifacts.
2. Preserve confirmed Product/MVP/IA decisions.
3. Generate stable Requirement IDs.
4. Cover:
   - Functional Requirements
   - Business Rules
   - Non-functional Requirements
   - Acceptance Criteria
   - Preconditions
   - Postconditions
   - Error behavior
   - Edge cases
5. Maintain traceability:
   `Module → Feature → Screen → Flow → Requirement`
6. Do not invent detailed UI layout at this stage.
7. Keep unresolved product decisions explicitly conditional.
8. Do not generate full test cases yet.

### Required Output
Create/update:

`requirements.md`

---

## Next Step Handoff

**Next Step = Step 6 — UI Prototype / Design Specification**

In a new chat, the user may say:

> Follow `project-workflow.md`. Read all uploaded approved artifacts and continue Step 6.

### Required Input for Step 6
- `product-brief.md`
- `competitor-analysis.md`
- `mvp-scope.md`
- `information-architecture-user-flow.md`
- `requirements.md`

### AI Role for Step 6
Act as:
- Senior Product Designer
- Senior UX Designer
- Design Systems-minded UI Architect

### Step 6 Responsibilities
1. Read all previous approved artifacts.
2. Preserve Requirement IDs, Screen IDs, Flow IDs, Feature IDs.
3. Convert requirements into UI structure and interaction states.
4. Define per screen:
   - Screen purpose
   - Layout hierarchy
   - Components
   - Component IDs
   - CTA hierarchy
   - Navigation actions
   - Empty/loading/error states
   - Premium/locked states
   - Accessibility notes
   - Responsive behavior
5. Maintain traceability:
   `Requirement → Screen → Component`
6. If HTML prototype is generated, include attributes such as:
   - `data-screen-id`
   - `data-component-id`
   - `data-requirement`
   - `data-testid`
7. Do not change confirmed requirements silently.
8. Flag any requirement/design conflict.

### Required Output for Step 6
At minimum:
- `ui-spec.md`

Optional/Recommended:
- `prototype/` HTML/CSS/JS folder
