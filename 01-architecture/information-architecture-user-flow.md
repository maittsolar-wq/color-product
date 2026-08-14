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

Recommended high-level structure:

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

| Screen ID | Screen Name | Module | Priority |
|---|---|---|---|
| SCR-ENTRY-001 | Splash | MOD-001 App Entry | MUST |
| SCR-ENTRY-002 | Onboarding | MOD-001 App Entry | SHOULD |
| SCR-HOME-001 | Home | MOD-002 Home & Discovery | MUST |
| SCR-CATEGORY-001 | Category / Drawing List | MOD-003 Category & Drawing List | MUST |
| SCR-PREVIEW-001 | Drawing Preview | MOD-004 Drawing Preview | MUST |
| SCR-EDITOR-001 | Coloring Editor | MOD-005 Coloring Editor | MUST |
| SCR-COMPLETE-001 | Completion / Result | MOD-005 Coloring Editor / MOD-006 My Works | SHOULD |
| SCR-WORKS-001 | My Works | MOD-006 Progress & My Works | MUST |
| SCR-PAYWALL-001 | Paywall | MOD-007 Monetization | MUST if monetization in MVP |
| SCR-SETTINGS-001 | Settings | MOD-008 Settings | MUST |

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

**Purpose**  
Điểm vào chính để user khám phá nội dung.

**Entry Points**
- Splash
- Onboarding
- Back from child screens
- Bottom navigation
- App re-open

**Exit Points**
- `SCR-CATEGORY-001`
- `SCR-PREVIEW-001`
- `SCR-WORKS-001`
- `SCR-SETTINGS-001`
- `SCR-PAYWALL-001` (nếu user tap CTA Premium)
- `SCR-EDITOR-001` (only if “Continue Coloring” direct resume is supported)

**Related Features**
- FE-HOME-001
- FE-HOME-002
- FE-HOME-003
- FE-HOME-004
- FE-HOME-005
- FE-HOME-006
- FE-HOME-007
- FE-HOME-008
- FE-HOME-009

**Home Content Blocks**
- Featured / New
- Category list
- Continue Coloring
- Daily Drawing (optional)
- My Works shortcut

**Notes**
- Đây là màn discovery quan trọng nhất.
- Artwork và category phải nổi bật.

---

### 5.4 SCR-CATEGORY-001 — Category / Drawing List

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

**Purpose**  
Thực hiện toàn bộ trải nghiệm tô màu cốt lõi.

**Entry Points**
- Drawing Preview
- Continue Coloring direct resume
- My Works resume

**Exit Points**
- Back → previous screen (with autosave)
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

**Purpose**  
Hiển thị trạng thái hoàn thành và các hành động sau khi hoàn tất tranh.

**Entry Points**
- Editor → Complete action

**Exit Points**
- `SCR-WORKS-001`
- `SCR-HOME-001`
- `SCR-PREVIEW-001`
- System share sheet
- Save-to-device flow

**Related Features**
- FE-EDITOR-014
- FE-WORK-006
- FE-WORK-007
- FE-WORK-008

**Primary Actions**
- Save
- Share
- View in My Works
- Back to Home
- Color another drawing

**Notes**
- Nếu chưa làm screen này trong MVP, có thể rút gọn thành result modal/state.
- Tuy nhiên screen riêng dễ tối ưu cho completion reward.

---

### 5.8 SCR-WORKS-001 — My Works

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

## 6. Navigation Architecture

### 6.1 Recommended Root Navigation

Recommended bottom navigation:

```text
Home | My Works | Settings
```

**Rationale**
- Home = discovery
- My Works = resume/retention
- Settings = low-frequency utility

**Not recommended for MVP**
- Quá nhiều tab như: Home / Categories / Daily / Community / AI / Profile
- Điều này làm tăng complexity quá sớm.

---

### 6.2 Navigation Types

