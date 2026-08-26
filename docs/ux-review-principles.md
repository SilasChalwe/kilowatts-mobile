# Kilowatts configuration UX rules

These rules apply to homeowner and installer configuration screens.

1. **Review first.** If configuration already exists, show its current or last-known values before offering inputs.
2. **Forms are actions, not pages.** Add and edit forms open only after the user chooses **Add**, **Edit**, **Configure**, or **Change**.
3. **Do not invent live state.** Values not published by Central must be labelled unavailable. A locally remembered value must be labelled as last applied from this device.
4. **No ineffective fields.** Every visible input must change a value accepted by the current firmware or access-control contract.
5. **Keep context after changes.** After a successful action, return to the review surface and show the updated summary.
6. **Prefer concise labels.** Use explanatory copy only where it prevents a real mistake or clarifies source-of-truth limitations.
7. **Prevent invalid choices.** Do not offer relay GPIOs that are already assigned or not declared safe by firmware.
8. **Preserve hidden configuration.** Editing one part of a saved configuration must not silently reset fields the editor does not expose.
