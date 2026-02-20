#region Block Splitter

function Remove-CharFromAllowedChars {
    <#
    .SYNOPSIS
        Removes specific characters from an AllowedChars list without breaking regex ranges.
    .DESCRIPTION
        Processes each AllowedChars entry individually, removing only standalone
        escaped characters (e.g. \\-, \\., _) while preserving range expressions
        like a-z, A-Z, 0-9.
    .PARAMETER AllowedChars
        The list of allowed character class fragments.
    .PARAMETER CharsToRemove
        Array of characters to remove. Each can be a literal char or escaped form.
    .OUTPUTS
        [string] The cleaned and joined character class string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [System.Collections.Generic.List[string]] $AllowedChars,
        [string[]] $CharsToRemove
    )

    $joined = ($AllowedChars | Select-Object -Unique) -join ''

    foreach ($c in $CharsToRemove) {
        switch ($c) {
            '-' {
                # Remove only escaped hyphens (\-) and trailing/leading bare hyphens,
                # but NOT hyphens that are part of ranges like a-z, A-Z, 0-9
                $joined = $joined -replace '\\-', ''
                # Remove bare hyphen only if at start or end of the string (not in a range)
                $joined = $joined -replace '(?<![a-zA-Z0-9])-(?![a-zA-Z0-9])', ''
                # Also remove trailing hyphen
                $joined = $joined -replace '-$', ''
            }
            '.' {
                $joined = $joined -replace '\.', ''
            }
            ' ' {
                $joined = $joined -replace ' ', ''
            }
            '_' {
                $joined = $joined -replace '_', ''
            }
            default {
                $joined = $joined -replace [regex]::Escape($c), ''
            }
        }
    }

    return $joined
}

function Split-ConstraintBlocks {
    <#
    .SYNOPSIS
        Splits a raw validChars string into clean constraint blocks.
    .DESCRIPTION
        Blocks are separated by <br><br> (with optional whitespace).
        Within a block, <br> and <br/> act as sentence separators (replaced with spaces).
        All HTML tags, HTML entities, and markdown formatting are stripped.
        Whitespace is normalized and each block is trimmed.
    .PARAMETER InputString
        The raw validChars description string.
    .OUTPUTS
        [string[]] Array of clean text blocks.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $InputString
    )

    # Split on <br><br> (block separator), allowing optional whitespace around it
    $rawBlocks = $InputString -split `
        '\s*<br\s*/?>\s*<br\s*/?>\s*'

    $cleanBlocks = @()

    foreach ($raw in $rawBlocks) {
        if ([string]::IsNullOrWhiteSpace($raw)) {
            continue
        }

        $block = $raw

        # Replace remaining <br> / <br/> with space (sentence separators within a block)
        $block = $block -replace '<br\s*/?>', ' '

        # Strip HTML entities: &nbsp; &quot; &apos; &amp; &lt; &gt; &#NNN; &#xHHH;
        $block = $block `
            -replace '&nbsp;', ' ' `
            -replace '&quot;', '"' `
            -replace '&apos;', "'" `
            -replace '&amp;', '&' `
            -replace '&lt;', '<' `
            -replace '&gt;', '>' `
            -replace '&#x?[0-9a-fA-F]+;', ''

        # Strip any remaining HTML tags (e.g. <code>, <a href>, etc.)
        $block = $block -replace '<[^>]+>', ''

        # Strip markdown bold: **text** → text
        $block = $block -replace '\*\*([^*]+)\*\*', '$1'

        # Strip markdown inline code: `text` → text
        $block = $block -replace '`([^`]*)`', '$1'

        # Strip markdown links: [text](url) → text
        $block = $block -replace '\[([^\]]+)\]\([^)]+\)', '$1'

        # Normalize whitespace (collapse multiple spaces/tabs/newlines to single space)
        $block = ($block -replace '\s+', ' ').Trim()

        if ($block.Length -gt 0) {
            $cleanBlocks += $block
        }
    }

    return $cleanBlocks
}

#endregion Block Splitter

#region Rule Registry