| Navigation Type | Use Case |
|---|---|
| Launch Route | Splash / Onboarding / Home |
| Push Navigation | Home → Category → Preview → Editor |
| Modal / Sheet | Paywall, system dialogs, confirmation |
| Bottom Navigation | Home, My Works, Settings |
| System Flow | Share sheet, save permission |

---

### 6.3 Back Behavior Principles

### NAV-001
Back từ Category → Home.

### NAV-002
Back từ Preview → previous discovery screen.

### NAV-003
Back từ Editor:
- autosave;
- confirm reset only if required for destructive action;
- return to previous screen.

### NAV-004
Back từ Paywall → previous screen without losing context.

### NAV-005
Back từ Completion → Home / My Works / previous logical destination.

---

## 7. Flow Inventory

### Main Flow IDs

| Flow ID | Flow Name | Priority |
|---|---|---|
| FLOW-ENTRY-001 | Launch & Enter App | MUST |
| FLOW-COLOR-001 | First Coloring Journey | MUST |
| FLOW-DISCOVER-001 | Browse Category & Select Drawing | MUST |
| FLOW-RESUME-001 | Resume Coloring | MUST |
| FLOW-COMPLETE-001 | Complete & Save Artwork | MUST |
| FLOW-WORKS-001 | Access My Works | MUST |
| FLOW-PREMIUM-001 | Locked Drawing → Paywall | SHOULD/MUST if monetization in MVP |
| FLOW-REWARD-001 | Rewarded Unlock Flow | SHOULD if used |
| FLOW-SETTINGS-001 | Open Settings / Restore Purchase | MUST |
| FLOW-ERROR-001 | Asset / Content Load Error | MUST |
| FLOW-EMPTY-001 | Empty My Works | MUST |
| FLOW-OFFLINE-001 | Offline / Limited Connectivity Handling | SHOULD |

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

```text
SCR-HOME-001 Home
↓
SCR-CATEGORY-001 Category
↓
SCR-PREVIEW-001 Drawing Preview
↓
Tap Start
↓
SCR-EDITOR-001 Coloring Editor
↓
Select Color
↓
Tap Region
↓
Color Applied
```

**Success Criteria**
- User tô thành công vùng đầu tiên nhanh chóng.
- Không bị yêu cầu học nhiều.
- Không bị chặn bởi paywall sớm nếu tranh free.

---

### 8.4 FLOW-RESUME-001 — Resume Coloring

```text
SCR-HOME-001 Home
↓
Tap Continue Coloring
or
Open SCR-WORKS-001 My Works
↓
Select In-Progress Drawing
↓
SCR-PREVIEW-001 or direct SCR-EDITOR-001
↓
SCR-EDITOR-001 Coloring Editor
↓
Progress Restored
```

**Success Criteria**
- Trạng thái tô được restore chính xác.
- User không phải tìm kiếm quá sâu.

---

### 8.5 FLOW-COMPLETE-001 — Complete & Save Artwork

```text
SCR-EDITOR-001 Coloring Editor
↓
Tap Complete
↓
SCR-COMPLETE-001 Completion / Result
↓
Choose:
- Save
- Share
- View in My Works
- Back to Home
- Start another drawing
```

**Success Criteria**
- User nhận được cảm giác hoàn thành.
- Tác phẩm được lưu thành công nếu user chọn save.

---

### 8.6 FLOW-WORKS-001 — Access My Works

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

### SCR-WORKS-001
- Loading
- Empty
- In-progress list
- Completed list
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

| Module ID | Module | Screen IDs |
|---|---|---|
| MOD-001 | App Entry | SCR-ENTRY-001, SCR-ENTRY-002 |
| MOD-002 | Home & Discovery | SCR-HOME-001 |
| MOD-003 | Category & Drawing List | SCR-CATEGORY-001 |
| MOD-004 | Drawing Preview | SCR-PREVIEW-001 |
| MOD-005 | Coloring Editor | SCR-EDITOR-001, SCR-COMPLETE-001 |
| MOD-006 | Progress & My Works | SCR-WORKS-001, SCR-COMPLETE-001 |
| MOD-007 | Monetization | SCR-PAYWALL-001 |
| MOD-008 | Settings | SCR-SETTINGS-001 |

