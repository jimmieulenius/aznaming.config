# Adding Constraint Rules to Convert-ConstraintToRegex

## How It Works — The Big Picture

```
validChars string                          Final regex
─────────────────                          ───────────
"Alphanumerics and hyphens<br><br>         ^[a-zA-Z0-9]
 Start with a letter.                      [a-zA-Z0-9\-]{0,79}$
 Can't use consecutive hyphens."
         │
         ▼
   Split-ConstraintBlocks        ← splits on <br><br>, strips HTML/markdown
         │
         ▼
   Block 1: "Alphanumerics and hyphens"
   Block 2: "Start with a letter. Can't use consecutive hyphens."
         │
         ▼
   Sentence split (on ". " and "; ")
         │
         ▼
   Sentence: "Alphanumerics and hyphens"
   Sentence: "Start with a letter"
   Sentence: "Can't use consecutive hyphens"
         │
         ▼
   Match each sentence against Rule Registry (first match wins)
         │
         ▼
   Each rule's Action modifies shared $state hashtable
         │
         ▼
   Regex Assembly reads $state → builds final regex
```

## The Rule Registry

Rules live in `New-ConstraintRuleRegistry` inside `Convert-ConstraintToRegex.ps1`. Each rule is an `[ordered]@{}` hashtable with three keys:

```powershell
[ordered]@{
    Name    = 'Category_DescriptiveName'   # Unique identifier for debugging
    Pattern = '(?i)regex to match'         # Regex tested against each sentence
    Action  = {                            # Scriptblock that modifies $state
        param($m, $state)
        # ...
    }
}
```

| Key       | Type          | Description |
|-----------|---------------|-------------|
| `Name`    | `[string]`    | A unique identifier. Convention: `Category_Description` (e.g. `CharClass_Alphanumerics`, `Start_Letter`, `Cant_EndHyphen`). Used only for debugging/logging. |
| `Pattern` | `[string]`    | A regex pattern tested via `[regex]::Match($sentence, $rule.Pattern)`. Use `(?i)` for case-insensitive matching. Anchoring with `^` is recommended to avoid false positives. |
| `Action`  | `[scriptblock]` | Called when `Pattern` matches. Receives up to 3 positional arguments. Modifies the shared `$state` hashtable. |

### Rule evaluation order matters

Rules are evaluated **in array order**, and the **first matching rule wins** for each sentence. This means:

- **Specific rules must come before general ones.** For example, `CharClass_AlphanumericHyphens` (matches "alphanumerics and hyphens") must appear before `CharClass_AlphanumericCombo` (catch-all for "alphanumerics, X, Y, and Z").
- If a sentence matches a rule, no further rules are tried for that sentence.

### Naming convention

Use these category prefixes:

| Prefix         | Purpose | Example |
|----------------|---------|---------|
| `CharClass_*`  | Allowed character class tokens | `CharClass_AlphanumericHyphens` |
| `Start_*`      | "Start with" constraints | `Start_Letter` |
| `End_*`        | "End with" constraints | `End_Alphanumeric` |
| `Cant_*`       | "Can't" restrictions (start/end/consecutive/exclusion) | `Cant_StartOrEndHyphen` |
| `FixedValue`   | "Must be X" patterns | `FixedValue` |
| `EnumValue`    | "Use one of:" patterns | `EnumValue` |
| `FixedFormat_*` | "Should always be" / "Must be in format:" | `FixedFormat_ShouldAlwaysBe` |
| `Special_*`    | Complex patterns that don't fit other categories | `Special_SolutionPattern` |
| `Note`         | Informational blocks to skip | `Note` |

---

## The Action Scriptblock

### Signature

Every Action scriptblock receives **3 positional arguments**:

```powershell
Action = {
    param($m, $state, $block)
    # ...
}
```

You can omit `$block` if you don't need it — PowerShell ignores extra positional args:

```powershell
Action = {
    param($m, $state)
    # ...
}
```

### Parameter reference

