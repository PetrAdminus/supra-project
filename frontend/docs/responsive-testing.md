# Responsive & Locale Testing Notes

## Viewports to verify in Storybook
- Desktop (1280px and wider)
- Tablet (768px)
- Mobile (360px / 414px)

### Key screens to check
1. DashboardPage — verify metric cards (spacing between label/value) and the `glass-card__metric` grid.
2. TicketsPage — purchase form plus ticket history; make sure `ticket-list__item` collapses gracefully.
3. LogsPage — event table and the error toggle. Below 600px rows become stacked blocks.
4. AdminPage — whitelisting summary and gas/VRF forms; watch for padding and horizontal overflow.

## Locale testing
- Use the globe icon in the Storybook toolbar to switch between `ru` and `en`.
- On each viewport, quickly scan both locales for truncation or awkward line breaks.

## Known gaps / next steps
- When Storybook 9 provides a replacement for the viewport addon, reintroduce presets (360/414/768).
- Prepare a quick QA checklist (screenshots + expected layout notes) and run on real devices.
