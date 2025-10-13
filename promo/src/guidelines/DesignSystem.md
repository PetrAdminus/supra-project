# ElyxS Design System Reference

The ElyxS interface combines neo-futuristic gradients with glassmorphism. Every new UI element must respect the rules below so that the product keeps a consistent Supra look and feel.

## 1. Visual Direction

- Dark cosmic background with layered gradients and subtle grid noise.
- Glass surfaces with soft borders and glow effects for highlighted content.
- Motion should be smooth (150-250 ms ease) and only reinforce focus states.
- Avoid flat, sharp corners unless explicitly noted for utility elements.

## 2. Color Tokens

Primary brand colors:

| Token       | Hex      | Usage                                      |
|-------------|----------|--------------------------------------------|
| cyan-400    | #22D3EE  | Key accents, highlights, positive callouts |
| cyan-500    | #06B6D4  | Primary buttons, active states             |
| purple-400  | #C084FC  | Secondary accents, gradient start          |
| purple-500  | #A855F7  | Secondary actions, glow shadows            |
| pink-400    | #F472B6  | Tertiary accent, celebratory highlights    |

Support palette (surface and neutrals):

| Token       | Hex      | Usage                                |
|-------------|----------|--------------------------------------|
| slate-900   | #0F172A  | Main background                      |
| slate-800   | #1E293B  | Secondary surface                    |
| violet-900  | #4C1D95  | Deep gradient stops                  |
| blue-900    | #1E3A8A  | Secondary gradient stops             |
| gray-100    | #F3F4F6  | Light text on dark surfaces          |
| gray-300    | #D1D5DB  | Muted text, placeholders             |
| gray-400    | #9CA3AF  | Borders, helper text                 |

Status colors:

| Status  | Token (hex) | Notes                  |
|---------|-------------|------------------------|
| Success | #5BE9B9     | Confirmations, badges  |
| Warning | #FFD479     | Pending state          |
| Danger  | #FF9BA6     | Errors, destructive UI |

## 3. Typography

- Display font: Orbitron (weights 600-800) for headings and hero text.
- Body font: Inter (weights 400-600) for paragraphs, labels, buttons.
- Base font size: 16px. Heading scale (mobile first):
  - H1: 48-64px (Orbitron, weight 700-800)
  - H2: 32-40px
  - H3: 24-28px
  - Paragraph: 16px, line-height 1.6-1.7
- Use uppercase sparingly (metrics badges, tiny labels).

## 4. Layout and Spacing

- Max content width: 1280px inside `.container` with `padding: 0 24px`.
- Section vertical rhythm: multiples of 24px (24, 48, 72).
- Grid utilities:
  - `.glass-grid` wrappers for 2 or 3 column layouts.
  - `.glass-card` elements with consistent padding (24px desktop, 16px mobile).
- Use sticky sidebars for dashboard navigation at 24px top offset.

## 5. Components

### Buttons

- Base class: `Button` from `src/components/ui/button.tsx`.
- Variants: `default`, `secondary`, `ghost`, `outline`, `link`.
- Primary CTA: gradient background from cyan-500 to purple-600 plus glow shadow.
- Add icon spacing (`gap-2`) and consistent height (40px for default).

### Cards

- Use `glass` or `glass-strong` classes with `border` in cyan/purple tint.
- Corners: 16px radius.
- Titles use Orbitron, body text Inter.
- Footer sections separated by subtle border gradient or spacing.

### Tables and Lists

- Prefer `table.tsx` utilities for logs and history.
- Zebra striping is discouraged; rely on glass panels and divider lines.
- Empty states require icon, message, and optional CTA.

### Forms

- Form elements come from `input.tsx`, `select.tsx`, `checkbox.tsx`, etc.
- Label alignment: top-left, 12px spacing to field.
- Error text color: `#FF9BA6` with small font size (12-13px).
- Buttons inside forms: align right or full-width on mobile (<768px).

## 6. Interactions and States

- Hover: increase glow intensity or shift gradient (no harsh color swap).
- Focus: outline 3px using `rgba(34, 211, 238, 0.35)` and retain box-shadow.
- Disabled: reduce opacity to 50%, remove glow, keep text readable.
- Loading: use skeleton placeholders (see `skeleton.tsx`) or spinner from `Button` with `disabled`.

## 7. Motion

- Use CSS transitions 180ms ease for opacity, transform, border color.
- For large hero elements, apply subtle pulse animations with delays (2-3s).
- Avoid horizontal parallax on mobile to prevent motion sickness.

## 8. Localization

- Supported languages: en, ru, es, zh, fr, de.
- Use `t('key')` via `react-i18next` (or adapter) instead of static strings.
- Provide fallbacks for missing translations; never leave raw keys in UI.
- UI controls for language use ISO codes in lowercase (`en`, `ru`, ...).

## 9. Accessibility

- Minimum contrast ratio: 4.5:1 for body text on any surface.
- Ensure focus states are visible on dark backgrounds.
- Interactive elements must have ARIA labels when icons stand alone.
- All motion effects require `prefers-reduced-motion` fallback (disable animations).

## 10. Asset Usage

- Logos and hero artwork must use `ImageWithFallback` where possible.
- Limit PNG usage to high-detail illustrations; prefer SVG for icons.
- Keep asset filenames deterministic (kebab-case) and document origin.

## 11. Review Checklist

Before merging any UI change:

1. Colors, typography, and spacing match tokens from this design system.
2. Mobile (width <= 768px) and desktop layouts render correctly.
3. Loading, empty, error states are implemented.
4. Localization keys exist for all displayed strings.
5. Accessibility checks (contrast, focus, aria) pass manual review.

Version: 1.1  
Last update: October 2025
