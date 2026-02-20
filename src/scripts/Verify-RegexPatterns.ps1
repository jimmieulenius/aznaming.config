# Comprehensive semantic verification of validChars → regex conversions
# For each constraint description, we generate test strings that SHOULD and SHOULD NOT match,
# based on the described rules, and verify the regex handles them correctly.

$functionPath = 'c:\Users\admin\Source\Repos\aznaming.config\src\modules\Az.Naming.Config\Source\Functions\Convert-ConstraintToRegex.ps1'
. $functionPath

$jsonPath = 'c:\Users\admin\Source\Repos\aznaming.config\config\validChars-regex.json'
$generated = Get-Content -Path $jsonPath -Encoding UTF8 | ConvertFrom-Json

$totalTests = 0
$passedTests = 0
$failedTests = 0
$failedDetails = @()

function Test-Regex {
    param(
        [int]$Line,
        [string]$Regex,
        [string]$TestValue,
        [bool]$ShouldMatch,
        [string]$Reason
    )

    $script:totalTests++
    try {
        $matched = $TestValue -cmatch $Regex
    }
    catch {
        $matched = $false
    }

    if ($matched -eq $ShouldMatch) {
        $script:passedTests++
    }
    else {
        $script:failedTests++
        $expectedStr = if ($ShouldMatch) { "MATCH" } else { "NO-MATCH" }
        $actualStr   = if ($matched)     { "MATCHED" } else { "DID-NOT-MATCH" }
        $script:failedDetails += [PSCustomObject]@{
            Line      = $Line
            Regex     = $Regex
            TestValue = $TestValue
            Expected  = $expectedStr
            Actual    = $actualStr
            Reason    = $Reason
        }
    }
}

