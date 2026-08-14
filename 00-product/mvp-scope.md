# MVP Scope & Feature Prioritization — Coloring App

**Document ID:** MVP-COLOR-001  
**Version:** 0.1  
**Status:** Draft  
**Related Documents:**  
- `00-product/product-brief.md`
- `00-product/competitor-analysis.md`

---

## 1. Purpose

Tài liệu này xác định phạm vi MVP của ứng dụng tô tranh, bao gồm:

- Các module cần triển khai.
- Feature nào bắt buộc cho MVP.
- Feature nào nên có nếu đủ thời gian.
- Feature nào để phiên bản sau.
- Feature nào chưa triển khai.
- Các Product Decision còn cần chốt.
- Điều kiện để MVP được xem là hoàn thành.

Mục tiêu là tránh mở rộng scope quá sớm và đảm bảo team tập trung vào trải nghiệm cốt lõi:

**Chọn tranh → Tô màu → Lưu tiến trình → Hoàn thành → Tiếp tục khám phá tranh khác.**

---

## 2. MVP Goal

MVP phải chứng minh được rằng người dùng có thể:

1. Mở app và hiểu ngay đây là ứng dụng tô màu.
2. Tìm được một tranh phù hợp.
3. Mở tranh và bắt đầu tô nhanh.
4. Chọn màu và tô dễ dàng bằng touch.
5. Undo/Redo khi cần.
6. Zoom/Pan để thao tác chính xác.
7. Thoát app mà không mất tiến trình.
8. Mở lại và tiếp tục tô.
9. Hoàn thành và lưu tác phẩm.
10. Có đủ nội dung để muốn quay lại sử dụng.

---

## 3. MVP Product Strategy

MVP không cạnh tranh bằng số lượng feature.

MVP ưu tiên:

### P1 — Coloring Quality
Tô phải mượt, chính xác và dễ hiểu.

### P2 — Content Quality
Artwork phải rõ, dễ tô và phù hợp thumbnail mobile.

### P3 — Low Friction
Người dùng phải bắt đầu tô với ít bước nhất có thể.

### P4 — Progress Reliability
Không được làm mất tiến trình tô.

### P5 — Simple Discovery
Người dùng phải dễ tìm được tranh theo sở thích.

### P6 — Controlled Monetization
Monetization không được phá trải nghiệm tô màu cốt lõi.

---

# 4. MVP Modules

MVP được chia thành 8 module chính:

| Module ID | Module | Mục tiêu |
|---|---|---|
| MOD-001 | App Entry | Launch app và đưa user vào trải nghiệm |
| MOD-002 | Home & Discovery | Khám phá category và artwork |
| MOD-003 | Category & Drawing List | Xem danh sách tranh |
| MOD-004 | Drawing Preview | Xem tranh trước khi bắt đầu |
| MOD-005 | Coloring Editor | Trải nghiệm tô màu cốt lõi |
| MOD-006 | Progress & My Works | Lưu và tiếp tục tác phẩm |
| MOD-007 | Monetization | Ads / Premium nếu được chốt |
| MOD-008 | Settings & Basic App Controls | Cấu hình cơ bản |

---

# 5. Prioritization Framework

Sử dụng MoSCoW:

### MUST
Không có feature này thì MVP không đạt core value.

### SHOULD
Rất nên có nhưng có thể release MVP nếu chưa hoàn thiện.

### COULD
Có giá trị nhưng không ảnh hưởng khả năng chứng minh core product.

### WON'T — MVP
Không triển khai trong MVP.

---

# 6. Module 1 — App Entry

## MUST

### FE-ENTRY-001 — App Launch
Ứng dụng có thể khởi động ổn định.

### FE-ENTRY-002 — Splash
Hiển thị splash ngắn trong quá trình initialize app.

### FE-ENTRY-003 — First-Time Entry
Xử lý lần đầu mở app.

### FE-ENTRY-004 — Direct Home Access
Sau bước khởi tạo, user được đưa tới Home.

## SHOULD

### FE-ENTRY-005 — Lightweight Onboarding
Onboarding tối đa 2–3 màn nếu thực sự cần giải thích value.