| Parameter | Type | Description |
|-----------|------|-------------|
| `$m` | `[System.Text.RegularExpressions.Match]` | The regex match object from `[regex]::Match($sentence, $rule.Pattern)`. Use `$m.Groups[1].Value` etc. to access capture groups defined in your `Pattern`. |
| `$state` | `[ordered] hashtable` | The shared mutable state that accumulates across all rules for the current validChars string. This is where you write your results. |
| `$block` | `[string]` | The full original sentence text (the same string that `Pattern` was matched against). Useful when you need to inspect text beyond what `$m` captured, or when the pattern only matches a prefix. |

### When to use each parameter

**`$m` — the match object:**

Use `$m` when your `Pattern` contains capture groups and you need the captured values:

```powershell
# Pattern: "(?i)^must be\s+(.+)"
#                           ^^^^ capture group 1
Action = {
    param($m, $state)
    $value = $m.Groups[1].Value.Trim().TrimEnd('.')
    $state.FixedValue = "^$([regex]::Escape($value))`$"
}
```

Common `$m` properties:
- `$m.Value` — the full matched text
- `$m.Groups[0].Value` — same as `$m.Value`
- `$m.Groups[1].Value` — first capture group
- `$m.Groups[N].Value` — Nth capture group
- `$m.Success` — always `$true` inside an Action (the orchestrator already checked this)

**`$state` — the shared state hashtable:**

This is the **main output channel** — you modify `$state` to influence the final regex. See [State Reference](#state-reference) below.

**`$block` — the raw sentence text:**

Use `$block` when the `Pattern` only matches a prefix but you need to inspect the full text:

```powershell
# Pattern matches "alphanumerics, ..." but we need to scan for individual tokens
Action = {
    param($m, $state, $block)
    $text = if ($block) { $block } else { $m.Value }
    if ($text -match '(?i)hyphens?') { $chars += '\-' }
    if ($text -match '(?i)periods?') { $chars += '.' }
    # ...
}
```

> **Defensive pattern:** Always use `$text = if ($block) { $block } else { $m.Value }` when relying on `$block`. This guards against edge cases where `$block` might be `$null`.

---

## State Reference

The `$state` hashtable is initialized fresh for each call to `Convert-ConstraintToRegex`. Every key has a specific purpose in the final regex assembly.

### State keys

| Key | Type | Default | Effect on final regex | Example |
|-----|------|---------|----------------------|---------|
| `AllowedChars` | `List[string]` | `@()` | Joined and wrapped in `[...]` to form the character class. Each entry is a regex fragment like `a-zA-Z0-9` or `\-_.` | `$state.AllowedChars.Add('a-zA-Z0-9\-')` |
| `StartChars` | `string` or `$null` | `$null` | If set, the first character must match this class. Value should include brackets: `[a-zA-Z]` | `$state.StartChars = '[a-zA-Z]'` |
| `EndChars` | `string` or `$null` | `$null` | If set, the last character must match this class. Value should include brackets: `[a-zA-Z0-9]` | `$state.EndChars = '[a-zA-Z0-9]'` |
| `CantStartWith` | `List[string]` | `@()` | Converted to a negative lookahead `(?![chars])` at start. Only used when `StartChars` is not set. | `$state.CantStartWith.Add('_')` |
| `CantEndWith` | `List[string]` | `@()` | Converted to a negative lookbehind `(?<![chars])` at end. Only used when `EndChars` is not set. | `$state.CantEndWith.Add('.')` |
| `Lookaheads` | `List[string]` | `@()` | Zero-width assertions inserted after `^`. Use for "can't contain consecutive" or "can't be all numbers" rules. | `$state.Lookaheads.Add('(?!.*--)')` |
| `Lookbehinds` | `List[string]` | `@()` | Available for custom lookbehinds (not currently used by assembly, but could be extended). | — |
| `FixedValue` | `string` or `$null` | `$null` | If set, **short-circuits** regex assembly — this value is returned directly. Use for "Must be X", enum, and GUID patterns. | `$state.FixedValue = '^default$'` |
| `IsExclusion` | `bool` | `$false` | If `$true`, regex assembly uses `[^ExcludedChars]` (negated class) instead of `[AllowedChars]`. | `$state.IsExclusion = $true` |
| `ExcludedChars` | `string` or `$null` | `$null` | The characters to exclude (used with `IsExclusion`). Already escaped for use inside `[^...]`. | `$state.ExcludedChars = '<>*%&'` |
| `MatchAll` | `bool` | `$false` | If `$true`, character class becomes `.` (any character). | `$state.MatchAll = $true` |
| `Notes` | `List[string]` | `@()` | Informational text that doesn't affect the regex. | `$state.Notes.Add('No underscores allowed')` |

### How state maps to the final regex

The regex assembler builds patterns in this format:

```
^{lookaheads}{startChars}{charClass}{min,max}{endChars}{lookbehind}$
```

Depending on which state keys are set:

| Scenario | Resulting pattern |
|----------|-------------------|
| No start/end | `^{lookaheads}[charClass]{min,max}{lookbehind}$` |
| Start only | `^{lookaheads}[start][charClass]{min-1,max-1}{lookbehind}$` |
| End only | `^{lookaheads}[charClass]{min-1,max-1}[end]$` |
| Both start+end | `^{lookaheads}[start]([charClass]{0,max-2}[end])?$` (when min≤1) |
| FixedValue set | Returns `$state.FixedValue` directly (no assembly) |
| IsExclusion | Uses `[^excludedChars]` instead of `[allowedChars]` |

---

## Step-by-Step: Adding a New Rule

### 1. Identify the unhandled pattern

Run the test script and look for unhandled or incorrect output:

```powershell
pwsh -File src/scripts/%Test-ValidChars.ps1
```

Or test a single validChars string:

```powershell
. src/modules/Az.Naming.Config/Source/Functions/Convert-ConstraintToRegex.ps1

