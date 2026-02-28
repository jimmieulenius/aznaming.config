* Line 73 in validChars.txt
* Endpoints
* Manual overrides
* Saving/loading abbreviations
* Further investigation for fully automated pipeline using copilot cli
  / Use existing script for TODOs in combination with pull request
* Output how many abbrevations that needs to be resolved
* Output how many checkname endpoints that needs to be resolved
* Regex "^(?![_])[^~!@#$%\\^&*()=+_[\\]{}\\\\|\\s\\x00-\\x1F]{1,15}(?<![.\\-])$" is not correct according to "Can't use spaces, control characters, or these characters:<br> `~ ! @ # $ % ^ & * ( ) = + _ [ ] { } \\ | ; : . ' \" , < > / ?`<br><br>Can't start with underscore. Can't end with period or hyphen." (same as line 73 in validChars.txt).