**Recommendation:** Không bắt buộc onboarding dài.

## WON'T — MVP

- Account registration bắt buộc.
- Social login.
- Profile setup.
- Interest personalization onboarding phức tạp.

---

# 7. Module 2 — Home & Discovery

## MUST

### FE-HOME-001 — Home Screen
Hiển thị các nội dung chính của app.

### FE-HOME-002 — Category List
Cho phép user duyệt category.

### FE-HOME-003 — Featured/New Content
Có khu vực hiển thị một số tranh nổi bật hoặc mới.

### FE-HOME-004 — Drawing Thumbnail
Thumbnail phải rõ và đủ lớn để nhận diện nội dung.

### FE-HOME-005 — Open Category
Tap category để mở danh sách tranh tương ứng.

### FE-HOME-006 — Open Drawing
Cho phép user mở tranh trực tiếp nếu layout hỗ trợ.

## SHOULD

### FE-HOME-007 — Continue Coloring
Hiển thị tác phẩm đang tô gần nhất.

### FE-HOME-008 — New / Recently Added
Khu vực tranh mới.

### FE-HOME-009 — Daily Drawing
Một tranh nổi bật mỗi ngày.

## COULD

- Seasonal section.
- Trending.
- Recommended for you.
- Recently viewed.

## WON'T — MVP

- AI recommendation engine.
- Social feed.
- User-generated feed.

---

# 8. Module 3 — Category & Drawing List

## MUST

### FE-CAT-001 — Category Screen
Hiển thị tên category và danh sách artwork.

### FE-CAT-002 — Drawing Grid
Tranh hiển thị dạng grid tối ưu cho mobile.

### FE-CAT-003 — Drawing State
Có thể phân biệt:

- Chưa tô.
- Đang tô.
- Đã hoàn thành.
- Locked/Premium nếu monetization được dùng.

### FE-CAT-004 — Drawing Selection
Tap artwork để mở Drawing Preview hoặc Editor.

### FE-CAT-005 — Content Loading
Danh sách tranh phải load ổn định.

## SHOULD

### FE-CAT-006 — All Category
Hiển thị tất cả artwork.

### FE-CAT-007 — Saved/My Works Shortcut
Truy cập nhanh tác phẩm đã tô.

## COULD

- Search.
- Filter.
- Sort.
- Favorites.

## WON'T — MVP

- Complex discovery algorithm.
- Community ranking.
- Creator profiles.

---

# 9. Module 4 — Drawing Preview

## MUST

### FE-PREVIEW-001 — Preview Artwork
Hiển thị artwork trước khi user bắt đầu tô.

### FE-PREVIEW-002 — Start Coloring
CTA rõ ràng để mở Editor.

### FE-PREVIEW-003 — Resume Coloring
Nếu tranh đã có progress, CTA phải tiếp tục trạng thái hiện tại.

### FE-PREVIEW-004 — Locked State
Nếu artwork bị khóa, hiển thị trạng thái rõ ràng.

## SHOULD

### FE-PREVIEW-005 — Completed Preview
Cho phép xem tác phẩm đã hoàn thành.

## COULD

- Suggested palettes.
- Similar drawings.
- Share preview.

---

# 10. Module 5 — Coloring Editor

Đây là module có priority cao nhất trong MVP.

## MUST

### FE-EDITOR-001 — Canvas
Hiển thị tranh tô với chất lượng rõ ràng.

### FE-EDITOR-002 — Color Selection
User có thể chọn màu từ palette.

### FE-EDITOR-003 — Tap-to-Fill
User tap vào vùng khép kín để tô vùng đó.

### FE-EDITOR-004 — Basic Brush
User có thể tô bằng brush nếu hybrid coloring được giữ trong MVP.

### FE-EDITOR-005 — Eraser
Cho phép xóa thao tác brush/free coloring.

### FE-EDITOR-006 — Undo
Hoàn tác thao tác gần nhất.

### FE-EDITOR-007 — Redo
Khôi phục thao tác vừa Undo.