[ordered]@{
    validChars = 'Your new pattern text here'
    minLength  = 1
    maxLength  = 50
} | Convert-ConstraintToRegex
```

### 2. Determine the category

Decide which state keys your rule needs to modify:

- Adding characters? → `CharClass_*`, modify `$state.AllowedChars`
- Start constraint? → `Start_*`, set `$state.StartChars`
- End constraint? → `End_*`, set `$state.EndChars`
- "Can't" restriction? → `Cant_*`, modify appropriate state keys
- Fixed value? → `FixedValue`, set `$state.FixedValue`
- Informational? → `Note`, add to `$state.Notes`

### 3. Write the rule

Open `Convert-ConstraintToRegex.ps1`, find `New-ConstraintRuleRegistry`, and add your rule **in the correct position** (specific before general):

```powershell
[ordered]@{
    Name    = 'CharClass_MyNewPattern'
    Pattern = '(?i)^my specific pattern text'
    Action  = {
        param($m, $state)
        $state.AllowedChars.Add('a-z0-9\-')
    }
},
```

### 4. Test it

```powershell
# Quick single-value test
. src/modules/Az.Naming.Config/Source/Functions/Convert-ConstraintToRegex.ps1
[ordered]@{ validChars = 'My specific pattern text'; minLength = 1; maxLength = 50 } | Convert-ConstraintToRegex

