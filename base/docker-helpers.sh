#!/bin/bash
# Docker agent run helpers

declare -ag PROJECT_ROOT_NAMES=(
    ".git" ".svn" ".hg" ".bzr" "Makefile"
    "Cargo.toml" "package.json" "go.mod"
    "pyproject.toml" "setup.py" "requirements.txt"
    "composer.json" "Gemfile" "CMakeLists.txt"
    "pom.xml" "build.gradle" "build.sbt"
)

# returns 0 if $1 is inside $HOME
function is_inside_home() {
    case "$1" in
        "$HOME"|"$HOME"/*) return 0;;
    esac
    return 1
}

# returns 0 if the given directory is a project root
function is_project_root() {
    for n in "${PROJECT_ROOT_NAMES[@]}"; do
        if [[ -e "$1/$n" ]]; then return 0; fi
    done
    return 1
}

# extracts the project name from current working directory
function get_project_name() {
    local dir="${1:-$PWD}"
    # walk up to the project root
    while [[ -n $dir && $dir != / ]] && is_inside_home "$dir" && ! is_project_root "$dir"; do
        dir=$(dirname "$dir")
    done
    [[ $dir == '/' ]] && return 1
    local base sub
    base=$(basename "$dir")
    sub=$(realpath -q --relative-to="$dir" "$PWD")
    # strip leading './'
    sub=${sub#./}
    if [[ -n "$sub" && "$sub" != "." ]]; then
        sub=${sub//\//_}
        echo "${base}_${sub}"
    else
        echo "$base"
    fi
}

function docker_add_volume() {
    local hostpath="$1" vol="$2" flags="${3:-}"
    mkdir -p "$hostpath"
    # apply docker auto-created volume owner fix if hostpath inside home
    if is_inside_home "$hostpath"; then
        local exp_uids="$(id -u):$(id -g)"
        if [[ "$(stat -c '%u:%g' "$hostpath")" != "$exp_uids" ]]; then
            sudo chown "$exp_uids" "$hostpath"
        fi
        if [[ -z "$vol" ]]; then
            vol="/home/$DOCKER_USERNAME${hostpath#"$HOME"}"
        fi
    fi
    [[ -n "$vol" ]] || vol="$hostpath"
    DOCKER_ARGS+=(-v "${hostpath}:${vol}${flags:+":$flags"}")
}