### FE-EDITOR-008 — Zoom
Pinch để phóng to/thu nhỏ.

### FE-EDITOR-009 — Pan
Di chuyển canvas khi zoom.

### FE-EDITOR-010 — Prevent Accidental Loss
Thoát Editor không được làm mất progress.

### FE-EDITOR-011 — Autosave
Progress được lưu tự động.

### FE-EDITOR-012 — Restore
Mở lại tranh phải restore đúng progress.

### FE-EDITOR-013 — Reset Drawing
Cho phép reset tranh sau confirmation.

### FE-EDITOR-014 — Completion
User có thể xác nhận hoàn thành tranh.

## SHOULD

### FE-EDITOR-015 — Multiple Palettes
Có nhiều nhóm màu cơ bản.

### FE-EDITOR-016 — Brush Size
Điều chỉnh size brush.

### FE-EDITOR-017 — Visual Tool Preview
Tool có icon/preview dễ hiểu.

### FE-EDITOR-018 — Hide UI / Focus Mode
Có thể giảm toolbar để xem artwork rõ hơn.

## COULD

### FE-EDITOR-019 — Special Brush Effects
Ví dụ:

- Watercolor.
- Oil.
- Glitter.
- Fur.
- Laser.
- Plasma.

MVP chỉ nên thêm một số ít nếu editor core đã ổn định.

### FE-EDITOR-020 — Gradient
Gradient colors.

### FE-EDITOR-021 — Texture
Texture fill.

## WON'T — MVP

- Professional layers.
- Vector editing.
- Advanced blending.
- AI recoloring.
- Multiplayer canvas.
- Photoshop-style selection tools.

---

# 11. Module 6 — Progress & My Works

## MUST

### FE-WORK-001 — Save Progress
Lưu trạng thái tranh đang tô.

### FE-WORK-002 — My Works
Có khu vực hiển thị artwork user đã bắt đầu hoặc hoàn thành.

### FE-WORK-003 — Resume
Cho phép tiếp tục tô từ My Works.

### FE-WORK-004 — Completed State
Phân biệt tranh đã hoàn thành.

### FE-WORK-005 — Local Persistence
Progress vẫn tồn tại sau khi app đóng/mở lại.

## SHOULD

### FE-WORK-006 — Save Final Image
Xuất tác phẩm thành ảnh.

### FE-WORK-007 — Save to Photos/Gallery
Cho phép lưu về thiết bị sau khi user cấp quyền.

### FE-WORK-008 — Share
Share artwork qua system share sheet.

## COULD

- Favorite artwork.
- Duplicate coloring version.
- Multiple versions của cùng một tranh.

## WON'T — MVP

- Cloud synchronization.
- Multi-device sync.
- Public profile.
- Public gallery.

---

# 12. Module 7 — Monetization

Module này phụ thuộc Product Decision.

## MUST — nếu Monetization nằm trong MVP

### FE-MON-001 — Free/Premium Content State
Hệ thống phân biệt content miễn phí và Premium.

### FE-MON-002 — Paywall
Hiển thị rõ quyền lợi Premium.

### FE-MON-003 — Purchase
User có thể mua subscription/IAP.

### FE-MON-004 — Restore Purchase
Khôi phục giao dịch hợp lệ.

### FE-MON-005 — Premium State
App nhận biết chính xác user Premium.

### FE-MON-006 — Ad-Free Premium
Premium không hiển thị quảng cáo theo business rule.

## SHOULD

### FE-MON-007 — Rewarded Ad Unlock
Cho phép unlock một số artwork bằng rewarded ad.

### FE-MON-008 — Interstitial
Nếu dùng interstitial, phải xuất hiện tại điểm ngắt tự nhiên.

## MUST NOT

Không hiển thị interstitial:

- Trong lúc user đang tô.
- Khi đang thực hiện thao tác quan trọng.
- Liên tục sau mỗi action.

## COULD

- Trial.
- Limited premium preview.
- Premium brush samples.

---

# 13. Module 8 — Settings

## MUST

### FE-SET-001 — Settings Screen
Màn hình cấu hình cơ bản.

