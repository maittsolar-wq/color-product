# Design System — Coloring App

**Document ID:** DS-COLOR-001  
**Version:** 1.0  
**Status:** Draft  

---

# 1. Visual Language

Keywords:

**Clean / Soft / Modern / Friendly / Creative**

The UI should feel light and calm, with the artwork providing most visual interest.

---

# 2. Color Tokens

Prototype tokens:

```css
--bg-app: #F3F3F3;
--surface: #FFFFFF;
--surface-soft: #F7F7F8;
--text-primary: #151515;
--text-secondary: #767676;
--line: #E8E8EA;

--accent: #7C4DFF;
--accent-soft: #EEE8FF;

--pink: #FF6D80;
--blue: #4A82FF;
--purple: #C34AD8;
--black: #0D0D0D;
--green: #168B2D;
--teal: #2C8E92;
--cream: #F4E6BE;
--ice: #E7EDF2;
```

Final brand palette can change without changing IA/requirements.

---

# 3. Typography

System font stack:
- Inter / SF Pro / Segoe UI fallback.

Hierarchy:
- Screen title: 24–28px.
- Section title: 18–20px.
- Body: 14–16px.
- Tool label: 10–12px.
- Caption: 11–12px.

---

# 4. Radius

- Large app card: 22–28px.
- Standard card: 16–20px.
- Button: 12–16px.
- Pill: 999px.
- Floating tool rail: 18–22px.

---

# 5. Spacing

Base spacing system:
- 4
- 8
- 12
- 16
- 20
- 24
- 32

---

# 6. Shadows

Use lightly.

Floating tools:
- subtle shadow only.

Do not use strong/glossy effects.

---

# 7. Icon Language

Icons should be:
- monochrome by default;
- thin/medium stroke;
- simple;
- readable at small size.

Selected tool can use Accent.

---

# 8. Editor-Specific Tokens

```css
--editor-workspace: #F2F2F2;
--editor-artboard: #FFFFFF;
--editor-toolbar: #FFFFFF;
--editor-control-border: #E9E9EA;
--editor-selected: #7C4DFF;
```

---

# 9. Component States

Every interactive component should support:
- default;
- hover (HTML prototype);
- pressed;
- selected;
- disabled;
- error if relevant.

---

# 10. Artwork Presentation

- Artboard always clean white.
- Line-art stays black.
- No decorative frame around artwork.
- Thumbnail should remain readable on small screens.