---

## 12. Feature → Screen Mapping

| Feature ID | Feature | Screen IDs |
|---|---|---|
| FE-HOME-001 | Home Screen | SCR-HOME-001 |
| FE-HOME-002 | Category List | SCR-HOME-001 |
| FE-HOME-007 | Continue Coloring | SCR-HOME-001, SCR-WORKS-001, SCR-EDITOR-001 |
| FE-CAT-001 | Category Screen | SCR-CATEGORY-001 |
| FE-CAT-002 | Drawing Grid | SCR-CATEGORY-001 |
| FE-PREVIEW-001 | Preview Artwork | SCR-PREVIEW-001 |
| FE-PREVIEW-002 | Start Coloring | SCR-PREVIEW-001, SCR-EDITOR-001 |
| FE-PREVIEW-003 | Resume Coloring | SCR-PREVIEW-001, SCR-EDITOR-001 |
| FE-EDITOR-002 | Color Selection | SCR-EDITOR-001 |
| FE-EDITOR-003 | Tap-to-Fill | SCR-EDITOR-001 |
| FE-EDITOR-004 | Basic Brush | SCR-EDITOR-001 |
| FE-EDITOR-006 | Undo | SCR-EDITOR-001 |
| FE-EDITOR-007 | Redo | SCR-EDITOR-001 |
| FE-EDITOR-008 | Zoom | SCR-EDITOR-001 |
| FE-EDITOR-009 | Pan | SCR-EDITOR-001 |
| FE-EDITOR-011 | Autosave | SCR-EDITOR-001 |
| FE-EDITOR-012 | Restore | SCR-EDITOR-001 |
| FE-EDITOR-014 | Completion | SCR-EDITOR-001, SCR-COMPLETE-001 |
| FE-WORK-002 | My Works | SCR-WORKS-001 |
| FE-WORK-006 | Save Final Image | SCR-COMPLETE-001 |
| FE-WORK-008 | Share | SCR-COMPLETE-001 |
| FE-MON-002 | Paywall | SCR-PAYWALL-001 |
| FE-MON-004 | Restore Purchase | SCR-PAYWALL-001, SCR-SETTINGS-001 |
| FE-SET-001 | Settings Screen | SCR-SETTINGS-001 |

---

## 13. Screen Depth & Complexity

Recommended screen depth:

```text
Level 0
- Splash / Home

Level 1
- Category
- My Works
- Settings

Level 2
- Preview
- Paywall

Level 3
- Editor
- Completion
```

**Principle**
- Không nên có discovery depth quá sâu.
- Từ Home đến Editor ideally là 2–3 bước.

---

## 14. Recommended Root Sitemap

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

### UXD-001
Giữ Drawing Preview như một màn riêng.

**Reason:**  
Giảm việc user vào thẳng editor khi chưa sẵn sàng, đồng thời tạo chỗ đặt trạng thái:
- Start
- Continue
- Locked
- Completed

### UXD-002
Giữ My Works như tab hoặc entry chính thức.

**Reason:**  
Resume flow là retention-critical.

### UXD-003
Không tạo tab Category riêng cho MVP.

**Reason:**  
Category là một phần của Home discovery, không cần tách quá sớm.

### UXD-004
Paywall phải là child flow, không phải root destination chính.

### UXD-005
Editor không nên bị gián đoạn bởi interstitial.

---

## 16. Open IA Decisions

### IA-DEC-001 — Onboarding
Có giữ onboarding ở MVP không?

**Recommendation:** Optional / lightweight only.

### IA-DEC-002 — Direct Resume
Continue Coloring từ Home mở:
- trực tiếp Editor
- hay qua Preview

**Recommendation:**  
Nếu có progress, có thể cho direct Editor để giảm friction.

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
