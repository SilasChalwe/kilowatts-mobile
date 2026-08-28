# Kilowatts product UI/UX contract

These rules apply to every homeowner and installer surface. They are product constraints, not optional styling guidance.

## Information architecture

1. **One navigation model per platform.** Web uses a sidebar on wide layouts and one hamburger/drawer on compact layouts. Do not add bottom navigation to web. Do not duplicate the same destinations as page buttons.
2. **One title layer.** The application shell owns the current page title. Embedded workspace screens must not repeat the same heading inside the page.
3. **Role belongs to identity.** Homeowner/installer role belongs in the profile/account area, not in the page header.
4. **Status has one home.** Global Online/Offline belongs in the application header. Do not repeat a second connection-health card on Overview.
5. **Do not duplicate destinations.** Alerts, Topology, Operations, Users & access and other primary destinations live in navigation. Feature screens should link to them only when the link is a genuine task step.

## Dashboard and layout

6. **Design for scanning first.** Overview starts with a small set of compact KPIs, followed by one dominant operational/analytics surface and secondary detail cards.
7. **Use responsive grids deliberately.** Desktop/web cards should fill the available workspace in useful columns instead of forming long phone-style stacks or leaving orphan cards and large blank areas.
8. **One metric, one meaning.** Never show the same firmware value under multiple labels. Power, counts, connectivity and configuration belong in separate semantic groups.
9. **No decorative dashboards.** Every card must answer a real user question or support a real action. Do not add widgets merely to fill space.
10. **Charts keep context.** Historical telemetry is timestamped, persistent, bounded and downsampled. New readings extend history rather than replacing it. Axes, units and current/latest state must be readable.

## Accessibility

11. **Never rely on colour alone.** Online/Offline, ON/OFF, warning/safe, success/failure and modes must include readable text, icons, labels, shape or another non-colour cue.
12. **Maintain readable contrast.** Normal text and status labels must meet WCAG AA contrast on the surface where they are displayed. Tertiary/offline text cannot be light grey on white.
13. **Touch and pointer targets are deliberate.** Interactive controls use at least a 44x44 target where practical and provide visible hover/focus feedback on web/desktop.
14. **Screen-reader grouping matters.** Compound metric/status components should expose one useful semantic announcement rather than reading decorative icons and fragments independently.
15. **Do not encode categories only with red/green.** Where multiple states need visual distinction, pair colour with explicit labels/icons and keep patterns understandable in greyscale.

## Configuration and operations

16. **Review first.** If configuration already exists, show its current or last-known values before offering inputs.
17. **Forms are actions, not pages.** Add and edit forms open only after the user chooses **Add**, **Edit**, **Configure**, or **Change**.
18. **Do not invent live state.** Values not published by Central must be labelled unavailable. A locally remembered value must be labelled as last applied from this device.
19. **No ineffective fields.** Every visible input must change a value accepted by the current firmware or access-control contract.
20. **Keep context after changes.** After a successful action, return to the review surface and show the updated summary.
21. **Prefer concise labels.** Use explanatory copy only where it prevents a real mistake or clarifies source-of-truth limitations.
22. **Prevent invalid choices.** Do not offer relay GPIOs that are already assigned or not declared safe by firmware.
23. **Preserve hidden configuration.** Editing one part of a saved configuration must not silently reset fields the editor does not expose.
24. **Confirm real outcomes.** Saving connection/configuration is not the same as a successful device response. Show Saved, Connecting, Connected, Confirmed or Failed according to the actual result.

## Quality gate

25. **Source review is not runtime validation.** A UI/UX change is not production-ready until Flutter analysis/tests and a real web/mobile render pass have been completed.
26. **Do not merge known-broken UI.** Compile errors, dead-end navigation, overflow, inaccessible states or misleading telemetry semantics block release.
