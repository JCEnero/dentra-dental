# DENTRA Flutter — Reference Mapping

This document maps every element of the existing React/TypeScript frontend
(`Mobile App UI Design/src/App.tsx`) to its equivalent in the Flutter project.

---

## Screens

| Existing Frontend Component | Flutter Screen | File |
|-----------------------------|---------------|------|
| `HomeScreen` (React component) | `HomeScreen` | `lib/features/home/screens/home_screen.dart` |
| `ScanScreen` (React component, FSM) | `ScanScreen` | `lib/features/scan/screens/scan_screen.dart` |
| `HistoryScreen` (React component) | `HistoryScreen` | `lib/features/history/screens/history_screen.dart` |
| `ClinicsScreen` (React component) | `ClinicsScreen` | `lib/features/clinics/screens/clinics_screen.dart` |
| `ProfileScreen` (React component) | `ProfileScreen` | `lib/features/profile/screens/profile_screen.dart` |

---

## Navigation

| Existing Frontend | Flutter Equivalent |
|-------------------|-------------------|
| `useState<number>(tab)` + `screens[tab]` in `App` | `IndexedStack` + `_AppShellState._tab` in `app.dart` |
| `BottomNav` component | `AppBottomNav` widget in `shared/widgets/app_bottom_nav.dart` |
| `onNavigate(i)` callback passed to screens | `onNavigate: ValueChanged<int>` prop on `HomeScreen` |
| Home tab: gradient background on nav bar | `AppBottomNav` detects `activeIndex == 0` and applies `verticalGradient` |
| Other tabs: white nav bar with purple active icon | `AppBottomNav` uses `AppColors.white` bg + `AppColors.g1` active color |

---

## Scan State Machine

| Frontend `ScanState` (TypeScript union) | Flutter `ScanState` (enum) |
|----------------------------------------|---------------------------|
| `"idle"` | `ScanState.idle` |
| `"preparing"` | `ScanState.preparing` |
| `"deviceCheck"` | `ScanState.deviceCheck` |
| `"regionSelection"` | `ScanState.regionSelection` |
| `"positioning"` | `ScanState.positioning` |
| `"countdown"` | `ScanState.countdown` |
| `"qualityCheck"` | `ScanState.qualityCheck` |
| `"qualityFailed"` | `ScanState.qualityFailed` |
| `"regionComplete"` | `ScanState.regionComplete` |
| `"scanSummary"` | `ScanState.scanSummary` |
| `"analyzing"` | `ScanState.analyzing` |
| `"complete"` | `ScanState.complete` |

---

## Shared Components / Widgets

| Existing Frontend Component | Flutter Widget | File |
|-----------------------------|---------------|------|
| `Avatar` component | `AvatarWidget` | `lib/shared/widgets/avatar_widget.dart` |
| `PurpleBtn` component | `PrimaryButton` (variants: primary / secondary / white) | `lib/shared/widgets/primary_button.dart` |
| `Divider` component (on gradient) | `GradientDivider` | `lib/shared/widgets/gradient_divider.dart` |
| Section label `<p style="...uppercase...">` | `SectionLabel` | `lib/shared/widgets/section_label.dart` |
| `BottomNav` component | `AppBottomNav` | `lib/shared/widgets/app_bottom_nav.dart` |
| `DentalGuide` SVG component | `_DentalGuidePainter` (CustomPainter) | inside `scan_screen.dart` |
| `CheckItem` animated component | `_AnimatedCheckItem` | inside `scan_screen.dart` |
| `_GradientScaffold` (implicit pattern) | `_GradientScaffold` | inside `scan_screen.dart` |

---

## Design Tokens

| Existing Frontend (`const C`) | Flutter Constant | File |
|-------------------------------|-----------------|------|
| `C.g1 = "#6859D8"` | `AppColors.g1 = Color(0xFF6859D8)` | `app_colors.dart` |
| `C.g2 = "#462FB5"` | `AppColors.g2 = Color(0xFF462FB5)` | `app_colors.dart` |
| `C.cardSolid = "#7868E2"` | `AppColors.cardSolid = Color(0xFF7868E2)` | `app_colors.dart` |
| `C.cardSolidAlt = "#8070EA"` | `AppColors.cardSolidAlt = Color(0xFF8070EA)` | `app_colors.dart` |
| `C.cardSolidDeep = "#5040C0"` | `AppColors.cardDeep = Color(0xFF5040C0)` | `app_colors.dart` |
| `C.lavender = "#E9E7FF"` | `AppColors.lavender = Color(0xFFE9E7FF)` | `app_colors.dart` |
| `C.lightLavender = "#F5F4FF"` | `AppColors.lightLavender = Color(0xFFF5F4FF)` | `app_colors.dart` |
| `C.white = "#FFFFFF"` | `AppColors.white = Color(0xFFFFFFFF)` | `app_colors.dart` |
| `C.offWhite = "#FAFAFF"` | `AppColors.offWhite = Color(0xFFFAFAFF)` | `app_colors.dart` |
| `C.navy = "#171735"` | `AppColors.navy = Color(0xFF171735)` | `app_colors.dart` |
| `C.secondaryText = "#6F7085"` | `AppColors.secondaryText = Color(0xFF6F7085)` | `app_colors.dart` |
| `C.border = "#E7E7F0"` | `AppColors.border = Color(0xFFE7E7F0)` | `app_colors.dart` |
| `GRAD = "linear-gradient(160deg, #6859D8 0%, #462FB5 100%)"` | `AppColors.primaryGradient` | `app_colors.dart` |
| `GRAD_V = "linear-gradient(180deg, ...)"` | `AppColors.verticalGradient` | `app_colors.dart` |
| `GRAD_H = "linear-gradient(90deg, ...)"` | `AppColors.horizontalGradient` | `app_colors.dart` |