# Full regression test
pwsh -File src/scripts/%Test-ValidChars.ps1
```

---

## Examples

### Example 1: Simple character class rule

A new Azure resource has validChars `"Lowercase letters, numbers, and dots"`. This isn't currently matched.

```powershell
# Place BEFORE the broad CharClass_AlphanumericCombo catch-all
[ordered]@{
    Name    = 'CharClass_LowercaseNumbersDots'
    Pattern = '(?i)^lowercase letters,?\s*numbers?,?\s*and\s+dots'
    Action  = {
        param($m, $state)
        $state.AllowedChars.Add('a-z0-9.')
    }
},
```

### Example 2: "Can't start/end" rule using the helper

A new constraint says `"Can't start or end with a dot"`. Use `Remove-CharFromAllowedChars` to derive start/end classes:

```powershell
[ordered]@{
    Name    = 'Cant_StartOrEndDot'
    Pattern = "(?i)can'?t\s+start\s+or\s+end\s+with\s+(a\s+)?dot"
    Action  = {
        param($m, $state)
        $noDot = Remove-CharFromAllowedChars `
            -AllowedChars $state.AllowedChars `
            -CharsToRemove @('.')
        if ($noDot.Length -gt 0) {
            if (-not $state.StartChars) { $state.StartChars = "[$noDot]" }
            if (-not $state.EndChars)   { $state.EndChars   = "[$noDot]" }
        } else {
            $state.CantStartWith.Add('\.')
            $state.CantEndWith.Add('\.')
        }
    }
},
```

> **Why two branches?** If `AllowedChars` has been populated (by a prior block like "Alphanumerics and periods"), we can derive the start/end class by subtraction. If no `AllowedChars` exist yet (exclusion-based pattern), we fall back to `CantStartWith`/`CantEndWith` which become lookaheads/lookbehinds.

### Example 3: Fixed value / enum rule

A new resource says `"Must be 'production' or 'staging'"`:

```powershell
[ordered]@{
    Name    = 'FixedValue_ProductionOrStaging'
    Pattern = "(?i)^must be\s+'production'\s+or\s+'staging'"
    Action  = {
        param($m, $state)
        $state.FixedValue = '^(production|staging)$'
    }
},
```

### Example 4: Rule that uses $block for full-text inspection

When the `Pattern` only anchors on a prefix but you need tokens from the full sentence:

```powershell
[ordered]@{
    Name    = 'CharClass_CustomCombo'
    Pattern = '(?i)^allowed characters include'
    Action  = {
        param($m, $state, $block)
        $text = if ($block) { $block } else { $m.Value }
        $chars = ''
        if ($text -match '(?i)letters')     { $chars += 'a-zA-Z' }
        if ($text -match '(?i)digits')      { $chars += '0-9' }
        if ($text -match '(?i)hyphens?')    { $chars += '\-' }
        if ($text -match '(?i)underscores?') { $chars += '_' }
        if ($chars) { $state.AllowedChars.Add($chars) }
    }
},
```

### Example 5: Lookahead constraint

A new constraint says `"Can't contain three consecutive dots"`:

```powershell
[ordered]@{
    Name    = 'Cant_ConsecutiveDots'
    Pattern = "(?i)can'?t\s+(contain|use)\s+three\s+consecutive\s+dots"
    Action  = {
        param($m, $state)
        $state.Lookaheads.Add('(?!.*\.\.\.)')
    }
},
```

---

## Helper Function: Remove-CharFromAllowedChars

When writing "Can't start/end with X" rules, **do not** naively do `$joined -replace '-', ''` — this destroys regex ranges like `a-z`. Use the helper instead:

```powershell
$cleaned = Remove-CharFromAllowedChars `
    -AllowedChars $state.AllowedChars `
    -CharsToRemove @('-', '.')
```

Supported characters: `-`, `.`, `_`, ` ` (space), and any other literal character (auto-escaped).

---

## Gotchas

1. **Rule order matters.** Specific patterns must come before catch-all patterns. If your new rule is a subset of an existing broad pattern, place it above.

2. **Regex in Pattern is matched with `[regex]::Match()`.** This is a .NET regex, not PowerShell's `-match`. Escaping rules differ slightly.

3. **`$state.StartChars` and `$state.EndChars` include brackets.** Set them as `'[a-zA-Z]'`, not just `'a-zA-Z'`.

4. **`FixedValue` short-circuits.** If any rule sets `$state.FixedValue`, the regex assembly is skipped entirely and that value is returned as-is. Don't combine it with character class rules.

5. **Blocks vs sentences.** The orchestrator first splits on `<br><br>` into blocks, then splits each block into sentences on `". "` and `"; "`. Your rule's `Pattern` is matched against individual **sentences**, not the full validChars string.

6. **Case sensitivity.** Always use `(?i)` in your `Pattern` unless you specifically need case-sensitive matching.

7. **Lowercase context detection.** Many Start/End rules check whether `AllowedChars` contains only lowercase ranges to decide between `[a-z]` and `[a-zA-Z]`. This is done via:
   ```powershell
   $hasLowerOnly = $state.AllowedChars -join '' -match '^[^A-Z]*$' `
       -and ($state.AllowedChars -join '' -match 'a-z')
   ```
   If your char class rule adds uppercase ranges (`A-Z`), downstream Start/End rules will automatically use full-alpha patterns.

8. **Registry caching.** The rule registry is built once and cached at `$script:ConstraintRuleRegistry`. If you modify `New-ConstraintRuleRegistry` during a session, call `Reset-ConstraintRuleRegistry` to force a rebuild before testing your changes.
