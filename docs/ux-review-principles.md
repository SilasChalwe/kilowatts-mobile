# Kilowatts product UX rules

These rules apply to the entire homeowner and installer product, not only configuration forms.

## Information architecture

1. **One navigation model per platform.** Web never uses the mobile bottom navigation. Wide web uses a persistent sidebar; compact web uses one hamburger/drawer. Native mobile uses the bottom navigation for primary destinations and must not add a competing hamburger navigation.
2. **Installer is a superset role.** Installer users keep homeowner controls and gain installation, operations and access-management destinations. Do not create a second nested application shell.
3. **Normal web destinations stay visible.** Overview, Loads, System, Alerts, Battery & Power, History & Reports and Settings belong in web navigation. Do not hide standard web destinations behind a mobile-style More page.
4. **No dead ends.** A standalone detail or administration route must provide normal back navigation. A workspace page stays inside the web shell.

## Layout and hierarchy

5. **Use responsive grids on web.** Related cards should use two- or three-column grids when space allows. Do not stretch phone-style single-column stacks across desktop canvases.
6. **Hierarchy must be visible.** Page title, page context, section title, data label and value must have different visual weight. Avoid giving every line the same emphasis.
7. **Bound empty and error states.** Empty/error states belong in a designed panel with a clear next action where one exists. Do not leave a small message floating in a large empty canvas.
8. **Keep primary actions close to their object.** Configuration actions live on the relevant card; global page actions live in the page header.
9. **Use space deliberately.** Large blank areas are acceptable only when they express an intentional empty state. Otherwise use the available web width to organize useful information.

## Configuration behavior

10. **Review first.** If configuration already exists, show its current or last-known values before offering inputs.
11. **Forms are actions, not pages.** Add and edit forms open only after the user chooses **Add**, **Edit**, **Configure**, or **Change**.
12. **Do not invent live state.** Values not published by Central must be labelled unavailable. A locally remembered value must be labelled as last applied from this device.
13. **No ineffective fields.** Every visible input must change a value accepted by the current firmware or access-control contract.
14. **Keep context after changes.** After a successful action, return to the review surface and show the updated summary.
15. **Prevent invalid choices.** Do not offer relay GPIOs that are already assigned or not declared safe by firmware.
16. **Preserve hidden configuration.** Editing one part of a saved configuration must not silently reset fields the editor does not expose.

## Product language and feedback

17. **Prefer concise labels.** Explain only what prevents a real mistake, clarifies a source-of-truth limitation or teaches a necessary domain concept.
18. **Show command state.** Remote actions should visibly progress through sending/confirmed/failed rather than changing silently.
19. **Use domain language consistently.** Central Node, Smart Node, Automatic, Fixed, priority, schedule and planning power should use the same wording everywhere.
20. **Never show developer failures as product UI.** Runtime exceptions, framework banners and raw backend errors must be replaced by actionable product states.