function New-ConstraintRuleRegistry {
    <#
    .SYNOPSIS
        Creates the rule registry — an ordered array of rules for matching constraint blocks.
    .DESCRIPTION
        Each rule is an [ordered]@{ Name; Pattern; Action } hashtable.
        Pattern is a regex matched against each clean block.
        Action is a scriptblock receiving ($match, $state).
        Rules are evaluated in order; first match wins per block.
    .OUTPUTS
        [hashtable[]] Array of rule definitions.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param()

    $rules = @(

        #----------------------------------------------------------------------
        # CharClass rules — detect allowed character classes
        #----------------------------------------------------------------------

        [ordered]@{
            Name    = 'CharClass_AllChars'
            Pattern = '^All characters$'
            Action  = {
                param($m, $state)
                $state.AllowedChars.Add('.')
                $state.MatchAll = $true
            }
        },

        [ordered]@{
            Name    = 'CharClass_AlphanumericsOnly'
            Pattern = '^Only alphanumerics are valid\.?$'
            Action  = {
                param($m, $state)
                $state.AllowedChars.Add('a-zA-Z0-9')
            }
        },

        [ordered]@{
            Name    = 'CharClass_DatastoreLowerDigitUnderscore'
            Pattern = '(?i)datastore name consists only of lowercase letters,?\s*digits,?\s*and underscores'
            Action  = {
                param($m, $state)
                $state.AllowedChars.Add('a-z0-9_')
            }
        },

        [ordered]@{
            Name    = 'CharClass_LowercaseLettersNumbersHyphensUnderscores'
            Pattern = '(?i)^lowercase letters,?\s*numbers?,?\s*hyphens?,?\s*and underscores?'
            Action  = {
                param($m, $state)
                $state.AllowedChars.Add('a-z0-9\-_')
            }
        },

        [ordered]@{
            Name    = 'CharClass_LowercaseLettersHyphensNumbers'
            Pattern = '(?i)^lowercase letters,?\s*hyphens?,?\s*and numbers?'
            Action  = {
                param($m, $state)
                $state.AllowedChars.Add('a-z0-9\-')
            }
        },

        [ordered]@{
            Name    = 'CharClass_LowercaseNumbersHyphens'
            Pattern = '(?i)^n?lowercase letters,?\s*numbers?,?\s*and hyphens?'
            Action  = {
                param($m, $state)
                $state.AllowedChars.Add('a-z0-9\-')
            }
        },

        [ordered]@{
            Name    = 'CharClass_LowercaseNumbersHyphens2'
            Pattern = '(?i)^lowercase letters,?\s*numbers?,?\s*or hyphens?'
            Action  = {
                param($m, $state)
                $state.AllowedChars.Add('a-z0-9\-')
            }
        },

        [ordered]@{
            Name    = 'CharClass_LowercaseAndNumbers'
            Pattern = '(?i)^lowercase letters (and|or) numbers'
            Action  = {
                param($m, $state)
                $state.AllowedChars.Add('a-z0-9')
            }
        },

        [ordered]@{
            Name    = 'CharClass_LettersAndNumbers'
            Pattern = '(?i)^letters and numbers'
            Action  = {
                param($m, $state)
                $state.AllowedChars.Add('a-zA-Z0-9')
            }
        },


        [ordered]@{
            Name    = 'CharClass_NumbersAndPeriods'
            Pattern = '(?i)^numbers and periods'
            Action  = {
                param($m, $state)
                $state.AllowedChars.Add('0-9.')
            }
        },

        [ordered]@{
            Name    = 'CharClass_AlphanumericHyphens'
            Pattern = '(?i)^alphanumerics?\s+and\s+hyphens'
            Action  = {
                param($m, $state)
                $state.AllowedChars.Add('a-zA-Z0-9\-')
            }
        },

        [ordered]@{
            Name    = 'CharClass_AlphanumericPeriods'
            Pattern = '(?i)^alphanumerics?\s+and\s+periods'
            Action  = {
                param($m, $state)
                $state.AllowedChars.Add('a-zA-Z0-9.')
            }
        },

        [ordered]@{
            Name    = 'CharClass_AlphanumericUnderscores'
            Pattern = '(?i)^alphanumerics?\s+and\s+underscores'
            Action  = {
                param($m, $state)
                $state.AllowedChars.Add('a-zA-Z0-9_')
            }
        },

        [ordered]@{
            Name    = 'CharClass_Alphanumerics'
            Pattern = '(?i)^alphanumerics?$'
            Action  = {
                param($m, $state)
                $state.AllowedChars.Add('a-zA-Z0-9')
            }
        },

        # Broad catch-all — must come AFTER specific Alphanumeric+X rules
        [ordered]@{
            Name    = 'CharClass_AlphanumericCombo'
            Pattern = '(?i)^alphanumerics?,?\s*(hyphens?|periods?|underscores?|slashes?|spaces?|parentheses?|,|\s|and)+'
            Action  = {
                param($m, $state, $block)
                $text = if ($block) { $block } else { $m.Value }
                # Start with alphanumerics, then add tokens found in the text
                $chars = 'a-zA-Z0-9'
                if ($text -match '(?i)hyphens?')      { $chars += '\-' }
                if ($text -match '(?i)periods?')      { $chars += '.' }
                if ($text -match '(?i)underscores?')  { $chars += '_' }
                if ($text -match '(?i)slashes?')      { $chars += '/' }
                if ($text -match '(?i)spaces?')       { $chars += ' ' }
                if ($text -match '(?i)parentheses?')  { $chars += '()' }
                $state.AllowedChars.Add($chars)
            }
        },

        [ordered]@{
            Name    = 'CharClass_AlphanumericUnicodePunycode'
            Pattern = '(?i)alphanumeric.*unicode.*punycode'
            Action  = {
                param($m, $state)
                # Unicode/Punycode domains use alphanumerics and hyphens
                $state.AllowedChars.Add('a-zA-Z0-9\-')
            }
        },

        [ordered]@{
            Name    = 'CharClass_UnderscoresHyphensPeriodsParenthesesLettersDigits'
            Pattern = '(?i)^underscores,?\s*hyphens,?\s*periods,?\s*parentheses,?\s*and\s+letters\s+or\s+digits'
            Action  = {
                param($m, $state)
                $state.AllowedChars.Add('a-zA-Z0-9_\-.()') 
            }
        },

        [ordered]@{
            Name    = 'CharClass_DnsLabels'
            Pattern = '(?i)each label can contain alphanumerics'
            Action  = {
                param($m, $state)
                # DNS labels: alphanumerics, underscores, hyphens, separated by periods
                $state.AllowedChars.Add('a-zA-Z0-9_\-.')
            }
        },

        [ordered]@{
            Name    = 'CharClass_UrlChars'
            Pattern = '(?i)any URL characters'
            Action  = {
                param($m, $state)
                # Broad URL-safe character set
                $state.AllowedChars.Add('a-zA-Z0-9\-._~:/?#@!$&()*+,;=%')
            }
        },

        [ordered]@{
            Name    = 'CharClass_AnyCharsDisplayName'
            Pattern = '(?i)display name can contain any characters'
            Action  = {
                param($m, $state)
                $state.AllowedChars.Add('.')
                $state.MatchAll = $true
            }
        },

        #----------------------------------------------------------------------
        # Start constraints
        #----------------------------------------------------------------------

        [ordered]@{
            Name    = 'Start_Letter'
            Pattern = '(?i)^start with\s+(a\s+)?letter(?!\s+or)(?!.*end\s+with)'
            Action  = {
                param($m, $state)
                # Use lowercase-only if context suggests it, otherwise full alpha
                $hasLowerOnly = $state.AllowedChars -join '' -match '^[^A-Z]*$' -and ($state.AllowedChars -join '' -match 'a-z')
                if ($hasLowerOnly) {
                    $state.StartChars = '[a-z]'
                } else {
                    $state.StartChars = '[a-zA-Z]'
                }
            }
        },

        [ordered]@{
            Name    = 'Start_LowercaseLetter'
            Pattern = '(?i)^start with\s+(a\s+)?lowercase letter(?!\s+or)'
            Action  = {
                param($m, $state)
                $state.StartChars = '[a-z]'
            }
        },

        [ordered]@{
            Name    = 'Start_LowercaseLetterOrNumber'
            Pattern = '(?i)^start with\s+(a\s+)?lowercase letter or number'
            Action  = {
                param($m, $state)
                $state.StartChars = '[a-z0-9]'
            }
        },

        [ordered]@{
            Name    = 'Start_Alphanumeric'
            Pattern = '(?i)^start\s+(with\s+)?(a\s+)?alphanumeric(?!.*end\s+)'
            Action  = {
                param($m, $state)
                $hasLowerOnly = $state.AllowedChars -join '' -match '^[^A-Z]*$' -and ($state.AllowedChars -join '' -match 'a-z')
                if ($hasLowerOnly) {
                    $state.StartChars = '[a-z0-9]'
                } else {
                    $state.StartChars = '[a-zA-Z0-9]'
                }
            }
        },

        [ordered]@{
            Name    = 'Start_LetterOrNumber'
            Pattern = '(?i)^start with\s+(a\s+)?letter or (a\s+)?number'
            Action  = {
                param($m, $state)
                $hasLowerOnly = $state.AllowedChars -join '' -match '^[^A-Z]*$' -and ($state.AllowedChars -join '' -match 'a-z')
                if ($hasLowerOnly) {
                    $state.StartChars = '[a-z0-9]'
                } else {
                    $state.StartChars = '[a-zA-Z0-9]'
                }
            }
        },

        [ordered]@{
            Name    = 'Start_AndEnd_Alphanumeric'
            Pattern = '(?i)^start and end with\s+alphanumeric(?!\s+or)'
            Action  = {
                param($m, $state)
                $hasLowerOnly = $state.AllowedChars -join '' -match '^[^A-Z]*$' -and ($state.AllowedChars -join '' -match 'a-z')
                if ($hasLowerOnly) {
                    $state.StartChars = '[a-z0-9]'
                    $state.EndChars   = '[a-z0-9]'
                } else {
                    $state.StartChars = '[a-zA-Z0-9]'
                    $state.EndChars   = '[a-zA-Z0-9]'
                }
            }
        },

        [ordered]@{
            Name    = 'Start_AndEnd_AlphanumericTypo'
            Pattern = '(?i)^start and end with\s+alphnumeric'
            Action  = {
                param($m, $state)
                $hasLowerOnly = $state.AllowedChars -join '' -match '^[^A-Z]*$' -and ($state.AllowedChars -join '' -match 'a-z')
                if ($hasLowerOnly) {
                    $state.StartChars = '[a-z0-9]'
                    $state.EndChars   = '[a-z0-9]'
                } else {
                    $state.StartChars = '[a-zA-Z0-9]'
                    $state.EndChars   = '[a-zA-Z0-9]'
                }
            }
        },

        [ordered]@{
            Name    = 'Start_AndEnd_LetterOrNumber'
            Pattern = '(?i)^start and end with\s+letter or number'
            Action  = {
                param($m, $state)
                $hasLowerOnly = $state.AllowedChars -join '' -match '^[^A-Z]*$' -and ($state.AllowedChars -join '' -match 'a-z')
                if ($hasLowerOnly) {
                    $state.StartChars = '[a-z0-9]'
                    $state.EndChars   = '[a-z0-9]'
                } else {
                    $state.StartChars = '[a-zA-Z0-9]'
                    $state.EndChars   = '[a-zA-Z0-9]'
                }
            }
        },

        [ordered]@{
            Name    = 'Start_AndEnd_AlphanumericOrUnderscore'
            Pattern = '(?i)^start and end with\s+alphanumeric or underscore'
            Action  = {
                param($m, $state)
                $state.StartChars = '[a-zA-Z0-9_]'
                $state.EndChars   = '[a-zA-Z0-9_]'
            }
        },

        [ordered]@{
            Name    = 'Start_WithLetterEnd'
            Pattern = '(?i)^start with\s+(a\s+)?letter.*end\s+with'
            Action  = {
                param($m, $state, $block)
                $text = if ($block) { $block } else { $m.Value }
                $hasLowerOnly = $state.AllowedChars -join '' -match '^[^A-Z]*$' -and ($state.AllowedChars -join '' -match 'a-z')
                if ($hasLowerOnly) {
                    $state.StartChars = '[a-z]'
                } else {
                    $state.StartChars = '[a-zA-Z]'
                }
                # Parse end constraint from same block
                if ($text -match '(?i)end\s+with\s+(a\s+)?(letter\s+or\s+number|alphanumeric)') {
                    if ($hasLowerOnly) {
                        $state.EndChars = '[a-z0-9]'
                    } else {
                        $state.EndChars = '[a-zA-Z0-9]'
                    }
                }
            }
        },

        [ordered]@{
            Name    = 'Start_AlphanumericEnd'
            Pattern = '(?i)^start\s+(with\s+)?(a\s+)?alphanumeric.*end\s+'
            Action  = {
                param($m, $state, $block)
                $text = if ($block) { $block } else { $m.Value }
                $hasLowerOnly = $state.AllowedChars -join '' -match '^[^A-Z]*$' -and ($state.AllowedChars -join '' -match 'a-z')
                if ($hasLowerOnly) {
                    $state.StartChars = '[a-z0-9]'
                } else {
                    $state.StartChars = '[a-zA-Z0-9]'
                }
                # Parse end constraint
                if ($text -match '(?i)end\s+(with\s+)?(a\s+)?alphanumeric\s+or\s+underscore') {
                    $state.EndChars = '[a-zA-Z0-9_]'
                } elseif ($text -match '(?i)end\s+(with\s+)?(a\s+)?alphanumeric') {
                    if ($hasLowerOnly) {
                        $state.EndChars = '[a-z0-9]'
                    } else {
                        $state.EndChars = '[a-zA-Z0-9]'
                    }
                } elseif ($text -match '(?i)end\s+(with\s+)?letter,?\s*number,?\s*or\s+underscore') {
                    $state.EndChars = '[a-zA-Z0-9_]'
                }
            }
        },

        [ordered]@{
            Name    = 'Start_MustBeginEnd'
            Pattern = '(?i)^must begin and end with\s+(a\s+)?letter or number'
            Action  = {
                param($m, $state)
                $hasLowerOnly = $state.AllowedChars -join '' -match '^[^A-Z]*$' -and ($state.AllowedChars -join '' -match 'a-z')
                if ($hasLowerOnly) {
                    $state.StartChars = '[a-z0-9]'
                    $state.EndChars   = '[a-z0-9]'
                } else {
                    $state.StartChars = '[a-zA-Z0-9]'
                    $state.EndChars   = '[a-zA-Z0-9]'
                }
            }
        },

        #----------------------------------------------------------------------
        # End constraints
        #----------------------------------------------------------------------

        [ordered]@{
            Name    = 'End_Alphanumeric'
            Pattern = '(?i)^end with\s+(a\s+)?alphanumeric(?!\s+or)'
            Action  = {
                param($m, $state)
                $hasLowerOnly = $state.AllowedChars -join '' -match '^[^A-Z]*$' -and ($state.AllowedChars -join '' -match 'a-z')
                if ($hasLowerOnly) {
                    $state.EndChars = '[a-z0-9]'
                } else {
                    $state.EndChars = '[a-zA-Z0-9]'
                }
            }
        },

        [ordered]@{
            Name    = 'End_LetterOrNumber'
            Pattern = '(?i)^end with\s+(a\s+)?letter or (a\s+)?number'
            Action  = {
                param($m, $state)
                $hasLowerOnly = $state.AllowedChars -join '' -match '^[^A-Z]*$' -and ($state.AllowedChars -join '' -match 'a-z')
                if ($hasLowerOnly) {
                    $state.EndChars = '[a-z0-9]'
                } else {
                    $state.EndChars = '[a-zA-Z0-9]'
                }
            }
        },

        [ordered]@{
            Name    = 'End_LowercaseLetterOrNumber'
            Pattern = '(?i)^end with\s+(a\s+)?lowercase letter or number'
            Action  = {
                param($m, $state)
                $state.EndChars = '[a-z0-9]'
            }
        },

        [ordered]@{
            Name    = 'End_AlphanumericOrUnderscore'
            Pattern = '(?i)^end\s+(with\s+)?(a\s+)?alphanumeric or\s+underscore'
            Action  = {
                param($m, $state)
                $state.EndChars = '[a-zA-Z0-9_]'
            }
        },

        [ordered]@{
            Name    = 'End_LetterNumberUnderscore'
            Pattern = '(?i)^end\s+(with\s+)?letter,?\s*number,?\s*or\s+underscore'
            Action  = {
                param($m, $state)
                $state.EndChars = '[a-zA-Z0-9_]'
            }
        },

        #----------------------------------------------------------------------
        # Cant constraints — "Can't" restrictions
        #----------------------------------------------------------------------

        [ordered]@{
            Name    = 'Cant_StartOrEndHyphen'
            Pattern = "(?i)can'?t\s+start\s+(with\s+)?or\s+end\s+with\s+(a\s+)?hyphens?"
            Action  = {
                param($m, $state)
                # Derive from AllowedChars minus hyphen
                $noHyphen = Remove-CharFromAllowedChars `
                    -AllowedChars $state.AllowedChars `
                    -CharsToRemove @('-')
                if ($noHyphen.Length -gt 0) {
                    if (-not $state.StartChars) { $state.StartChars = "[$noHyphen]" }
                    if (-not $state.EndChars)   { $state.EndChars   = "[$noHyphen]" }
                } else {
                    $state.CantStartWith.Add('\\-')
                    $state.CantEndWith.Add('\\-')
                }
            }
        },

        [ordered]@{
            Name    = 'Cant_StartOrEndHyphens2'
            Pattern = "(?i)can'?t\s+start\s+or\s+end\s+with\s+hyphens"
            Action  = {
                param($m, $state)
                $noHyphen = Remove-CharFromAllowedChars `
                    -AllowedChars $state.AllowedChars `
                    -CharsToRemove @('-')
                if ($noHyphen.Length -gt 0) {
                    if (-not $state.StartChars) { $state.StartChars = "[$noHyphen]" }
                    if (-not $state.EndChars)   { $state.EndChars   = "[$noHyphen]" }
                } else {
                    $state.CantStartWith.Add('\\-')
                    $state.CantEndWith.Add('\\-')
                }
            }
        },

        [ordered]@{
            Name    = 'Cant_StartHyphen'
            Pattern = "(?i)can'?t\s+start\s+with\s+(a\s+)?hyphen"
            Action  = {
                param($m, $state)
                $noHyphen = Remove-CharFromAllowedChars `
                    -AllowedChars $state.AllowedChars `
                    -CharsToRemove @('-')
                if ($noHyphen.Length -gt 0 -and -not $state.StartChars) {
                    $state.StartChars = "[$noHyphen]"
                } elseif ($state.AllowedChars.Count -eq 0) {
                    $state.CantStartWith.Add('\\-')
                }
            }
        },

        [ordered]@{
            Name    = 'Cant_EndHyphen'
            Pattern = "(?i)can'?t\s+end\s+with\s+(a\s+)?hyphen"
            Action  = {
                param($m, $state)
                $noHyphen = Remove-CharFromAllowedChars `
                    -AllowedChars $state.AllowedChars `
                    -CharsToRemove @('-')
                if ($noHyphen.Length -gt 0 -and -not $state.EndChars) {
                    $state.EndChars = "[$noHyphen]"
                } elseif ($state.AllowedChars.Count -eq 0) {
                    $state.CantEndWith.Add('\\-')
                }
            }
        },

        [ordered]@{
            Name    = 'Cant_EndPeriod'
            Pattern = "(?i)can'?t\s+end\s+(with\s+|in\s+)(a\s+)?period(?!\s+or)"
            Action  = {
                param($m, $state)
                $joined = ($state.AllowedChars | Select-Object -Unique) -join ''
                if ($joined.Length -gt 0) {
                    $noPeriod = $joined -replace '\.', ''
                    if ($noPeriod.Length -gt 0 -and -not $state.EndChars) {
                        $state.EndChars = "[$noPeriod]"
                    }
                } else {
                    $state.CantEndWith.Add('.')
                }
            }
        },

        [ordered]@{
            Name    = 'Cant_EndPeriodOrSpace'
            Pattern = "(?i)can'?t\s+end\s+with\s+(a\s+)?(period|\.?)\s+or\s+space"
            Action  = {
                param($m, $state)
                $joined = ($state.AllowedChars | Select-Object -Unique) -join ''
                if ($joined.Length -gt 0) {
                    $cleaned = $joined -replace '\.', '' -replace ' ', ''
                    if ($cleaned.Length -gt 0 -and -not $state.EndChars) {
                        $state.EndChars = "[$cleaned]"
                    }
                } else {
                    $state.CantEndWith.Add('.')
                    $state.CantEndWith.Add(' ')
                }
            }
        },

        [ordered]@{
            Name    = 'Cant_EndSpaceOrPeriod'
            Pattern = "(?i)can'?t\s+end\s+with\s+(a\s+)?space\s+or\s+(period|\.?)"
            Action  = {
                param($m, $state)
                $joined = ($state.AllowedChars | Select-Object -Unique) -join ''
                if ($joined.Length -gt 0) {
                    $cleaned = $joined -replace '\.', '' -replace ' ', ''
                    if ($cleaned.Length -gt 0 -and -not $state.EndChars) {
                        $state.EndChars = "[$cleaned]"
                    }
                } else {
                    $state.CantEndWith.Add(' ')
                    $state.CantEndWith.Add('.')
                }
            }
        },

        [ordered]@{
            Name    = 'Cant_EndSpace'
            Pattern = "(?i)can'?t\s+end\s+with\s+(a\s+)?space"
            Action  = {
                param($m, $state)
                $joined = ($state.AllowedChars | Select-Object -Unique) -join ''
                if ($joined.Length -gt 0) {
                    $cleaned = $joined -replace ' ', ''
                    if ($cleaned.Length -gt 0 -and -not $state.EndChars) {
                        $state.EndChars = "[$cleaned]"
                    }
                } else {
                    $state.CantEndWith.Add(' ')
                }
            }
        },

        [ordered]@{
            Name    = 'Cant_EndPeriodOrHyphen'
            Pattern = "(?i)can'?t\s+end\s+with\s+(a\s+)?period\s+or\s+hyphen"
            Action  = {
                param($m, $state)
                $cleaned = Remove-CharFromAllowedChars `
                    -AllowedChars $state.AllowedChars `
                    -CharsToRemove @('.', '-')
                if ($cleaned.Length -gt 0 -and -not $state.EndChars) {
                    $state.EndChars = "[$cleaned]"
                } elseif ($state.AllowedChars.Count -eq 0) {
                    $state.CantEndWith.Add('.')
                    $state.CantEndWith.Add('\-')
                }
            }
        },

        [ordered]@{
            Name    = 'Cant_StartUnderscoreHyphenNumber'
            Pattern = "(?i)can'?t\s+start\s+with\s+underscore,?\s*hyphen,?\s*or\s+number"
            Action  = {
                param($m, $state)
                if (-not $state.StartChars) {
                    $state.StartChars = '[a-zA-Z]'
                }
            }
        },

        [ordered]@{
            Name    = 'Cant_StartUnderscore'
            Pattern = "(?i)can'?t\s+start\s+with\s+(a\s+)?underscore"
            Action  = {
                param($m, $state)
                if (-not $state.StartChars) {
                    $joined = ($state.AllowedChars | Select-Object -Unique) -join ''
                    if ($joined.Length -gt 0) {
                        $noUnderscore = $joined -replace '_', ''
                        if ($noUnderscore.Length -gt 0) {
                            $state.StartChars = "[$noUnderscore]"
                        }
                    } else {
                        $state.CantStartWith.Add('_')
                    }
                }
            }
        },

        [ordered]@{
            Name    = 'Cant_StartNumber'
            Pattern = "(?i)can'?t\s+start\s+with\s+(a\s+)?number"
            Action  = {
                param($m, $state)
                if (-not $state.StartChars) {
                    $state.StartChars = '[a-z]'
                }
            }
        },

        [ordered]@{
            Name    = 'Cant_EndUnderscoreOrHyphen'
            Pattern = "(?i)can'?t\s+end\s+with\s+(a\s+)?underscore\s+or\s+hyphen"
            Action  = {
                param($m, $state)
                $cleaned = Remove-CharFromAllowedChars `
                    -AllowedChars $state.AllowedChars `
                    -CharsToRemove @('_', '-')
                if ($cleaned.Length -gt 0 -and -not $state.EndChars) {
                    $state.EndChars = "[$cleaned]"
                } elseif ($state.AllowedChars.Count -eq 0) {
                    $state.CantEndWith.Add('_')
                    $state.CantEndWith.Add('\\-')
                }
            }
        },

        [ordered]@{
            Name    = 'Cant_ConsecutiveHyphens'
            Pattern = "(?i)can'?t\s+(use|contain|have)\s+consecutive\s+hyphens|consecutive\s+hyphens\s+not\s+allowed|consecutive\s+hyphens\s+aren'?t\s+allowed"
            Action  = {
                param($m, $state)
                $state.Lookaheads.Add('(?!.*--)')
            }
        },

        [ordered]@{
            Name    = 'Cant_ConsecutiveHyphensMore'
            Pattern = "(?i)can'?t\s+contain\s+a\s+sequence\s+of\s+more\s+than\s+two\s+hyphens"
            Action  = {
                param($m, $state)
                $state.Lookaheads.Add('(?!.*---)')
            }
        },

        [ordered]@{
            Name    = 'Cant_HyphenPrecededFollowed'
            Pattern = '(?i)each\s+hyphen\s+(must\s+be\s+|and\s+underscore\s+must\s+be\s+)?preceded\s+and\s+followed\s+by'
            Action  = {
                param($m, $state)
                # Same effect as no consecutive hyphens
                $state.Lookaheads.Add('(?!.*--)')
            }
        },

        [ordered]@{
            Name    = 'Cant_BeAllNumbers'
            Pattern = "(?i)can'?t\s+be\s+all\s+numbers"
            Action  = {
                param($m, $state)
                $state.Lookaheads.Add('(?!^\d+$)')
            }
        },

        [ordered]@{
            Name    = 'Cant_BeNamed'
            Pattern = "(?i)can'?t\s+be\s+named\s+(.+)"
            Action  = {
                param($m, $state)
                $remainder = $m.Groups[1].Value.Trim().TrimEnd('.')
                # Extract backtick-delimited values, or split on "or" / ","
                $values = [regex]::Matches($remainder, '`([^`]+)`') |
                    ForEach-Object { $_.Groups[1].Value }
                if ($values.Count -eq 0) {
                    $values = $remainder -split '\s+or\s+|,\s*' |
                        ForEach-Object { $_.Trim().Trim("'", '"') } |
                        Where-Object { $_.Length -gt 0 }
                }
                foreach ($v in $values) {
                    $escaped = [regex]::Escape($v)
                    $state.Lookaheads.Add('(?!^' + $escaped + '$)')
                }
            }
        },

        [ordered]@{
            Name    = 'Cant_UseWords'
            Pattern = "(?i)(the\s+)?following\s+words\s+can'?t\s+be\s+used.*?:\s*(.+)"
            Action  = {
                param($m, $state)
                $remainder = $m.Groups[2].Value.Trim().TrimEnd('.')
                $values = [regex]::Matches($remainder, '`([^`]+)`') |
                    ForEach-Object { $_.Groups[1].Value }
                if ($values.Count -eq 0) {
                    $values = $remainder -split ',\s*|\s+or\s+' |
                        ForEach-Object { $_.Trim().Trim("'", '"') } |
                        Where-Object { $_.Length -gt 0 }
                }
                foreach ($v in $values) {
                    $escaped = [regex]::Escape($v)
                    $state.Lookaheads.Add('(?!^' + $escaped + '$)')
                }
            }
        },

        [ordered]@{
            Name    = 'Cant_ContainSubstring'
            Pattern = '(?i)can''?t\s+contain\s+`?([^\s`\.]+)`?\s*$'
            Action  = {
                param($m, $state)
                $value = $m.Groups[1].Value
                $escaped = [regex]::Escape($value)
                $state.Lookaheads.Add('(?!.*' + $escaped + ')')
            }
        },

        [ordered]@{
            Name    = 'Cant_UseExcluded'
            Pattern = "(?i)can'?t\s+use:\s*"
            Action  = {
                param($m, $state, $block)
                $text = if ($block) { $block } else { $m.Value }

                # Remove the "Can't use:" prefix
                $remainder = $text -replace "(?i)^.*?can'?t\s+use:\s*", ''

                # Check for "or control characters" / "or space" suffixes
                $hasControlChars = $false
                $hasSpace = $false

                if ($remainder -match '(?i)\s+or\s+control\s+characters?') {
                    $hasControlChars = $true
                    $remainder = $remainder -replace '(?i)\s+or\s+control\s+characters?.*$', ''
                }
                if ($remainder -match '(?i)\s+or\s+space') {
                    $hasSpace = $true
                    $remainder = $remainder -replace '(?i)\s+or\s+space.*$', ''
                }

                # Get the excluded characters string
                $chars = $remainder.Trim()

                # Build escaped character set for use in [^...] class
                $excludedChars = ''
                $uniqueChars = ($chars.ToCharArray() | Select-Object -Unique)

                foreach ($c in $uniqueChars) {
                    switch ($c) {
                        ']'  { $excludedChars += '\]' }
                        '\' { $excludedChars += '\\' }
                        '^'  { $excludedChars += '\^' }
                        '-'  { $excludedChars += '\-' }
                        default { $excludedChars += $c }
                    }
                }

                if ($hasControlChars) {
                    $excludedChars += '\x00-\x1F'
                }
                if ($hasSpace) {
                    $excludedChars += '\s'
                }

                $state.IsExclusion = $true
                $state.ExcludedChars = $excludedChars
            }
        },

        [ordered]@{
            Name    = 'Cant_UseSpacesControlChars'
            Pattern = "(?i)can'?t\s+use\s+spaces,?\s*control\s+characters,?\s*(or\s+)?these\s+characters"
            Action  = {
                param($m, $state, $block)
                $text = if ($block) { $block } else { $m.Value }

                # Extract chars after "these characters:"
                $charsPart = ''
                if ($text -match '(?i)these\s+characters:\s*(.+)$') {
                    $charsPart = $matches[1].Trim()
                }

                # Chars are space-separated, get unique non-space chars
                $chars = $charsPart -replace '\s+', ''

                # Build escaped character set
                $excludedChars = ''
                $uniqueChars = ($chars.ToCharArray() | Select-Object -Unique)

                foreach ($c in $uniqueChars) {
                    switch ($c) {
                        ']'  { $excludedChars += '\]' }
                        '\' { $excludedChars += '\\' }
                        '^'  { $excludedChars += '\^' }
                        '-'  { $excludedChars += '\-' }
                        default { $excludedChars += $c }
                    }
                }

                # Add space and control characters to excluded set
                $excludedChars += '\s\x00-\x1F'

                $state.IsExclusion = $true
                $state.ExcludedChars = $excludedChars
            }
        },

        [ordered]@{
            Name    = 'Cant_Contain'
            Pattern = "(?i)can'?t\s+contain"
            Action  = {
                param($m, $state, $block)
                $text = if ($block) { $block } else { $m.Value }

                # Extract text after "can't contain"
                $remainder = $text -replace "(?i)^.*?can'?t\s+contain\s*", ''

                # Check if this is a char exclusion (has "or control characters" suffix)
                if ($remainder -match '(?i)\s+or\s+control\s+characters?') {
                    $charsPart = $remainder -replace '(?i)\s+or\s+control\s+characters?.*$', ''
                    $chars = $charsPart.Trim()

                    # Build escaped character set for [^...] class
                    $excludedChars = ''
                    $uniqueChars = ($chars.ToCharArray() | Select-Object -Unique)

                    foreach ($c in $uniqueChars) {
                        switch ($c) {
                            ']'  { $excludedChars += '\]' }
                            '\' { $excludedChars += '\\' }
                            '^'  { $excludedChars += '\^' }
                            '-'  { $excludedChars += '\-' }
                            default { $excludedChars += $c }
                        }
                    }

                    $excludedChars += '\x00-\x1F'
                    $state.IsExclusion = $true
                    $state.ExcludedChars = $excludedChars
                }
                else {
                    # Not a char exclusion — store as note
                    $state.Notes.Add($text)
                }
            }
        },

        [ordered]@{
            Name    = 'Cant_UseUnderscores'
            Pattern = "(?i)can'?t\s+use\s+underscores|underscores\s+aren'?t\s+supported"
            Action  = {
                param($m, $state)
                # Remove underscores from allowed chars if present
                $state.Notes.Add('No underscores allowed')
            }
        },

        #----------------------------------------------------------------------
        # Fixed value — "Must be X"
        #----------------------------------------------------------------------

        [ordered]@{
            Name    = 'FixedValue'
            Pattern = '(?i)^must be\s+(.+)'
            Action  = {
                param($m, $state, $block)
                $text = if ($block) { $block } else { $m.Value }
                $value = $m.Groups[1].Value.Trim().TrimEnd('.')

                if ($value -match '(?i)^a\s+globally\s+unique\s+identifier\s+\(GUID\)') {
                    # GUID pattern
                    $state.FixedValue = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
                }
                elseif ($value -match '(?i)^in\s+format:\s*(.+)') {
                    # "Must be in format:" — parse the format inline
                    $format = $matches[1].Trim().TrimEnd('.')
                    if ($format -match 'VaultName_KeyName_KeyVersion') {
                        $state.FixedValue = '^[^_]+_[^_]+_[^_]+$'
                    }
                    else {
                        $escaped = [regex]::Escape($format)
                        $state.FixedValue = "^$escaped`$"
                    }
                }
                else {
                    # Fixed value — escape regex metacharacters
                    $escaped = [regex]::Escape($value)
                    $state.FixedValue = "^$escaped`$"
                }
            }
        },

        #----------------------------------------------------------------------
        # Enum value — "Use one of:"
        #----------------------------------------------------------------------

        [ordered]@{
            Name    = 'EnumValue'
            Pattern = '(?i)^use one of:'
            Action  = {
                param($m, $state, $block)
                $text = if ($block) { $block } else { $m.Value }
                $remainder = $text -replace '(?i)^use one of:\s*', ''
                # Values are space-separated words
                $values = $remainder.Trim() -split '\s+' |
                    Where-Object { $_.Length -gt 0 }
                if ($values.Count -gt 0) {
                    $escaped = $values | ForEach-Object { [regex]::Escape($_) }
                    $state.FixedValue = "^($($escaped -join '|'))`$"
                }
            }
        },

        #----------------------------------------------------------------------
        # Fixed format — "Should always be" / "Must be in format:"
        #----------------------------------------------------------------------

        [ordered]@{
            Name    = 'FixedFormat_ShouldAlwaysBe'
            Pattern = '(?i)^should always be\s+(.+)'
            Action  = {
                param($m, $state)
                $value = $m.Groups[1].Value.Trim().TrimEnd('.')
                $escaped = [regex]::Escape($value)
                $state.FixedValue = "^$escaped`$"
            }
        },

        [ordered]@{
            Name    = 'FixedFormat_MustBeInFormat'
            Pattern = '(?i)^must be in format:'
            Action  = {
                param($m, $state, $block)
                $text = if ($block) { $block } else { $m.Value }
                $remainder = $text -replace '(?i)^must be in format:\s*', ''
                $format = $remainder.Trim().TrimEnd('.')

                if ($format -match 'VaultName_KeyName_KeyVersion') {
                    $state.FixedValue = '^[^_]+_[^_]+_[^_]+$'
                }
                else {
                    # Generic format — escape and use as literal
                    $escaped = [regex]::Escape($format)
                    $state.FixedValue = "^$escaped`$"
                }
            }
        },

        #----------------------------------------------------------------------
        # Special patterns (must be before Note to avoid Note absorbing them)
        #----------------------------------------------------------------------

        [ordered]@{
            Name    = 'Special_SolutionPattern'
            Pattern = '(?i)the\s+name\s+must\s+be\s+in\s+the\s+pattern:'
            Action  = {
                param($m, $state)
                # SolutionType(WorkspaceName) or SolutionType[WorkspaceName]
                $state.FixedValue = '^[a-zA-Z0-9]+[\(\[][a-zA-Z0-9\-]+[\)\]]$'
            }
        },

        #----------------------------------------------------------------------
        # Note / Informational — skip these blocks
        #----------------------------------------------------------------------

        [ordered]@{
            Name    = 'Note'
            Pattern = '(?i)^note:|^for more information|^the solution type|only predefined values|^to use restricted|^for solutions authored|^windows virtual|^linux virtual|^resource name can|^for example|^valid characters are|^each label is|^can''t contain reserved'
            Action  = {
                param($m, $state, $block)
                $text = if ($block) { $block } else { $m.Value }
                $state.Notes.Add($text)
            }
        }
    )

    return $rules
}

