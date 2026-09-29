_journal_file() {
  local today=$(date +%Y-%m-%d) year=$(date +%Y) month=$(date +%m) dayname=$(date +%A)
  local dir="$HOME/notes/$year/$month" file="$dir/$today.md"
  if [[ ! -f "$file" ]]; then
    mkdir -p "$dir"
    printf "# %s - %s\n\n## Notes\n\n## Todos\n" "$today" "$dayname" > "$file"
  fi
  echo "$file"
}
note() {
  [[ -z "$*" ]] && echo "Usage: note <text>" && return 1
  local file=$(_journal_file) ts=$(date +%H:%M)
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' "/^## Todos$/i\\
- [$ts] $*
" "$file"
  else
    sed -i "/^## Todos$/i\\- [$ts] $*" "$file"
  fi
  echo "Note added: [$ts] $*"
}
todo() {
  if [[ "${1:-}" =~ ^-([0-9]+)$ ]]; then local n="${BASH_REMATCH[1]:-${match[1]}}"; shift; _todo_status "$n" "$@"; return; fi
  [[ -z "$*" ]] && echo "Usage: todo <text>" && return 1
  echo "- [TODO] $*" >> "$(_journal_file)"
  echo "Todo added: $*"
}
todos() {
  local file=$(_journal_file) num=0
  grep -n '^\- \[' "$file" | grep -E '\[(TODO|DONE|IN_PROGRESS|BLOCKED)\]' | while IFS= read -r line; do
    num=$((num + 1))
    local c=""; [[ "$line" == *'[TODO]'* ]] && c="\033[33m"; [[ "$line" == *'[IN_PROGRESS]'* ]] && c="\033[34m"
    [[ "$line" == *'[DONE]'* ]] && c="\033[32m"; [[ "$line" == *'[BLOCKED]'* ]] && c="\033[31m"
    echo -e "  ${c}${num}. ${line#*:}\033[0m"
  done
}
_todo_status() {
  local num="$1" new_status="${2^^}"
  [[ -z "$new_status" ]] && echo "Statuses: todo, done, in_progress, blocked" && return 1
  case "$new_status" in TODO|DONE|IN_PROGRESS|BLOCKED) ;; *) echo "Invalid: $new_status"; return 1;; esac
  local file=$(_journal_file) tmp=$(mktemp)
  awk -v n="$num" -v s="$new_status" '/^- \[(TODO|DONE|IN_PROGRESS|BLOCKED)\]/{c++;if(c==n)sub(/\[(TODO|DONE|IN_PROGRESS|BLOCKED)\]/,"["s"]")}{print}' "$file" > "$tmp" && mv "$tmp" "$file"
  echo "Todo #$num -> [$new_status]"
}
alias journal='vim $(_journal_file)'
