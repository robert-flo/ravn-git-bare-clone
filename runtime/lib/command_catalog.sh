#!/usr/bin/env bash

if [[ ${RAVN_GIT_BARE_CLONE_COMMAND_CATALOG_LOADED:-0} == 1 ]]; then
  return 0
fi
readonly RAVN_GIT_BARE_CLONE_COMMAND_CATALOG_LOADED=1

# Load the language-neutral command contract shared by dispatch, menu, help,
# and shell completion. Fields: canonical<TAB>aliases<TAB>label<TAB>description<TAB>icon<TAB>menu<TAB>options.
RAVN_GIT_BARE_CLONE_COMMAND_CATALOG_DIR=""
RAVN_GIT_BARE_CLONE_COMMAND_CATALOG_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly RAVN_GIT_BARE_CLONE_COMMAND_CATALOG_DIR
readonly RAVN_GIT_BARE_CLONE_COMMAND_CATALOG_FILE="${RAVN_GIT_BARE_CLONE_COMMAND_CATALOG_FILE:-$RAVN_GIT_BARE_CLONE_COMMAND_CATALOG_DIR/../commands.tsv}"
# shellcheck disable=SC2034 # Public catalog consumed by sourced capabilities.
RAVN_GIT_BARE_CLONE_COMMAND_CATALOG=()
while IFS= read -r catalog_record || [[ -n $catalog_record ]]; do
  [[ -z $catalog_record || ${catalog_record:0:1} == "#" ]] && continue
  RAVN_GIT_BARE_CLONE_COMMAND_CATALOG+=("$catalog_record")
done < "$RAVN_GIT_BARE_CLONE_COMMAND_CATALOG_FILE"
readonly RAVN_GIT_BARE_CLONE_COMMAND_CATALOG

command_catalog_get() {
  local lookup="$1"
  local requested_field="$2"
  local record=""
  local canonical=""
  local aliases=""
  local label=""
  local description=""
  local icon=""
  local menu=""
  local options=""
  local value=""

  for record in "${RAVN_GIT_BARE_CLONE_COMMAND_CATALOG[@]}"; do
    IFS=$'\t' read -r canonical aliases label description icon menu options <<< "$record"
    if [[ $canonical == "$lookup" || " $aliases " == *" $lookup "* ]]; then
      case "$requested_field" in
        canonical) value="$canonical" ;;
        aliases) value="$aliases" ;;
        label) value="$label" ;;
        description) value="$description" ;;
        icon) value="$icon" ;;
        menu) value="$menu" ;;
        options) value="$options" ;;
        module) value="$canonical" ;;
        *)
          RAVN_GIT_BARE_CLONE_COMMAND_CATALOG_ERROR="Unknown metadata field: $requested_field"
          return 1
          ;;
      esac
      # shellcheck disable=SC2034 # Read by caller in the same shell.
      RAVN_GIT_BARE_CLONE_COMMAND_CATALOG_VALUE="$value"
      return 0
    fi
  done

  # shellcheck disable=SC2034 # Read by caller in the same shell.
  RAVN_GIT_BARE_CLONE_COMMAND_CATALOG_ERROR="Unknown command: $lookup"
  return 1
}

command_catalog_list() {
  local include_menu="$1"
  local record=""
  local canonical=""
  local aliases=""
  local label=""
  local description=""
  local icon=""
  local menu=""
  local options=""

  for record in "${RAVN_GIT_BARE_CLONE_COMMAND_CATALOG[@]}"; do
    IFS=$'\t' read -r canonical aliases label description icon menu options <<< "$record"
    if [[ $include_menu == all || $menu == 1 ]]; then
      printf '%s\n' "$canonical"
    fi
  done
}

command_catalog_completion_words() {
  local record=""
  local canonical=""
  local aliases=""
  local label=""
  local description=""
  local icon=""
  local menu=""
  local options=""

  for record in "${RAVN_GIT_BARE_CLONE_COMMAND_CATALOG[@]}"; do
    IFS=$'\t' read -r canonical aliases label description icon menu options <<< "$record"
    printf '%s %s\n' "$canonical" "$aliases"
  done
}