### FE-SET-002 — Restore Purchase
Nếu subscription được triển khai.

### FE-SET-003 — Privacy Policy
Truy cập Privacy Policy.

### FE-SET-004 — Terms
Truy cập Terms of Use nếu cần.

### FE-SET-005 — App Version
Hiển thị version/build.

## SHOULD

### FE-SET-006 — Sound
Bật/tắt sound effects nếu app có âm thanh.

### FE-SET-007 — Haptic
Bật/tắt haptic nếu được sử dụng.

### FE-SET-008 — Rate App
Điểm vào store review.

## COULD

- Language.
- Theme.
- App icon customization.

---

# 14. Content Scope for MVP

Content là một phần quan trọng của MVP.

## Recommended Initial Categories

### MUST

1. Cute
2. Animals
3. Anime
4. Cozy
5. Fantasy
6. Food
7. People
8. Places
9. Nature
10. Mandala

## Recommended Artwork Volume

### Minimum viable content

**15–20 tranh/category**

10 categories:

```text
10 × 15 = 150 artworks minimum
```

### Preferred MVP

**20–25 tranh/category**

```text
10 × 20 = 200 artworks
10 × 25 = 250 artworks
```

Recommendation:

**Target khoảng 200–250 tranh cho MVP nếu content pipeline đáp ứng được.**

---

# 15. Artwork Quality Requirements

Tất cả artwork MVP phải tuân thủ baseline:

### ART-001
Black and white line art.

### ART-002
1:1.

### ART-003
Không viền khung.

### ART-004
Nét ngoài dày hơn nét trong.

### ART-005
Nét trong vừa phải.

### ART-006
Vùng tô rõ và khép kín.

### ART-007
Không có text.

### ART-008
Không watermark/logo.

### ART-009
Thumbnail dễ nhận diện.

### ART-010
Không quá nhiều chi tiết cực nhỏ.

### ART-011
Tối ưu thao tác bằng touch.

### ART-012
Style trong cùng category phải đủ nhất quán.

---

# 16. MVP Navigation Architecture

Recommended:

```text
App
│
├── Home
│   ├── Featured / New
│   ├── Categories
│   └── Continue Coloring
│
├── Category
│   └── Drawing Grid
│
├── Drawing Preview
│
├── Coloring Editor
│
├── My Works
│
├── Paywall
│
└── Settings
```

Bottom navigation nếu sử dụng nên giữ tối giản.

Ví dụ:

```text
Home
My Works
Settings
```

Category là flow con của Home, không nhất thiết cần một tab riêng.

---

# 17. Critical MVP User Journey

## Journey J-001 — First Coloring

```text
Launch
↓
Home
↓
Select Category
↓
Select Drawing
↓
Preview
↓
Start
↓
Select Color
↓
Tap Region
↓
Color Applied
```

### Success Criteria

User mới có thể hoàn thành journey mà:

- Không cần đọc tutorial dài.
- Không cần login.
- Không gặp paywall trước khi hiểu core value, trừ khi business yêu cầu khác.
- Không cần biết thuật ngữ nghệ thuật.

---

## Journey J-002 — Continue Coloring

```text
Open Drawing
↓
Color
↓
Exit App
↓
Reopen App
↓
My Works / Continue
↓
Resume
```

### Success Criteria

Progress phải giống trạng thái trước khi thoát.

---

## Journey J-003 — Complete Drawing

```text
Editor
↓
Complete
↓
Result
↓
Save
↓
My Works
```

---

# 18. MVP Must-Have Summary

MVP không được release nếu thiếu:

1. Home.
2. Category browsing.
3. Drawing grid.
4. Drawing preview/start.
5. Coloring canvas.
6. Color palette.
7. Tap-to-fill.
8. Basic brush nếu hybrid.
9. Undo.
10. Redo.
11. Zoom.
12. Pan.
13. Autosave.
14. Restore.
15. My Works.
16. Completed state.
17. Artwork content.
18. Stable app launch/navigation.
19. Privacy/legal baseline.
20. Monetization core nếu business yêu cầu release có doanh thu.