#endregion Rule Registry

#region Registry Lifecycle

<#
.SYNOPSIS
    Clears the cached rule registry so it is rebuilt on the next call
    to Convert-ConstraintToRegex.
.DESCRIPTION
    The rule registry is built once and cached at script scope for
    performance.  Call this function after modifying
    New-ConstraintRuleRegistry during development or testing to force
    a fresh rebuild.
#>
function Reset-ConstraintRuleRegistry {
    [CmdletBinding()]
    param()
    $script:ConstraintRuleRegistry = $null
}

#endregion Registry Lifecycle

#region Orchestrator

function Convert-ConstraintToRegex {
    <#
    .SYNOPSIS
        Converts a validChars constraint description into a regex pattern.
    .DESCRIPTION
        Splits the validChars text into blocks, iterates each block through
        the rule registry, accumulates state, and assembles a final regex.
    .PARAMETER InputObject
        A hashtable containing validChars, minLength, and maxLength.
    .OUTPUTS
        [string] The generated regex pattern, or $null if no pattern could be built.
    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [hashtable]
        $InputObject
    )

    process {
        if (-not $InputObject.validChars) {
            return $null
        }

        #------------------------------------------------------------------
        # Initialize state
        #------------------------------------------------------------------
        $state = [ordered]@{
            AllowedChars  = [System.Collections.Generic.List[string]]::new()
            StartChars    = $null
            EndChars      = $null
            CantEndWith   = [System.Collections.Generic.List[string]]::new()
            CantStartWith = [System.Collections.Generic.List[string]]::new()
            Lookaheads    = [System.Collections.Generic.List[string]]::new()
            Lookbehinds   = [System.Collections.Generic.List[string]]::new()
            FixedValue    = $null
            IsExclusion   = $false
            ExcludedChars = $null
            MatchAll      = $false
            Notes         = [System.Collections.Generic.List[string]]::new()
        }

        #------------------------------------------------------------------
        # Parse min/max lengths
        #------------------------------------------------------------------
        $minLen = if ($InputObject.minLength) {
            [int]::Parse($InputObject.minLength)
        } else {
            1
        }

        $maxLen = if ($InputObject.maxLength) {
            [int]::Parse($InputObject.maxLength)
        } else {
            80
        }

        #------------------------------------------------------------------
        # Split into blocks
        #------------------------------------------------------------------
        $blocks = @(Split-ConstraintBlocks `
            -InputString $InputObject.validChars)

        if ($blocks.Count -eq 0) {
            return $null
        }

        #------------------------------------------------------------------
        # Load rule registry (cached at script scope for reuse)
        #------------------------------------------------------------------
        if (-not $script:ConstraintRuleRegistry) {
            $script:ConstraintRuleRegistry = New-ConstraintRuleRegistry
        }
        $rules = $script:ConstraintRuleRegistry

        #------------------------------------------------------------------
        # Iterate blocks through rules
        #------------------------------------------------------------------
        foreach ($block in $blocks) {
            # Split each block into sentences using ". " or "; " as delimiters.
            # This ensures that compound blocks like
            #   "Start and end with alphanumeric; can't be all numbers."
            # have each clause matched independently.
            # The lookbehind requires a word char before the period to avoid
            # splitting "Can't end with . or space" mid-sentence.
            $sentences = $block -split '(?<=\w\.)\s+|;\s+' `
                | ForEach-Object { $_.TrimEnd('.').Trim() } `
                | Where-Object { $_.Length -gt 0 }

            foreach ($sentence in $sentences) {
                foreach ($rule in $rules) {
                    $m = [regex]::Match($sentence, $rule.Pattern)

                    if ($m.Success) {
                        & $rule.Action $m $state $sentence
                        break
                    }
                }
            }
        }

        #------------------------------------------------------------------
        # Assemble final regex
        #------------------------------------------------------------------

        # Short-circuit: fixed value
        if ($state.FixedValue) {
            return $state.FixedValue
        }

        # Build character class
        $charClass = $null

        if ($state.IsExclusion -and $state.ExcludedChars) {
            $charClass = "[^$($state.ExcludedChars)]"
        }
        elseif ($state.MatchAll) {
            $charClass = '.'
        }
        elseif ($state.AllowedChars.Count -gt 0) {
            $joined = ($state.AllowedChars | Select-Object -Unique) -join ''
            $charClass = "[$joined]"
        }

        if (-not $charClass) {
            return $null
        }

        # Build lookaheads string
        $lookaheadStr = ''
        if ($state.Lookaheads.Count -gt 0) {
            $lookaheadStr = ($state.Lookaheads | Select-Object -Unique) -join ''
        }

        # Incorporate CantStartWith as negative lookahead
        if ($state.CantStartWith.Count -gt 0 -and -not $state.StartChars) {
            $cantStartChars = ($state.CantStartWith | Select-Object -Unique) -join ''
            $lookaheadStr += "(?![$cantStartChars])"
        }

        # Build lookbehind string for CantEndWith
        $lookbehindStr = ''
        if ($state.CantEndWith.Count -gt 0 -and -not $state.EndChars) {
            $cantEndChars = ($state.CantEndWith | Select-Object -Unique) -join ''
            $lookbehindStr = "(?<![$cantEndChars])"
        }

        # Assemble regex based on start/end constraints
        $result = $null

        if ($state.StartChars -and $state.EndChars) {
            # Both start and end constrained
            if ($minLen -le 1) {
                # Min length 1: start char alone is valid
                $result = "^${lookaheadStr}$($state.StartChars)" +
                    "($charClass{0,$($maxLen - 2)}$($state.EndChars))?`$"
            }
            elseif ($minLen -eq 2) {
                $result = "^${lookaheadStr}$($state.StartChars)" +
                    "$charClass{0,$($maxLen - 2)}$($state.EndChars)`$"
            }
            else {
                $result = "^${lookaheadStr}$($state.StartChars)" +
                    "$charClass{$($minLen - 2),$($maxLen - 2)}$($state.EndChars)`$"
            }
        }
        elseif ($state.StartChars) {
            # Only start constrained
            if ($minLen -le 1) {
                $result = "^${lookaheadStr}$($state.StartChars)" +
                    "$charClass{0,$($maxLen - 1)}${lookbehindStr}`$"
            }
            else {
                $result = "^${lookaheadStr}$($state.StartChars)" +
                    "$charClass{$($minLen - 1),$($maxLen - 1)}${lookbehindStr}`$"
            }
        }
        elseif ($state.EndChars) {
            # Only end constrained
            if ($minLen -le 1) {
                $result = "^${lookaheadStr}" +
                    "$charClass{0,$($maxLen - 1)}$($state.EndChars)`$"
            }
            else {
                $result = "^${lookaheadStr}" +
                    "$charClass{$($minLen - 1),$($maxLen - 1)}$($state.EndChars)`$"
            }
        }
        else {
            # No start/end constraints
            $result = "^${lookaheadStr}$charClass{$minLen,$maxLen}${lookbehindStr}`$"
        }

        return $result
    }
}

#endregion Orchestrator
