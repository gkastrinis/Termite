package terminal

// Named ANSI styles shared by terminal output across packages.
RESET :: "\x1b[0m"

ERROR       :: "\x1b[31m"
ERROR_LABEL :: "\x1b[41m"
HINT        :: "\x1b[33m"
FILE        :: "\x1b[36m"
LOCATION    :: "\x1b[38;5;250m"
TOKEN_KIND  :: "\x1b[33m"
TOKEN_VALUE :: "\x1b[35m"

DEBUG_INT    :: "\x1b[32m"
DEBUG_STRING :: "\x1b[32m"
DEBUG_NAME   :: "\x1b[95m"
DEBUG_OP     :: "\x1b[33m"
DEBUG_LOOKUP :: "\x1b[34m"
DEBUG_GROUP  :: "\x1b[35m"
DEBUG_META   :: "\x1b[36m"

PAREN_COLORS :: [6]string{
	"\x1b[0m", "\x1b[92m", "\x1b[95m",
	"\x1b[38;5;250m", "\x1b[93m", "\x1b[96m",
}

RULE_ID    :: "\x1b[40m"
RULE_ARROW :: "\x1b[45m"
