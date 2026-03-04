* Line 73 in validChars.txt
* Endpoints
* Manual overrides
* Saving/loading abbreviations
* Further investigation for fully automated pipeline using copilot cli
  / Use existing script for TODOs in combination with pull request
* DONE: Output how many abbrevations that needs to be resolved
* DONE: Output how many checkname endpoints that needs to be resolved
* DONE: Regex "^(?![_])[^~!@#$%\\^&*()=+_[\\]{}\\\\|\\s\\x00-\\x1F]{1,15}(?<![.\\-])$" - Fixed to handle "Can't use spaces, control characters, or these characters: ~ ! @ # $ % ^ & * ( ) = + _ [ ] { } \ | ; : . ' " , < > / ?" and "Can't start with underscore. Can't end with period or hyphen."
  - Fixed rule ordering (Cant_UseSpacesControlChars before Cant_UseExcluded)
  - Fixed HTML tag stripping to preserve angle brackets < >
  - Disabled backtick stripping to preserve forbidden character lists
  - Added backtick-aware sentence splitting
  - Improved character extraction and regex building
* Check rules as "Must be in format:"
* DONE: Output number of files generated