---

# 19. Should-Have Summary

Nên có nếu timeline cho phép:

- Daily Drawing.
- Continue Coloring trên Home.
- Multiple palettes.
- Brush size.
- Save final image.
- Share.
- Rewarded unlock.
- Lightweight onboarding.
- Haptic/sound settings.

---

# 20. Could-Have Summary

Không block MVP:

- Special brushes.
- Gradients.
- Texture.
- Events.
- Seasonal content.
- Favorites.
- Search.
- More discovery sections.

---

# 21. Won't Have in MVP

Không triển khai:

- AI image generation.
- Photo-to-coloring.
- Community.
- Follow.
- Like/comment.
- Chat.
- Public profiles.
- User-generated public gallery.
- Marketplace.
- Multiplayer.
- Cloud sync.
- Professional drawing layers.
- Advanced image editor.
- Desktop version.

---

# 22. Version 1.1 Candidates

Sau MVP, ưu tiên đánh giá:

### V11-001
Daily Drawing.

### V11-002
Additional brush effects.

### V11-003
Seasonal/Events content.

### V11-004
More palettes.

### V11-005
Favorites.

### V11-006
Search/filter.

### V11-007
Content Packs.

### V11-008
More rewarded unlock models.

---

# 23. Future Roadmap Candidates

Chỉ xem xét khi core metrics tốt:

### FUT-001
AI-generated coloring pages.

### FUT-002
Photo-to-line-art.

### FUT-003
Community gallery.

### FUT-004
User publishing.

### FUT-005
Likes/comments.

### FUT-006
Cross-device sync.

### FUT-007
Personalized recommendation.

---

# 24. MVP Product Decisions Needed

Trước khi chuyển sang Requirement chi tiết, cần chốt:

### PD-MVP-001 — Platform
Android only, iOS only hay cả hai?

### PD-MVP-002 — Target Market
US, Global hay thị trường khác?

### PD-MVP-003 — Audience Classification
General Audience hay Child-Directed?

### PD-MVP-004 — Account
Không login hay có account?

**Recommendation:** Không login trong MVP nếu không có cloud/community.

### PD-MVP-005 — Monetization
Ads + Subscription có triển khai ngay trong MVP không?

### PD-MVP-006 — Rewarded Ads
Có unlock tranh bằng rewarded ads không?

### PD-MVP-007 — Daily Drawing
MVP hay Version 1.1?

### PD-MVP-008 — Coloring Interaction
Tap-to-fill only hay hybrid Fill + Brush?

**Recommendation:** Hybrid, nhưng Tap-to-Fill là interaction chính.

### PD-MVP-009 — Initial Content Volume
150, 200 hay 250+ artwork?

### PD-MVP-010 — Offline
Artwork nào có thể sử dụng offline?

### PD-MVP-011 — Share
Share result có nằm trong MVP không?

### PD-MVP-012 — Premium Scope
Premium unlock:

- Artwork?
- Categories?
- Brushes?
- No Ads?
- Tất cả?

---

# 25. Recommended Decisions for Pilot MVP

Nếu mục tiêu là release nhanh và test thị trường:

| Decision | Recommendation |
|---|---|
| Platform | 1 platform trước |
| Account | Không login |
| Core coloring | Fill + basic Brush |
| Categories | 10 |
| Artwork | ~200 |
| Daily | SHOULD |
| Share | SHOULD |
| Ads | Có nhưng hạn chế |
| Rewarded | Có thể dùng |
| Subscription | Có nếu business cần |
| AI | Không |
| Community | Không |
| Offline | Core artwork/progress hỗ trợ local |
| Premium tools | Hạn chế ở MVP |

---

# 26. Scope Guardrails

Mọi request mới trong quá trình development phải trả lời ba câu:

### Q1
Feature này có trực tiếp cải thiện:

- Discovery?
- Coloring?
- Progress?
- Completion?
- Monetization bắt buộc?

### Q2
Nếu không có feature này, MVP có còn chứng minh core value không?

### Q3
Feature này có làm delay core editor/content không?

Nếu:

