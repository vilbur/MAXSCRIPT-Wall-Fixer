## UI tooltips

- In control tooltips, put each callback description on its own line and separate callback descriptions with an empty line.
- Write callback names in CAPITAL letters, followed by a colon and a space. Examples: `LMB: `, `RMB: `, `CTRL + RMB: `.

Example:

```maxscript
tooltip:"LMB: Run the primary action.\n\nCTRL + RMB: Open additional options."
```

## Verification

- Keep verification proportional to the risk and complexity of the change.
- For simple, low-risk edits such as UI text, spacing, sizing, colors, or tooltip changes, do not create or run unnecessary tests.
- Run targeted checks only when they provide meaningful confidence for the specific change.