---

## Typography

| Existing Frontend | Flutter Equivalent |
|-------------------|-------------------|
| `'Outfit', 'Inter', sans-serif` | `GoogleFonts.outfit(...)` via `google_fonts` package |
| `fontSize: 28, fontWeight: 800` (hero heading) | `AppTypography.headingXL` |
| `fontSize: 22, fontWeight: 800` (section heading) | `AppTypography.headingLg` |
| `fontSize: 34, fontWeight: 800` (stat value) | `AppTypography.metricValue` |
| `fontSize: 11, letterSpacing: 1.0, uppercase` (section label) | `AppTypography.overline` / `SectionLabel` widget |

---

## Mock Data

| Existing Frontend | Flutter Equivalent | File |
|-------------------|--------------------|------|
| `const screenings = [...]` in `App.tsx` | `MockData.screenings` | `lib/core/services/mock_data.dart` |
| `const clinics = [...]` in `App.tsx` | `MockData.clinics` | `lib/core/services/mock_data.dart` |
| `const DAILY_TIPS = [...]` in `App.tsx` | `MockData.dailyTips` | `lib/core/services/mock_data.dart` |
| `const REGIONS = [...]` in `App.tsx` | `MockData.scanRegions` | `lib/core/services/mock_data.dart` |

---

## Models

| Existing Frontend (inline object shape) | Flutter Model | File |
|-----------------------------------------|--------------|------|
| `screenings[i]` object (`id, date, fullDate, images, teeth, region, weekday`) | `ScreeningModel` | `lib/core/models/screening_model.dart` |
| `clinics[i]` object (`id, name, distance, services, rating`) | `ClinicModel` | `lib/core/models/clinic_model.dart` |

---

## Routes

| Existing Frontend (tab index) | Flutter Tab | Screen |
|-------------------------------|-------------|--------|
| `tab === 0` | index 0 | `HomeScreen` |
| `tab === 1` | index 1 | `ScanScreen` |
| `tab === 2` | index 2 | `HistoryScreen` |
| `tab === 3` | index 3 | `ClinicsScreen` |
| `tab === 4` | index 4 | `ProfileScreen` |

Cross-tab navigation (e.g. "Start Dental Scan" on Home → Scan tab) is handled
via the `onNavigate` callback passed from `AppShell` down to `HomeScreen`.

---

## Assets

| Existing Frontend Asset | Flutter Asset / Approach |
|------------------------|--------------------------|
| `REFERENCEUI.png` (reference image, not rendered in UI) | Not included — reference only |
| Google Fonts: Outfit | `google_fonts` package — `GoogleFonts.outfit(...)` |
| SVG icons (inline in JSX) | `CustomPainter` subclasses in `app_bottom_nav.dart`; `Icons.*` (Material) for in-screen icons |
| Dental arch SVG guide | `_DentalGuidePainter` (CustomPainter) in `scan_screen.dart` |

---

## Architecture Comparison

```
EXISTING FRONTEND (React/Vite)          FLUTTER PROJECT
─────────────────────────────           ─────────────────────────────
src/App.tsx (monolithic)                lib/
                                        ├── main.dart
                                        ├── app/
                                        │   ├── app.dart          ← MaterialApp + AppShell
                                        │   └── theme.dart        ← ThemeData
                                        ├── core/
                                        │   ├── constants/        ← AppColors, AppSpacing, etc.
                                        │   ├── models/           ← ScreeningModel, ClinicModel
                                        │   └── services/         ← MockData
                                        ├── shared/
                                        │   └── widgets/          ← AvatarWidget, PrimaryButton, etc.
                                        └── features/
                                            ├── home/screens/     ← HomeScreen
                                            ├── scan/screens/     ← ScanScreen (full FSM)
                                            ├── history/screens/  ← HistoryScreen
                                            ├── clinics/screens/  ← ClinicsScreen
                                            └── profile/screens/  ← ProfileScreen
```

---

## Key Design Decisions

1. **Gradient background on Home** — The entire Home screen uses `AppColors.verticalGradient`
   as a `Container` decoration, matching the frontend's `background: GRAD_V` on the scroll container.

2. **Bottom nav gradient on Home tab** — `AppBottomNav` detects `activeIndex == 0` and switches
   between gradient (Home) and white (other tabs) to reproduce the frontend's seamless blending.

3. **Embossed hero card** — Reproduced using layered `BoxShadow` entries (dark drop shadow + white
   inner highlight offset) on `_DeviceHeroCard`, matching the frontend's `inset` + `drop-shadow` CSS.

4. **Scan FSM** — The entire scan workflow is a single `StatefulWidget` with a `ScanState` enum,
   matching the frontend's `useState<ScanState>` pattern. Timer-driven transitions replace `setTimeout`/`setInterval`.

5. **No WebView** — Every screen is implemented with native Flutter widgets (Container, Column, Row,
   CustomPaint, ListView, etc.). No HTML is embedded.

6. **Color system strictly mirrors frontend** — All six gradient/color constants from `const C`
   in `App.tsx` are replicated in `AppColors` with identical hex values.
