# Terminal colors and output helpers

setup_colors() {
  if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'
  else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=''
    NC=''
  fi
}

info() {
  printf "${BLUE}ℹ${NC} %s\n" "$*"
}

success() {
  printf "${GREEN}✓${NC} %s\n" "$*"
}

warn() {
  printf "${YELLOW}⚠${NC} %s\n" "$*" >&2
}

error() {
  printf "${RED}✗${NC} %s\n" "$*" >&2
}

step() {
  printf "\n${BOLD}→ %s${NC}\n" "$*"
}

# Format a command for display (cyan/bold)
cmd() {
  printf "${BOLD}${BLUE}%s${NC}" "$1"
}

# Initialize colors on source
setup_colors