foreach ($entry in $generated) {
    $ln    = $entry.LineNumber
    $regex = $entry.GeneratedRegex
    $desc  = $entry.ValidationText

    if (-not $regex) { continue }

    # ===================================================================
    # LINE 1: All characters
    # ===================================================================
    if ($ln -eq 1) {
        Test-Regex $ln $regex "a"            $true  "single letter"
        Test-Regex $ln $regex "Hello World!"  $true  "mixed chars with space"
        Test-Regex $ln $regex '!@#%'          $true  "special chars"
        Test-Regex $ln $regex ""              $false "empty string should fail (minLen=1)"
        Test-Regex $ln $regex ("x" * 81)      $false "81 chars exceeds maxLen=80"
    }

    # ===================================================================
    # LINE 2-3: Alphanumeric, hyphens and a period/dot - Start and end with alphanumeric
    # ===================================================================
    if ($ln -in 2,3) {
        Test-Regex $ln $regex "a"              $true  "single alphanumeric"
        Test-Regex $ln $regex "abc-def"        $true  "alphanumeric with hyphen"
        Test-Regex $ln $regex "abc.def"        $true  "alphanumeric with period"
        Test-Regex $ln $regex "a1-b2.c3"       $true  "mixed valid"
        Test-Regex $ln $regex "-abc"           $false "starts with hyphen"
        Test-Regex $ln $regex "abc-"           $false "ends with hyphen"
        Test-Regex $ln $regex ".abc"           $false "starts with period"
        Test-Regex $ln $regex "abc."           $false "ends with period"
        Test-Regex $ln $regex "abc_def"        $false "underscore not allowed"
    }

    # ===================================================================
    # LINE 4: Alphanumeric, hyphens, and Unicode/Punycode (no start/end constraint)
    # ===================================================================
    if ($ln -eq 4) {
        Test-Regex $ln $regex "abc-123"      $true  "alphanumeric with hyphens"
        Test-Regex $ln $regex "-abc"         $true  "starts with hyphen (no constraint)"
        Test-Regex $ln $regex "abc-"         $true  "ends with hyphen (no constraint)"
        Test-Regex $ln $regex "abc_def"      $false "underscore not allowed"
    }

    # ===================================================================
    # LINE 5: Unicode/Punycode + Can't start or end with hyphen
    # ===================================================================
    if ($ln -eq 5) {
        Test-Regex $ln $regex "abc-123"      $true  "valid with hyphen"
        Test-Regex $ln $regex "a"            $true  "single char"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
    }

    # ===================================================================
    # LINE 6-7: Alphanumeric, underscores and hyphens - Start with alphanumeric
    # ===================================================================
    if ($ln -in 6,7) {
        Test-Regex $ln $regex "abc_def-123"  $true  "all valid chars"
        Test-Regex $ln $regex "a"            $true  "single alphanumeric"
        Test-Regex $ln $regex "_abc"         $false "starts with underscore"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
    }

    # ===================================================================
    # LINE 8: Alphanumerics only
    # ===================================================================
    if ($ln -eq 8) {
        Test-Regex $ln $regex "abc123"       $true  "alphanumerics"
        Test-Regex $ln $regex "ABC123"       $true  "upper alphanumerics"
        Test-Regex $ln $regex "a-b"          $false "hyphen not allowed"
        Test-Regex $ln $regex "a_b"          $false "underscore not allowed"
        Test-Regex $ln $regex "a.b"          $false "period not allowed"
    }

    # ===================================================================
    # LINE 9: Alphanumerics and hyphens (no constraints)
    # ===================================================================
    if ($ln -eq 9) {
        Test-Regex $ln $regex "abc-123"      $true  "valid"
        Test-Regex $ln $regex "-abc"         $true  "starts with hyphen ok (no constraint)"
        Test-Regex $ln $regex "abc_def"      $false "underscore not allowed"
    }

    # ===================================================================
    # LINE 10: Alphanumerics and hyphens + Start with alphanumeric + Can't be named bin/default
    # ===================================================================
    if ($ln -eq 10) {
        Test-Regex $ln $regex "abc-123"      $true  "valid name"
        Test-Regex $ln $regex "a"            $true  "single char"
        Test-Regex $ln $regex "bin"          $false "reserved word bin"
        Test-Regex $ln $regex "default"      $false "reserved word default"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
        Test-Regex $ln $regex "binx"         $true  "bin prefix is ok"
    }

    # ===================================================================
    # LINE 11: Alphanumerics and hyphens + Start with alphanumeric + No underscores
    # ===================================================================
    if ($ln -eq 11) {
        Test-Regex $ln $regex "abc-123"      $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single char"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
        Test-Regex $ln $regex "abc_def"      $false "underscore not allowed"
    }

    # ===================================================================
    # LINE 12: Alphanumerics and hyphens + Can't contain 3+ hyphens + Can't start/end with hyphen
    # ===================================================================
    if ($ln -eq 12) {
        Test-Regex $ln $regex "abc-def"      $true  "valid"
        Test-Regex $ln $regex "a--b"         $true  "double hyphen ok (<=2)"
        Test-Regex $ln $regex "a---b"        $false "triple hyphen not allowed"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
    }

    # ===================================================================
    # LINE 13: Alphanumerics and hyphens + Can't end with hyphen
    # ===================================================================
    if ($ln -eq 13) {
        Test-Regex $ln $regex "abc-def"      $true  "valid"
        Test-Regex $ln $regex "-abc"         $true  "starts with hyphen is ok"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
        Test-Regex $ln $regex "a"            $true  "single char"
    }

    # ===================================================================
    # LINE 14: Alphanumerics and hyphens + Can't start or end with hyphen
    # ===================================================================
    if ($ln -eq 14) {
        Test-Regex $ln $regex "abc-def"      $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single char"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
    }

    # ===================================================================
    # LINE 15: Alphanumerics and hyphens + Can't start/end with hyphen + No underscores
    # ===================================================================
    if ($ln -eq 15) {
        Test-Regex $ln $regex "abc-def"      $true  "valid"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
        Test-Regex $ln $regex "abc_def"      $false "underscore not allowed"
    }

    # ===================================================================
    # LINE 16: Alphanumerics and hyphens + Can't start with hyphen + No consecutive hyphens
    # ===================================================================
    if ($ln -eq 16) {
        Test-Regex $ln $regex "abc-def"      $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single char"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
        Test-Regex $ln $regex "a--b"         $false "consecutive hyphens"
    }

    # ===================================================================
    # LINE 17: Alphanumerics and hyphens + End with alphanumeric
    # ===================================================================
    if ($ln -eq 17) {
        Test-Regex $ln $regex "abc-def"      $true  "valid"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
        Test-Regex $ln $regex "a"            $true  "single char"
    }

    # ===================================================================
    # LINE 18: Alphanumerics and hyphens + Start and end with alphanumeric + can't be all numbers
    # ===================================================================
    if ($ln -eq 18) {
        Test-Regex $ln $regex "abc-123"      $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single char"
        Test-Regex $ln $regex "12345"        $false "all numbers not allowed"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
        Test-Regex $ln $regex "a1b2"         $true  "mixed alpha+num ok"
    }

    # ===================================================================
    # LINE 19-20: Alphanumerics and hyphens + Start and end with alphanumeric
    # ===================================================================
    if ($ln -in 19,20) {
        Test-Regex $ln $regex "abc-def"      $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single char"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
    }

    # ===================================================================
    # LINE 21: Alphanumerics and hyphens + Start and end alphanumeric + Consecutive hyphens not allowed
    # ===================================================================
    if ($ln -eq 21) {
        Test-Regex $ln $regex "abc-def"      $true  "valid"
        Test-Regex $ln $regex "a--b"         $false "consecutive hyphens"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
    }

    # ===================================================================
    # LINE 22: Alphanumerics and hyphens + Start and end with letter or number
    # ===================================================================
    if ($ln -eq 22) {
        Test-Regex $ln $regex "abc-def"      $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single char"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
    }

    # ===================================================================
    # LINE 23: Alphanumerics and hyphens + Start with a letter and end with alphanumeric
    # ===================================================================
    if ($ln -eq 23) {
        Test-Regex $ln $regex "abc-def"      $true  "valid"
        Test-Regex $ln $regex "abc-123"      $true  "end with number ok"
        Test-Regex $ln $regex "a"            $true  "single letter"
        Test-Regex $ln $regex "1abc"         $false "starts with number"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
    }

    # ===================================================================
    # LINE 24: Alphanumerics and hyphens + Start with a letter
    # ===================================================================
    if ($ln -eq 24) {
        Test-Regex $ln $regex "abc-123"      $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single letter"
        Test-Regex $ln $regex "1abc"         $false "starts with number"
    }

    # ===================================================================
    # LINE 25: Alphanumerics and hyphens + Start with a letter + Can't end with hyphen
    # ===================================================================
    if ($ln -eq 25) {
        Test-Regex $ln $regex "abc-123"      $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single letter"
        Test-Regex $ln $regex "1abc"         $false "starts with number"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
    }

    # ===================================================================
    # LINE 26-29: Alphanumerics and hyphens + Start with letter + End with letter or number
    # ===================================================================
    if ($ln -in 26,27,28,29) {
        Test-Regex $ln $regex "abc-123"      $true  "valid"
        Test-Regex $ln $regex "abc-def"      $true  "ends with letter"
        Test-Regex $ln $regex "a"            $true  "single letter"
        Test-Regex $ln $regex "1abc"         $false "starts with number"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
    }

    # ===================================================================
    # LINE 30: Alphanumerics and hyphens + Start with letter + End with letter or number + No consecutive hyphens
    # ===================================================================
    if ($ln -eq 30) {
        Test-Regex $ln $regex "abc-def"      $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single letter"
        Test-Regex $ln $regex "1abc"         $false "starts with number"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
        Test-Regex $ln $regex "a--b"         $false "consecutive hyphens"
    }

    # ===================================================================
    # LINE 31: Alphanumerics and hyphens + Start with alphanumeric
    # ===================================================================
    if ($ln -eq 31) {
        Test-Regex $ln $regex "abc-123"      $true  "valid"
        Test-Regex $ln $regex "1abc"         $true  "starts with number ok"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
    }

    # ===================================================================
    # LINE 32: Alphanumerics and hyphens + reserved words: default, requested, service
    # ===================================================================
    if ($ln -eq 32) {
        Test-Regex $ln $regex "abc-123"      $true  "valid"
        Test-Regex $ln $regex "default"      $false "reserved word"
        Test-Regex $ln $regex "requested"    $false "reserved word"
        Test-Regex $ln $regex "service"      $false "reserved word"
        Test-Regex $ln $regex "defaults"     $true  "not exact reserved word"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
    }

    # ===================================================================
    # LINE 33: Alphanumerics and hyphens (dashboard - note only)
    # ===================================================================
    if ($ln -eq 33) {
        Test-Regex $ln $regex "abc-123"      $true  "valid"
    }

    # ===================================================================
    # LINE 34: Alphanumerics and periods + Start and end with alphanumeric
    # ===================================================================
    if ($ln -eq 34) {
        Test-Regex $ln $regex "abc.def"      $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single char"
        Test-Regex $ln $regex ".abc"         $false "starts with period"
        Test-Regex $ln $regex "abc."         $false "ends with period"
        Test-Regex $ln $regex "abc-def"      $false "hyphen not allowed"
    }

    # ===================================================================
    # LINE 35: Alphanumerics and underscores + Start with a letter
    # ===================================================================
    if ($ln -eq 35) {
        Test-Regex $ln $regex "abc_123"      $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single letter"
        Test-Regex $ln $regex "1abc"         $false "starts with number"
        Test-Regex $ln $regex "_abc"         $false "starts with underscore"
        Test-Regex $ln $regex "abc-def"      $false "hyphen not allowed"
    }

    # ===================================================================
    # LINE 36: Alphanumerics, hyphens, and periods + Start and end with alphanumeric
    # ===================================================================
    if ($ln -eq 36) {
        Test-Regex $ln $regex "abc-def.123"  $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single char"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
        Test-Regex $ln $regex "abc."         $false "ends with period"
    }

    # ===================================================================
    # LINE 37: Alphanumerics, hyphens, and underscores (no constraints)
    # ===================================================================
    if ($ln -eq 37) {
        Test-Regex $ln $regex "abc-def_123"  $true  "valid"
        Test-Regex $ln $regex "-abc"         $true  "starts with hyphen ok (no constraint)"
        Test-Regex $ln $regex "abc.def"      $false "period not allowed"
    }

    # ===================================================================
    # LINE 38: Alphanumerics, hyphens, underscores + Start with a letter or number
    # ===================================================================
    if ($ln -eq 38) {
        Test-Regex $ln $regex "abc-def_123"  $true  "valid"
        Test-Regex $ln $regex "1abc"         $true  "starts with number"
        Test-Regex $ln $regex "_abc"         $false "starts with underscore"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
    }

    # ===================================================================
    # LINE 39: Alphanumerics, hyphens, periods, and underscores (no constraints)
    # ===================================================================
    if ($ln -eq 39) {
        Test-Regex $ln $regex "abc-def.123_x" $true  "valid"
        Test-Regex $ln $regex "abc"           $true  "simple"
    }

    # ===================================================================
    # LINE 40: Start letter, end alphanumeric
    # ===================================================================
    if ($ln -eq 40) {
        Test-Regex $ln $regex "abc-def.123"  $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single letter"
        Test-Regex $ln $regex "1abc"         $false "starts with number"
        Test-Regex $ln $regex "abc."         $false "ends with period"
    }

    # ===================================================================
    # LINE 41: Start with alphanumeric
    # ===================================================================
    if ($ln -eq 41) {
        Test-Regex $ln $regex "abc-def.123_x" $true  "valid"
        Test-Regex $ln $regex "1abc"          $true  "starts with number ok"
        Test-Regex $ln $regex "_abc"          $false "starts with underscore"
        Test-Regex $ln $regex "-abc"          $false "starts with hyphen"
    }

    # ===================================================================
    # LINE 42: Alphanumerics, hyphens, spaces, and periods
    # ===================================================================
    if ($ln -eq 42) {
        Test-Regex $ln $regex "abc def.123-x" $true  "valid with space"
        Test-Regex $ln $regex "abc_def"       $false "underscore not allowed"
    }

    # ===================================================================
    # LINE 43: Alphanumerics, hyphens, underscores, and periods
    # ===================================================================
    if ($ln -eq 43) {
        Test-Regex $ln $regex "abc-def_123.x" $true  "valid"
        Test-Regex $ln $regex "abc"           $true  "simple"
    }

    # ===================================================================
    # LINE 44: Alphanumerics, hyphens, underscores, periods, and parentheses
    # ===================================================================
    if ($ln -eq 44) {
        Test-Regex $ln $regex "abc(def)-123" $true  "with parentheses"
        Test-Regex $ln $regex "abc"          $true  "simple"
    }

    # ===================================================================
    # LINE 45: Start letter/number + Can't end with period
    # ===================================================================
    if ($ln -eq 45) {
        Test-Regex $ln $regex "abc(def)-123" $true  "valid"
        Test-Regex $ln $regex "1abc"         $true  "starts with number ok"
        Test-Regex $ln $regex "_abc"         $false "starts with underscore"
        Test-Regex $ln $regex "abc."         $false "ends with period"
    }

    # ===================================================================
    # LINE 46: Start alphanumeric
    # ===================================================================
    if ($ln -eq 46) {
        Test-Regex $ln $regex "abc.def-123_x" $true  "valid"
        Test-Regex $ln $regex "1abc"          $true  "starts with number ok"
        Test-Regex $ln $regex ".abc"          $false "starts with period"
        Test-Regex $ln $regex "_abc"          $false "starts with underscore"
    }

    # ===================================================================
    # LINE 47: Start and end with alphanumeric
    # ===================================================================
    if ($ln -eq 47) {
        Test-Regex $ln $regex "abc.def-123"  $true  "valid"
        Test-Regex $ln $regex ".abc"         $false "starts with period"
        Test-Regex $ln $regex "abc."         $false "ends with period"
        Test-Regex $ln $regex "abc_"         $false "ends with underscore"
    }

    # ===================================================================
    # LINE 48: Start and end with alphnumeric (typo)
    # ===================================================================
    if ($ln -eq 48) {
        Test-Regex $ln $regex "abc.def-123"  $true  "valid"
        Test-Regex $ln $regex ".abc"         $false "starts with period"
        Test-Regex $ln $regex "abc_"         $false "ends with underscore"
    }

    # ===================================================================
    # LINE 49: Start and end with letter or number
    # ===================================================================
    if ($ln -eq 49) {
        Test-Regex $ln $regex "abc.def-123"  $true  "valid"
        Test-Regex $ln $regex ".abc"         $false "starts with period"
        Test-Regex $ln $regex "abc."         $false "ends with period"
    }

    # ===================================================================
    # LINE 50: Start with alphanumeric and end with alphanumeric or underscore
    # ===================================================================
    if ($ln -eq 50) {
        Test-Regex $ln $regex "abc.def-123_" $true  "ends with underscore ok"
        Test-Regex $ln $regex "abc"          $true  "simple"
        Test-Regex $ln $regex ".abc"         $false "starts with period"
        Test-Regex $ln $regex "abc."         $false "ends with period"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
    }

    # ===================================================================
    # LINE 51: + slashes + Start and end with alphanumeric
    # ===================================================================
    if ($ln -eq 51) {
        Test-Regex $ln $regex "abc/def.123"  $true  "valid with slash"
        Test-Regex $ln $regex "/abc"         $false "starts with slash"
        Test-Regex $ln $regex "abc/"         $false "ends with slash"
    }

    # ===================================================================
    # LINE 52: Can't end in period
    # ===================================================================
    if ($ln -eq 52) {
        Test-Regex $ln $regex "abc(def).123" $true  "valid"
        Test-Regex $ln $regex "abc."         $false "ends with period"
    }

    # ===================================================================
    # LINE 53: Can't end with period or space
    # ===================================================================
    if ($ln -eq 53) {
        Test-Regex $ln $regex "abc def.123-x" $true  "valid with space"
        Test-Regex $ln $regex "abc."          $false "ends with period"
        Test-Regex $ln $regex "abc "          $false "ends with space"
    }

    # ===================================================================
    # LINE 54: Alphanumerics, underscores, and hyphens (no constraints)
    # ===================================================================
    if ($ln -eq 54) {
        Test-Regex $ln $regex "abc_def-123"  $true  "valid"
        Test-Regex $ln $regex "-abc"         $true  "ok, no constraint"
        Test-Regex $ln $regex "abc.def"      $false "period not allowed"
    }

    # ===================================================================
    # LINE 55: Alphanumerics, underscores, and hyphens + Start with alphanumeric
    # ===================================================================
    if ($ln -eq 55) {
        Test-Regex $ln $regex "abc_def-123"  $true  "valid"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen (start with alphanumeric required)"
        Test-Regex $ln $regex "abc.def"      $false "period not allowed"
    }

    # ===================================================================
    # LINE 56: Start and end with alphanumeric or underscore
    # ===================================================================
    if ($ln -eq 56) {
        Test-Regex $ln $regex "abc_def-123"  $true  "valid"
        Test-Regex $ln $regex "_abc"         $true  "starts with underscore ok"
        Test-Regex $ln $regex "_abc_"        $true  "ends with underscore ok"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
    }

    # ===================================================================
    # LINE 57-58: Start and end with alphanumeric
    # ===================================================================
    if ($ln -in 57,58) {
        Test-Regex $ln $regex "abc_def-123"  $true  "valid"
        Test-Regex $ln $regex "_abc"         $false "starts with underscore"
        Test-Regex $ln $regex "abc_"         $false "ends with underscore"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
    }

    # ===================================================================
    # LINE 59: Start with a letter
    # ===================================================================
    if ($ln -eq 59) {
        Test-Regex $ln $regex "abc_def-123"  $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single letter"
        Test-Regex $ln $regex "1abc"         $false "starts with number"
        Test-Regex $ln $regex "_abc"         $false "starts with underscore"
    }

    # ===================================================================
    # LINE 60: Start with alphanumeric
    # ===================================================================
    if ($ln -eq 60) {
        Test-Regex $ln $regex "abc_def-123"  $true  "valid"
        Test-Regex $ln $regex "1abc"         $true  "starts with number"
        Test-Regex $ln $regex "_abc"         $false "starts with underscore"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
    }

    # ===================================================================
    # LINE 61: Alphanumerics, underscores, periods + Start and end with alphanumeric
    # ===================================================================
    if ($ln -eq 61) {
        Test-Regex $ln $regex "abc_def.123"  $true  "valid"
        Test-Regex $ln $regex "_abc"         $false "starts with underscore"
        Test-Regex $ln $regex "abc_"         $false "ends with underscore"
        Test-Regex $ln $regex "abc."         $false "ends with period"
    }

    # ===================================================================
    # LINE 62: underscores, hyphens, and parentheses
    # ===================================================================
    if ($ln -eq 62) {
        Test-Regex $ln $regex "abc(def)_123" $true  "valid with parentheses"
        Test-Regex $ln $regex "abc.def"      $false "period not allowed"
    }

    # ===================================================================
    # LINE 63: Start and end with alphanumeric
    # ===================================================================
    if ($ln -eq 63) {
        Test-Regex $ln $regex "abc_def-123.x" $true  "valid"
        Test-Regex $ln $regex "_abc"          $false "starts with underscore"
        Test-Regex $ln $regex "abc."          $false "ends with period"
    }

    # ===================================================================
    # LINE 64: parentheses, hyphens, periods
    # ===================================================================
    if ($ln -eq 64) {
        Test-Regex $ln $regex "abc(def)_123.x-y" $true  "valid"
    }

    # ===================================================================
    # LINE 65: Start with alphanumeric
    # ===================================================================
    if ($ln -eq 65) {
        Test-Regex $ln $regex "abc_def.123-x" $true  "valid"
        Test-Regex $ln $regex "1abc"          $true  "number start ok"
        Test-Regex $ln $regex "_abc"          $false "starts with underscore"
    }

    # ===================================================================
    # LINE 66: Start with letter or number, end with letter/number/underscore
    # ===================================================================
    if ($ln -eq 66) {
        Test-Regex $ln $regex "abc_123"      $true  "valid"
        Test-Regex $ln $regex "abc_"         $true  "ends with underscore ok"
        Test-Regex $ln $regex "_abc"         $false "starts with underscore"
        Test-Regex $ln $regex "abc."         $false "ends with period"
    }

    # ===================================================================
    # LINE 67: Start with alphanumeric; end alphanumeric or underscore
    # ===================================================================
    if ($ln -eq 67) {
        Test-Regex $ln $regex "abc_123"      $true  "valid"
        Test-Regex $ln $regex "abc_"         $true  "ends with underscore"
        Test-Regex $ln $regex "_abc"         $false "starts with underscore"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
    }

    # ===================================================================
    # LINE 68: Start with alphanumeric
    # ===================================================================
    if ($ln -eq 68) {
        Test-Regex $ln $regex "abc_def.123-x" $true  "valid"
        Test-Regex $ln $regex "_abc"          $false "starts with underscore"
    }

    # ===================================================================
    # LINE 69: Start with alphanumeric, end with alphanumeric or underscore
    # ===================================================================
    if ($ln -eq 69) {
        Test-Regex $ln $regex "abc_"         $true  "ends with underscore ok"
        Test-Regex $ln $regex ".abc"         $false "starts with period"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
    }

    # ===================================================================
    # LINE 70: Alphanumerics + Start with a letter
    # ===================================================================
    if ($ln -eq 70) {
        Test-Regex $ln $regex "abc123"       $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single letter"
        Test-Regex $ln $regex "1abc"         $false "starts with number"
        Test-Regex $ln $regex "abc-def"      $false "hyphen not allowed"
    }

    # ===================================================================
    # LINE 71: Any URL characters and case sensitive
    # ===================================================================
    if ($ln -eq 71) {
        Test-Regex $ln $regex "https://abc.com/path?q=1" $true  "URL valid"
        Test-Regex $ln $regex "abc"                      $true  "simple"
    }

    # ===================================================================
    # LINE 72: Can't contain <>*%&:\/?@- or control characters + Can't end with . or space
    # ===================================================================
    if ($ln -eq 72) {
        Test-Regex $ln $regex "abcdef123"    $true  "valid"
        Test-Regex $ln $regex "abc."         $false "ends with period"
        Test-Regex $ln $regex "abc "         $false "ends with space"
    }

    # ===================================================================
    # LINE 73: Can't use spaces, control chars, these characters + Can't start with underscore + Can't end with period or hyphen
    # ===================================================================
    if ($ln -eq 73) {
        Test-Regex $ln $regex "abcdef"       $true  "valid"
        Test-Regex $ln $regex "abc def"      $false "space not allowed"
    }

    # ===================================================================
    # LINE 74: Same as 73 but with Windows/Linux VM note
    # ===================================================================
    if ($ln -eq 74) {
        Test-Regex $ln $regex "abcdef"       $true  "valid"
    }

    # ===================================================================
    # LINE 75-76: Can't use: '<>%&:\?/# or control characters
    # ===================================================================
    if ($ln -in 75,76) {
        Test-Regex $ln $regex "abcdef 123"   $true  "valid with space"
        Test-Regex $ln $regex "abc<def"      $false "< not allowed"
        Test-Regex $ln $regex "abc>def"      $false "> not allowed"
    }

    # ===================================================================
    # LINE 77: Can't use: <>*%&:\?.+/ or control chars + Can't end with space
    # ===================================================================
    if ($ln -eq 77) {
        Test-Regex $ln $regex "abcdef123"    $true  "valid"
        Test-Regex $ln $regex "abc "         $false "ends with space"
        Test-Regex $ln $regex "abc<def"      $false "< not allowed"
    }

    # ===================================================================
    # LINE 78: Can't use: :<>+/&%\?| or control characters (NO end constraint)
    # ===================================================================
    if ($ln -eq 78) {
        Test-Regex $ln $regex "abcdef"       $true  "valid"
        Test-Regex $ln $regex "abc<def"      $false "< not allowed"
    }

    # ===================================================================
    # LINE 79-80: Various Can't use patterns + Can't end with space or period
    # ===================================================================
    if ($ln -in 79,80) {
        Test-Regex $ln $regex "abcdef"       $true  "valid"
    }

    # ===================================================================
    # LINE 81: Can't use: / + Can't end with space or period
    # ===================================================================
    if ($ln -eq 81) {
        Test-Regex $ln $regex "abcdef"       $true  "valid"
        Test-Regex $ln $regex "abc/def"      $false "/ not allowed"
        Test-Regex $ln $regex "abc."         $false "ends with period"
        Test-Regex $ln $regex "abc "         $false "ends with space"
    }

    # ===================================================================
    # LINE 82-83: Can't use: %&\?/ + Can't end with space or period
    # ===================================================================
    if ($ln -in 82,83) {
        Test-Regex $ln $regex "abcdef"       $true  "valid"
        Test-Regex $ln $regex "abc%def"      $false "% not allowed"
    }

    # ===================================================================
    # LINE 84: Can't use: <>*&@:?+/\,;=.|[]" or space + Can't start with underscore, hyphen, or number
    # ===================================================================
    if ($ln -eq 84) {
        Test-Regex $ln $regex "abcdef"       $true  "valid"
        Test-Regex $ln $regex "abc def"      $false "space not allowed"
        Test-Regex $ln $regex "_abc"         $false "starts with underscore"
    }

    # ===================================================================
    # LINE 85-86: Can't use: <>*#.%&:\\+?/- or control chars + Start with alphanumeric
    # ===================================================================
    if ($ln -in 85,86) {
        Test-Regex $ln $regex "abcdef"       $true  "valid"
        Test-Regex $ln $regex "abc<def"      $false "< not allowed"
    }

    # ===================================================================
    # LINE 87: Can't use: <>*%{}&:\\?+/#| + Can't end with space or period
    # ===================================================================
    if ($ln -eq 87) {
        Test-Regex $ln $regex "abcdef"       $true  "valid"
    }

    # ===================================================================
    # LINE 88: Can't end with period
    # ===================================================================
    if ($ln -eq 88) {
        Test-Regex $ln $regex "abcdef"       $true  "valid"
        Test-Regex $ln $regex "abc."         $false "ends with period"
    }

    # ===================================================================
    # LINE 89: Can't end with a space
    # ===================================================================
    if ($ln -eq 89) {
        Test-Regex $ln $regex "abcdef"       $true  "valid"
        Test-Regex $ln $regex "abc "         $false "ends with space"
    }

    # ===================================================================
    # LINE 90: Can't end with period or space
    # ===================================================================
    if ($ln -eq 90) {
        Test-Regex $ln $regex "abcdef"       $true  "valid"
        Test-Regex $ln $regex "abc."         $false "ends with period"
        Test-Regex $ln $regex "abc "         $false "ends with space"
    }

    # ===================================================================
    # LINE 91: Can't use: <>%&\?/ or control chars (no end constraint)
    # ===================================================================
    if ($ln -eq 91) {
        Test-Regex $ln $regex "abcdef"       $true  "valid"
    }

    # ===================================================================
    # LINE 92: Datastore name — lowercase letters, digits, underscores
    # ===================================================================
    if ($ln -eq 92) {
        Test-Regex $ln $regex "my_store_123" $true  "valid"
        Test-Regex $ln $regex "ABC"          $false "uppercase not allowed"
        Test-Regex $ln $regex "my-store"     $false "hyphen not allowed"
    }

    # ===================================================================
    # LINE 93: Display name - any characters (MatchAll path)
    # ===================================================================
    if ($ln -eq 93) {
        Test-Regex $ln $regex "Hello World!" $true  "any chars ok"
        Test-Regex $ln $regex "abc"          $true  "simple"
    }

    # ===================================================================
    # LINE 94: Each label — alphanumerics, underscores, hyphens, separated by period
    # ===================================================================
    if ($ln -eq 94) {
        Test-Regex $ln $regex "abc.def"      $true  "valid DNS-like"
        Test-Regex $ln $regex "abc_def-123"  $true  "valid label chars"
        Test-Regex $ln $regex "abc"          $true  "simple"
    }

    # ===================================================================
    # LINE 95: Solution pattern: SolutionType(WorkspaceName) or SolutionType[WorkspaceName]
    # ===================================================================
    if ($ln -eq 95) {
        Test-Regex $ln $regex "AntiMalware(contoso-IT)" $true  "parentheses solution"
        Test-Regex $ln $regex "Solution[workspace]"     $true  "brackets solution"
        Test-Regex $ln $regex "justtext"                $false "no parens or brackets"
    }

    # ===================================================================
    # LINE 96: Letters and numbers + Start with letter + End with letter or number
    # ===================================================================
    if ($ln -eq 96) {
        Test-Regex $ln $regex "abc123"       $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single letter"
        Test-Regex $ln $regex "1abc"         $false "starts with number"
        Test-Regex $ln $regex "abc-def"      $false "hyphen not allowed"
    }

    # ===================================================================
    # LINE 97: Lowercase letters and numbers
    # ===================================================================
    if ($ln -eq 97) {
        Test-Regex $ln $regex "abc123"       $true  "valid"
        Test-Regex $ln $regex "ABC"          $false "uppercase not allowed"
        Test-Regex $ln $regex "abc-def"      $false "hyphen not allowed"
    }

    # ===================================================================
    # LINE 98: Lowercase letters and numbers + Can't start with a number
    # ===================================================================
    if ($ln -eq 98) {
        Test-Regex $ln $regex "abc123"       $true  "valid"
        Test-Regex $ln $regex "1abc"         $false "starts with number"
        Test-Regex $ln $regex "ABC"          $false "uppercase not allowed"
    }

    # ===================================================================
    # LINE 99: Lowercase letters and numbers + Start with a letter
    # ===================================================================
    if ($ln -eq 99) {
        Test-Regex $ln $regex "abc123"       $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single letter"
        Test-Regex $ln $regex "1abc"         $false "starts with number"
    }

    # ===================================================================
    # LINE 100-101: Lowercase letters and numbers + Start with a lowercase letter
    # ===================================================================
    if ($ln -in 100,101) {
        Test-Regex $ln $regex "abc123"       $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single letter"
        Test-Regex $ln $regex "1abc"         $false "starts with number"
        Test-Regex $ln $regex "Abc"          $false "uppercase not allowed"
    }

    # ===================================================================
    # LINE 102: Lowercase letters or numbers + Start with lowercase letter
    # ===================================================================
    if ($ln -eq 102) {
        Test-Regex $ln $regex "abc123"       $true  "valid"
        Test-Regex $ln $regex "1abc"         $false "starts with number"
    }

    # ===================================================================
    # LINE 103-104: Lowercase letters, hyphens, numbers + Can't start or end with hyphen
    # ===================================================================
    if ($ln -in 103,104) {
        Test-Regex $ln $regex "abc-123"      $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single char"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
        Test-Regex $ln $regex "ABC-123"      $false "uppercase not allowed"
    }

    # ===================================================================
    # LINE 105: Start and end with letter or number + Can't contain -ondemand
    # ===================================================================
    if ($ln -eq 105) {
        Test-Regex $ln $regex "abc-123"      $true  "valid"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
        Test-Regex $ln $regex "abc-ondemand" $false "contains -ondemand"
    }

    # ===================================================================
    # LINE 106: Lowercase letters, numbers, and hyphens (no constraint)
    # ===================================================================
    if ($ln -eq 106) {
        Test-Regex $ln $regex "abc-123"      $true  "valid"
        Test-Regex $ln $regex "ABC"          $false "uppercase not allowed"
    }

    # ===================================================================
    # LINE 107-108: Can't start or end with hyphen
    # ===================================================================
    if ($ln -in 107,108) {
        Test-Regex $ln $regex "abc-123"      $true  "valid"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
    }

    # ===================================================================
    # LINE 109: Can't start/end with hyphen + Can't use consecutive hyphens
    # ===================================================================
    if ($ln -eq 109) {
        Test-Regex $ln $regex "abc-123"      $true  "valid"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
        Test-Regex $ln $regex "a--b"         $false "consecutive hyphens"
    }

    # ===================================================================
    # LINE 110: Can't start/end with hyphen + Consecutive hyphens aren't allowed
    # ===================================================================
    if ($ln -eq 110) {
        Test-Regex $ln $regex "abc-123"      $true  "valid"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
        Test-Regex $ln $regex "a--b"         $false "consecutive hyphens"
    }

    # ===================================================================
    # LINE 111: Can't start/end with hyphens + Can't use consecutive hyphens
    # ===================================================================
    if ($ln -eq 111) {
        Test-Regex $ln $regex "abc-123"      $true  "valid"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
        Test-Regex $ln $regex "a--b"         $false "consecutive hyphens"
    }

    # ===================================================================
    # LINE 112: Start with lowercase letter or number
    # ===================================================================
    if ($ln -eq 112) {
        Test-Regex $ln $regex "abc-123"      $true  "valid"
        Test-Regex $ln $regex "1abc"         $true  "starts with number"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
    }

    # ===================================================================
    # LINE 113: Start with lowercase letter or number + No consecutive hyphens
    # ===================================================================
    if ($ln -eq 113) {
        Test-Regex $ln $regex "abc-123"      $true  "valid"
        Test-Regex $ln $regex "1abc"         $true  "starts with number"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
        Test-Regex $ln $regex "a--b"         $false "consecutive hyphens"
    }

    # ===================================================================
    # LINE 114: Start with lowercase letter or number + begin/end with letter/number + each hyphen preceded/followed by alphanumeric
    # ===================================================================
    if ($ln -eq 114) {
        Test-Regex $ln $regex "abc-123"      $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single char"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
        Test-Regex $ln $regex "a--b"         $false "consecutive hyphens"
    }

    # ===================================================================
    # LINE 115: Start with lowercase letter + End with lowercase letter or number
    # ===================================================================
    if ($ln -eq 115) {
        Test-Regex $ln $regex "abc-123"      $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single letter"
        Test-Regex $ln $regex "1abc"         $false "starts with number"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
    }

    # ===================================================================
    # LINE 116: Lowercase letters, numbers, hyphens, underscores + begin/end letter/number
    # ===================================================================
    if ($ln -eq 116) {
        Test-Regex $ln $regex "abc-123_def"  $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single char"
        Test-Regex $ln $regex "-abc"         $false "starts with hyphen"
        Test-Regex $ln $regex "abc-"         $false "ends with hyphen"
        Test-Regex $ln $regex "a--b"         $false "consecutive hyphens"
    }

    # ===================================================================
    # LINE 117: Must be `ActiveDirectory`
    # ===================================================================
    if ($ln -eq 117) {
        Test-Regex $ln $regex "ActiveDirectory" $true  "exact match"
        Test-Regex $ln $regex "activedirectory" $false "wrong case"
        Test-Regex $ln $regex "Active"          $false "partial match"
    }

    # ===================================================================
    # LINE 118: Must be `current`
    # ===================================================================
    if ($ln -eq 118) {
        Test-Regex $ln $regex "current"      $true  "exact match"
        Test-Regex $ln $regex "Current"      $false "wrong case"
        Test-Regex $ln $regex "current1"     $false "extra chars"
    }

    # ===================================================================
    # LINE 119: Must be `Default`
    # ===================================================================
    if ($ln -eq 119) {
        Test-Regex $ln $regex "Default"      $true  "exact match"
        Test-Regex $ln $regex "default"      $false "wrong case"
    }

    # ===================================================================
    # LINE 120: Must be `default`
    # ===================================================================
    if ($ln -eq 120) {
        Test-Regex $ln $regex "default"      $true  "exact match"
        Test-Regex $ln $regex "Default"      $false "wrong case"
    }

    # ===================================================================
    # LINE 121: Must be a globally unique identifier (GUID)
    # ===================================================================
    if ($ln -eq 121) {
        Test-Regex $ln $regex "550e8400-e29b-41d4-a716-446655440000" $true  "valid GUID"
        Test-Regex $ln $regex "abcdef01-2345-6789-abcd-ef0123456789" $true  "valid GUID lowercase"
        Test-Regex $ln $regex "ABCDEF01-2345-6789-ABCD-EF0123456789" $true  "valid GUID uppercase"
        Test-Regex $ln $regex "not-a-guid"                           $false "invalid GUID"
        Test-Regex $ln $regex "550e8400e29b41d4a716446655440000"     $false "GUID without hyphens"
    }

    # ===================================================================
    # LINE 122: Must be in format: VaultName_KeyName_KeyVersion
    # ===================================================================
    if ($ln -eq 122) {
        Test-Regex $ln $regex "MyVault_MyKey_v1"   $true  "valid format"
        Test-Regex $ln $regex "a_b_c"              $true  "minimal format"
        Test-Regex $ln $regex "abc"                $false "no underscores"
        Test-Regex $ln $regex "a_b"                $false "only two segments"
    }

    # ===================================================================
    # LINE 123: nLowercase letters, numbers, hyphens + Start with letter, end with alphanumeric
    # ===================================================================
    if ($ln -eq 123) {
        Test-Regex $ln $regex "abc-123"      $true  "valid"
        Test-Regex $ln $regex "a"            $true  "single letter"
        Test-Regex $ln $regex "1abc"         $false "starts with number"
    }

    # ===================================================================
    # LINE 124-125: Numbers and periods (version-like)
    # ===================================================================
    if ($ln -in 124,125) {
        Test-Regex $ln $regex "1.2.3.4"      $true  "valid version"
        Test-Regex $ln $regex "123"           $true  "just numbers"
        Test-Regex $ln $regex "abc"           $false "letters not allowed"
    }

    # ===================================================================
    # LINE 126: Only alphanumerics are valid
    # ===================================================================
    if ($ln -eq 126) {
        Test-Regex $ln $regex "abc123"       $true  "valid"
        Test-Regex $ln $regex "abc-def"      $false "hyphen not allowed"
        Test-Regex $ln $regex "abc_def"      $false "underscore not allowed"
    }

    # ===================================================================
    # LINE 127: Should always be $default
    # ===================================================================
    if ($ln -eq 127) {
        Test-Regex $ln $regex '$default'     $true  "exact match with dollar sign"
        Test-Regex $ln $regex "default"      $false "missing dollar sign"
    }

    # ===================================================================
    # LINE 128: Underscores, hyphens, periods, parentheses, letters/digits + Can't end with period
    # ===================================================================
    if ($ln -eq 128) {
        Test-Regex $ln $regex "abc(def)_123" $true  "valid"
        Test-Regex $ln $regex "abc."         $false "ends with period"
        Test-Regex $ln $regex "a"            $true  "single char"
    }

    # ===================================================================
    # LINE 129: Use one of: custom, effective
    # ===================================================================
    if ($ln -eq 129) {
        Test-Regex $ln $regex "custom"       $true  "valid option"
        Test-Regex $ln $regex "effective"    $true  "valid option"
        Test-Regex $ln $regex "other"        $false "invalid option"
        Test-Regex $ln $regex "Custom"       $false "wrong case"
    }

    # ===================================================================
    # LINE 130: Use one of: MCAS, Sentinel, WDATP, WDATP_EXCLUDE_LINUX_PUBLIC_PREVIEW
    # ===================================================================
    if ($ln -eq 130) {
        Test-Regex $ln $regex "MCAS"         $true  "valid option"
        Test-Regex $ln $regex "Sentinel"     $true  "valid option"
        Test-Regex $ln $regex "WDATP"        $true  "valid option"
        Test-Regex $ln $regex "WDATP_EXCLUDE_LINUX_PUBLIC_PREVIEW" $true  "valid option"
        Test-Regex $ln $regex "other"        $false "invalid option"
        Test-Regex $ln $regex "mcas"         $false "wrong case"
    }
}