```text
Không trực tiếp hỗ trợ core
+
Không block MVP
+
Có nguy cơ delay
```

→ chuyển sang Version 1.1/Future.

---

# 27. Definition of MVP Complete

MVP được xem là **Feature Complete** khi:

### Product

- Core flows đã implement.
- Không còn Must feature chưa làm.

### Content

- Đạt số artwork tối thiểu đã chốt.
- Artwork đạt QA baseline.
- Category mapping chính xác.

### Functional QA

- Smoke test pass.
- Critical flow pass.
- Autosave/restore pass.
- Undo/Redo pass.
- Zoom/Pan pass.

### Stability

- Không Critical bug.
- Không High bug ảnh hưởng core coloring.
- Không crash trong primary journey.

### Monetization

Nếu nằm trong MVP:

- Purchase pass.
- Restore purchase pass.
- Premium state pass.
- Ads rules pass.

### UX

- New user hiểu cách bắt đầu tô.
- Không cần tutorial dài.
- Core interaction dễ dùng bằng touch.

### Release

- Privacy/Terms sẵn sàng.
- Analytics events quan trọng được tracking nếu có.
- Store assets và listing sẵn sàng.

---

# 28. Output of Step 3

Sau khi tài liệu này được review và Product Decisions được chốt:

```text
product-brief.md
+
competitor-analysis.md
+
mvp-scope.md
```

sẽ trở thành input cho **Step 4 — Information Architecture & User Flow**.

Step 4 sẽ xác định:

- Danh sách màn hình chính thức.
- Screen ID.
- Navigation map.
- Entry/exit point.
- Primary flow.
- Alternative flow.
- Premium flow.
- Error/empty states ở mức flow.
- Mapping Module → Screen.

Sau Step 4 mới chuyển sang Requirement Catalog chi tiết.


---

# AI EXECUTION INSTRUCTIONS — STEP 3 HANDOFF

## Step Identity

**Step 3 = MVP Scope & Feature Prioritization**

### Required Input
- `product-brief.md`
- `competitor-analysis.md`
- Any new confirmed decisions from boss/user.

### AI Role
Act as:
- Senior Product Manager
- Senior Business Analyst
- MVP / Scope Owner

### AI Responsibilities
1. Read all previous approved artifacts before making scope decisions.
2. Preserve confirmed product decisions.
3. Convert product direction into clearly defined modules.
4. Give every feature a stable Feature ID.
5. Prioritize each feature using MoSCoW:
   - MUST
   - SHOULD
   - COULD
   - WON'T — MVP
6. Keep MVP focused on proving the product's core value.
7. Detect and prevent scope creep.
8. Separate:
   - MVP
   - Version 1.1 candidates
   - Future roadmap
9. Identify Product Decisions that still need confirmation.
10. Define Definition of MVP Complete.
11. Do not design detailed screen UI yet.
12. Do not generate detailed test cases yet.

### Required Output
Create/update `mvp-scope.md` containing:
- MVP Goal
- MVP Product Strategy
- Module Breakdown
- Feature IDs
- MoSCoW Prioritization
- Content Scope
- Core Interaction Scope
- Monetization Scope
- Critical User Journeys
- Must-Have Summary
- Should-Have Summary
- Could-Have Summary
- Won't-Have Summary
- Version 1.1 Candidates
- Future Roadmap Candidates
- Product Decisions Needed
- Scope Guardrails
- Definition of MVP Complete

## Next Step Handoff

**Next Step = Step 4 — Information Architecture & User Flow**

In a new chat, the user may say:

> Read `product-brief.md`, `competitor-analysis.md`, and `mvp-scope.md`, then continue Step 4.

The AI must:
1. Read all three artifacts first.
2. Preserve confirmed decisions and MVP scope.
3. Convert modules/features into the official screen inventory.
4. Assign stable Screen IDs.
5. Define navigation architecture.
6. Define primary, secondary, premium, resume, empty, error, and alternative flows.
7. Map Module → Feature → Screen.
8. Avoid detailed visual design at this stage.
9. Produce `information-architecture-user-flow.md`.
