# Convert-ConstraintToRegex — Implementation Plan

## Overview

Rewrite the `Convert-ConstraintToRegex` function in `src/modules/Az.Naming.Config/Source/Functions/New-AzResourceNamePolicy.ps1` with an extensible, block-based architecture that converts descriptive `validChars` text (from `config/validChars.txt`) into regex patterns.

The file contains 131 lines of descriptive text covering **7 distinct pattern categories**:

| # | Category | Example | ~Count |
|---|----------|---------|--------|
| 1 | Allowed character classes | `Alphanumerics, hyphens, underscores` | 65 lines |
| 2 | Start/End constraints | `Start with a letter. End with alphanumeric.` | 50 blocks |
| 3 | Consecutive char constraints | `Can't use consecutive hyphens` | 8 blocks |
| 4 | Exclusion patterns | `Can't use:<br>\`<>*%&:\?\`` | 20 lines |
| 5 | Fixed/Enum values | `Must be \`default\`.` / `Use one of:` | 7 lines |
| 6 | Informational/Notes | `Note: A period must be followed by...` | 5 blocks |
| 7 | Special/Complex | DNS labels, solution patterns, Punycode | 5 lines |

---

## Stages

- [Stage 1 — Architecture & Core Parser](#stage-1--architecture--core-parser)
- [Stage 2 — Character Class Recognition](#stage-2--character-class-recognition)
- [Stage 3 — Start/End & Consecutive Constraints](#stage-3--startend--consecutive-constraints)
- [Stage 4 — Fixed Values, Enums & Special Cases](#stage-4--fixed-values-enums--special-cases)
- [Stage 5 — Integration, Testing & Cleanup](#stage-5--integration-testing--cleanup)

---

## Stage 1 — Architecture & Core Parser

**Status:** Complete

### Prompt

> **Context:** I'm working in `c:\Users\admin\Source\Repos\aznaming.config`. The file `config/validChars.txt` contains 131 lines of descriptive text for Azure resource naming rules. Each line describes allowed characters and constraints (e.g., `"Alphanumerics and hyphens<br><br>Start and end with alphanumeric."`). These are used in `src/modules/Az.Naming.Config/Source/Functions/New-AzResourceNamePolicy.ps1` where `Convert-ConstraintToRegex` converts them to regex patterns. The current implementation is limited — it uses hardcoded if/elseif branches. See `docs/convert-constraint-to-regex-plan.md` for the full plan.
>
> **Task — Stage 1 of 5: Architecture & Core Parser**
>
> Create a new PowerShell file `src/modules/Az.Naming.Config/Source/Functions/Convert-ConstraintToRegex.ps1` with an extensible, block-based architecture:
>
> 1. **Block Splitter** — A function `Split-ConstraintBlocks` that takes a raw validChars string and splits it into individual constraint blocks. Blocks are separated by `<br><br>` (with optional spaces). Within a block, `<br>` and `<br/>` are treated as sentence separators. Strip all HTML (`<br>`, `&nbsp;`, etc.) and markdown (`**bold**`, `` `code` ``, `[links](url)`) and normalize whitespace. Return an array of clean text blocks.
>
> 2. **Rule Registry** — A data structure (array of `[ordered]@{ Name; Pattern; Action }`) where `Pattern` is a regex matched against each block, and `Action` is a scriptblock that receives the match and a shared state hashtable. New rules can be added by appending to the array. Categories of rules to register (leave Action as placeholder `{}` for now):
>    - `CharClass_*` — for character class tokens (alphanumerics, hyphens, etc.)
>    - `Start_*` — for start constraints
>    - `End_*` — for end constraints
>    - `Cant_*` — for "can't" restrictions
>    - `FixedValue` — for "Must be X" patterns
>    - `EnumValue` — for "Use one of:" patterns
>    - `Note` — for informational blocks (skip)
>
> 3. **Orchestrator** — Rewrite `Convert-ConstraintToRegex` to: split into blocks → iterate blocks → match against rule registry → accumulate state → assemble final regex. The state hashtable should track: `AllowedChars` (list), `StartChars` (string), `EndChars` (string), `Lookaheads` (list), `Lookbehinds` (list), `FixedValue` (string), `IsExclusion` (bool), `ExcludedChars` (string).
>
> 4. Keep the existing function signature (pipeline input with `$InputObject` hashtable containing `validChars`, `minLength`, `maxLength`).
>
> Follow the existing codebase style: `Verb-Noun` naming, `[ordered]@{}` hashtables, pipeline patterns, backtick line continuation for readability.

---

## Stage 2 — Character Class Recognition

**Status:** Complete

### Prompt

> **Context:** I'm working in `c:\Users\admin\Source\Repos\aznaming.config`. In Stage 1, I created `src/modules/Az.Naming.Config/Source/Functions/Convert-ConstraintToRegex.ps1` with:
> - `Split-ConstraintBlocks` — splits validChars text into clean blocks
> - A rule registry (array of `@{ Name; Pattern; Action }`) with placeholder actions
> - `Convert-ConstraintToRegex` orchestrator that iterates blocks through the registry, using a state hashtable with keys: `AllowedChars`, `StartChars`, `EndChars`, `Lookaheads`, `Lookbehinds`, `FixedValue`, `IsExclusion`, `ExcludedChars`
>
> See `docs/convert-constraint-to-regex-plan.md` for the full plan. Stage 1 is complete.
>
> **Task — Stage 2 of 5: Character Class Recognition**
>
> Implement the `Action` scriptblocks for all `CharClass_*` rules and the exclusion (`Can't use:`) rules:
>
> 1. **CharClass token dictionary** — Map these descriptive terms to regex fragments. Each adds to `$state.AllowedChars`:
>    - `All characters` → `.` (special: sets a "match all" flag)
>    - `Alphanumerics` / `Alphanumeric` → `a-zA-Z0-9`
>    - `Letters and numbers` → `a-zA-Z0-9`
>    - `Lowercase letters` / `lowercase` → `a-z`
>    - `numbers` / `digits` → `0-9`
>    - `hyphens` → `-`
>    - `underscores` → `_`
>    - `periods` → `\\.`
>    - `parentheses` → `()`
>    - `spaces` → `\\s` or literal space
>    - `slashes` → `/`
>    - Handle `Lowercase letters, numbers, and hyphens` as a single block → `a-z0-9-`
>    - Handle `Lowercase letters and numbers` → `a-z0-9`
>
> 2. **Exclusion patterns** — For `Can't use:` blocks:
>    - Extract chars between backticks (`` ` ``)
>    - Escape regex-special characters in the extracted set
>    - Set `$state.IsExclusion = $true` and populate `$state.ExcludedChars`
>    - The "or control characters" / "or space" suffixes should add `\x00-\x1F` / `\s` to excluded set
>
> 3. **Regex assembly for exclusions** — When `IsExclusion` is true, build a negated character class like `[^excludedChars]`
>
> Test by running against all 131 lines in `config/validChars.txt` and verify each produces the right character class (not the full regex yet — just the `[charClass]` portion). Print a summary showing input → detected chars.

---

## Stage 3 — Start/End & Consecutive Constraints

**Status:** Complete

### Prompt

> **Context:** I'm working in `c:\Users\admin\Source\Repos\aznaming.config`. Stages 1-2 are complete in `src/modules/Az.Naming.Config/Source/Functions/Convert-ConstraintToRegex.ps1`. The function now:
> - Splits validChars text into blocks
> - Recognizes character class tokens and builds `$state.AllowedChars`
> - Handles `Can't use:` exclusion patterns with `$state.ExcludedChars`
>
> See `docs/convert-constraint-to-regex-plan.md` for the full plan. Stages 1-2 are complete.
>
> **Task — Stage 3 of 5: Start/End & Consecutive Constraints**
>
> Implement the `Action` scriptblocks for `Start_*`, `End_*`, and `Cant_*` rules:
>
> 1. **Start constraints** — Set `$state.StartChars` based on:
>    - `Start with a letter` → `[a-zA-Z]` (or `[a-z]` if lowercase-only context)
>    - `Start with alphanumeric` / `Start with a letter or number` → `[a-zA-Z0-9]` (or `[a-z0-9]`)
>    - `Start with lowercase letter` → `[a-z]`
>    - `Start with lowercase letter or number` → `[a-z0-9]`
>
> 2. **End constraints** — Set `$state.EndChars`:
>    - `End with alphanumeric` / `End with letter or number` → `[a-zA-Z0-9]` (or `[a-z0-9]`)
>    - `End with alphanumeric or underscore` → `[a-zA-Z0-9_]`
>    - `End with lowercase letter or number` → `[a-z0-9]`
>
> 3. **"Can't start/end" constraints** — These are the negative version:
>    - `Can't start or end with hyphen` → StartChars excludes `-`, EndChars excludes `-`
>    - `Can't end with period` → EndChars excludes `.`
>    - `Can't end with period or space` → EndChars excludes `. `
>    - `Can't start with underscore, hyphen, or number` → StartChars = `[a-zA-Z]`
>
> 4. **Consecutive constraints** — Add to `$state.Lookaheads`:
>    - `Can't use consecutive hyphens` / `Consecutive hyphens not allowed` → `(?!.*--)`
>    - `Can't contain a sequence of more than two hyphens` → `(?!.*---)`
>    - `Each hyphen must be preceded and followed by an alphanumeric` → `(?!.*--)` (same effect)
>
> 5. **"Can't be all numbers"** → `(?!^\d+$)` lookahead
>
> Update the regex assembly to incorporate start/end chars. When both StartChars and EndChars are set: `^[startChars][middleChars]{min-2,max-2}[endChars]$`. When only start: `^[startChars][allChars]{min-1,max-1}$`. Handle the case when min=1 (the start char alone is valid, so middle is optional).

---

## Stage 4 — Fixed Values, Enums & Special Cases

**Status:** Complete

### Prompt

> **Context:** I'm working in `c:\Users\admin\Source\Repos\aznaming.config`. Stages 1-3 are complete in `src/modules/Az.Naming.Config/Source/Functions/Convert-ConstraintToRegex.ps1`. The function now handles character classes, exclusions, start/end constraints, and consecutive character rules.
>
> See `docs/convert-constraint-to-regex-plan.md` for the full plan. Stages 1-3 are complete.
>
> **Task — Stage 4 of 5: Fixed Values, Enums & Special Cases**
>
> 1. **Fixed values** — `Must be \`X\`` patterns → return `^X$` exactly (escape regex-special chars in X). Handle: `Must be 'ActiveDirectory'`, `Must be 'current'`, `Must be 'Default'`, `Must be 'default'`.
>
> 2. **Enum values** — `Use one of:` followed by backtick-delimited values → `^(val1|val2|...)$`. Handle: `Use one of: custom effective`, `Use one of: MCAS Sentinel WDATP WDATP_EXCLUDE_LINUX_PUBLIC_PREVIEW`.
>
> 3. **Fixed format** — `Should always be **$default**` → `^\$default$`. `Must be in format: VaultName_KeyName_KeyVersion` → `^[^_]+_[^_]+_[^_]+$`.
>
> 4. **Special patterns**:
>    - `Numbers and periods` → `^[0-9.]+$`
>    - `Must be a globally unique identifier (GUID)` → standard GUID regex
>    - `Only alphanumerics are valid` → `^[a-zA-Z0-9]+$`
>    - `Any URL characters and case sensitive` → broad URL-safe regex
>    - `Datastore name consists only of lowercase letters, digits, and underscores` → `^[a-z0-9_]+$`
>    - `Each label can contain alphanumerics, underscores, and hyphens. Each label is separated by a period.` → `^[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+)*$`
>
> 5. **Informational blocks to skip** — `Note:` prefixed blocks, `For more information, see [...]`, `The solution type is case-sensitive`, `Volume can't be named...`, `Only predefined values are valid`. These should not affect the regex but could be stored as metadata in `$state.Notes`.
>
> 6. Ensure that fixed/enum values short-circuit the regex assembly (return immediately, don't combine with char classes).

---

## Stage 5 — Integration, Testing & Cleanup

**Status:** Complete

### Prompt

> **Context:** I'm working in `c:\Users\admin\Source\Repos\aznaming.config`. Stages 1-4 are complete in `src/modules/Az.Naming.Config/Source/Functions/Convert-ConstraintToRegex.ps1`. The function now handles all pattern categories: char classes, exclusions, start/end, consecutive, fixed values, enums, and special cases.
>
> See `docs/convert-constraint-to-regex-plan.md` for the full plan. Stages 1-4 are complete.
>
> **Task — Stage 5 of 5: Integration, Testing & Cleanup**
>
> 1. **Integration** — Update `New-AzResourceNamePolicy.ps1` to remove the old inline `Convert-ConstraintToRegex` function and call the new one from the separate file. Verify the module manifest (`Az.Naming.Config.psd1`) includes the new file in `NestedModules` or that it's auto-discovered.
>
> 2. **Comparison test** — Write a test script `src/scripts/%Test-ValidChars.ps1` that:
>    - Reads all config JSON files from `config/*.json`
>    - For each resource with a `validChars` value, calls `Convert-ConstraintToRegex`
>    - Compares the generated regex against the existing `regex` value in the JSON
>    - Reports: matches, improvements (was null/wrong, now correct), regressions (was correct, now different), and still-unhandled
>
> 3. **Coverage report** — Run against all 131 lines in `config/validChars.txt` and produce a summary: how many lines produce a valid regex, how many fall back to default, how many return null.
>
> 4. **Cleanup** — Remove dead code, add comment-based help to all public functions, ensure consistent formatting.