# ===================================================================
# RESULTS
# ===================================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " SEMANTIC REGEX VERIFICATION REPORT" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Tests:  $totalTests"
Write-Host "Passed:       $passedTests" -ForegroundColor Green
Write-Host "Failed:       $failedTests" -ForegroundColor $(if ($failedTests -eq 0) { "Green" } else { "Red" })
Write-Host "Pass Rate:    $([math]::Round(($passedTests / $totalTests) * 100, 2))%"
Write-Host ""

if ($failedTests -gt 0) {
    Write-Host "============================================" -ForegroundColor Red
    Write-Host " FAILED TESTS" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host ""
    
    foreach ($fail in $failedDetails) {
        Write-Host "  LINE $($fail.Line)" -ForegroundColor Red -NoNewline
        Write-Host " | Regex: $($fail.Regex)"
        Write-Host "    Test: '$($fail.TestValue)' | Expected: $($fail.Expected) | Actual: $($fail.Actual)" -ForegroundColor Yellow
        Write-Host "    Reason: $($fail.Reason)" -ForegroundColor Gray
        Write-Host ""
    }
}

# Save results to file
$report = [PSCustomObject]@{
    Timestamp    = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    TotalTests   = $totalTests
    Passed       = $passedTests
    Failed       = $failedTests
    PassRate     = "$([math]::Round(($passedTests / $totalTests) * 100, 2))%"
    Failures     = $failedDetails
}
$report | ConvertTo-Json -Depth 10 | Out-File -FilePath 'c:\Users\admin\Source\Repos\aznaming.config\config\validChars-regex-verification.json' -Encoding UTF8 -Force

Write-Host "Full verification results saved to config\validChars-regex-verification.json"
