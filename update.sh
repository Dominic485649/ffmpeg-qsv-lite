#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${ROOT:-$HOME/ffmpeg}"
FFMPEG_REF="${FFMPEG_REF:-n8.1.2}"

# 只保留 QSV 目标实际需要的源码：FFmpeg、libvpl、fdk-aac、AudioToolboxWrapper、dav1d
declare -A URLS=(
  [ffmpeg-source]="https://git.ffmpeg.org/ffmpeg.git"
  [libvpl]="https://github.com/intel/libvpl.git"
  [fdk-aac]="https://github.com/mstorsjo/fdk-aac.git"
  [AudioToolboxWrapper]="https://github.com/dantmnf/AudioToolboxWrapper.git"
  [dav1d]="https://code.videolan.org/videolan/dav1d.git"
)

declare -A TAG_REGEX=(
  [ffmpeg-source]='^n[0-9]+(\.[0-9]+)*$'
  [libvpl]='^v2\.[0-9]+(\.[0-9]+)*$'
  [fdk-aac]='^v?[0-9]+(\.[0-9]+)*$'
  [AudioToolboxWrapper]='.*'
  [dav1d]='^[0-9]+(\.[0-9]+)*$'
)

normalize_version() {
  local repo="$1"
  local tag="$2"

  case "$repo" in
    ffmpeg-source|libvpl)
      echo "${tag#n}"
      ;;
    *)
      echo "${tag#v}"
      ;;
  esac
}

clone_if_missing() {
  local name="$1"
  local repo_dir="$ROOT/$name"
  local url="${URLS[$name]}"

  if [[ ! -d "$repo_dir/.git" ]]; then
    echo "===> clone $name from $url"
    git clone "$url" "$repo_dir"
  fi
}

latest_stable_tag() {
  local name="$1"
  local repo_dir="$ROOT/$name"
  local regex="${TAG_REGEX[$name]}"

  git -C "$repo_dir" for-each-ref --format='%(refname:short)' refs/tags \
    | sed 's/\^{}$//' \
    | sort -u \
    | { grep -E "$regex" || true; } \
    | while read -r tag; do
        printf "%s\t%s\n" "$(normalize_version "$name" "$tag")" "$tag"
      done \
    | sort -V \
    | tail -n 1 \
    | cut -f2
}

sanitize_repo() {
  local repo_dir="$1"
  git -C "$repo_dir" reset --hard
  git -C "$repo_dir" clean -fdx
}

checkout_stable() {
  local name="$1"
  local repo_dir="$ROOT/$name"
  local tag="$2"
  local ver
  ver="$(normalize_version "$name" "$tag")"

  if [[ "$name" == "ffmpeg-source" ]]; then
    git -C "$repo_dir" branch -D "build-$ver" 2>/dev/null || true
    git -C "$repo_dir" switch -C "build-$ver" "$tag"
  else
    git -C "$repo_dir" switch --detach "$tag" 2>/dev/null || \
    git -C "$repo_dir" checkout --detach "$tag"
  fi

  git -C "$repo_dir" submodule update --init --recursive || true
  
  local commit_hash
  commit_hash="$(git -C "$repo_dir" rev-parse HEAD)"
  local remote_url
  remote_url="$(git -C "$repo_dir" remote get-url origin)"
  echo "     -> $name: source=$remote_url, ref=$tag, commit=$commit_hash"
}

update_one() {
  local name="$1"
  local repo_dir="$ROOT/$name"

  clone_if_missing "$name"

  echo "===> sanitize $name"
  sanitize_repo "$repo_dir"

  # Force remote to HTTPS to avoid SSH timeouts
  local url="${URLS[$name]}"
  git -C "$repo_dir" remote set-url origin "$url" 2>/dev/null || true

  echo "===> fetch $name"
  git -C "$repo_dir" fetch --tags --prune origin

  local tag=""
  if [[ "$name" == "ffmpeg-source" ]]; then
    tag="$FFMPEG_REF"
  else
    tag="$(latest_stable_tag "$name")"
  fi

  if [[ -z "$tag" ]]; then
    # Fallback to master/main for tagless repositories like AudioToolboxWrapper
    tag="master"
    if ! git -C "$repo_dir" show-ref --verify --quiet "refs/remotes/origin/$tag"; then
      tag="main"
    fi
    echo "No stable tag matched for $name, falling back to branch $tag"
  fi

  checkout_stable "$name" "$tag"
}

usage() {
  cat <<EOF
用法:
  ./update.sh           # 更新完整 FFmpeg 构建 QSV 版所需源码
EOF
}

main() {
  mkdir -p "$ROOT"

  local repos=(
    ffmpeg-source
    libvpl
    fdk-aac
    AudioToolboxWrapper
    dav1d
  )

  if [[ "$#" -gt 0 ]]; then
    usage
    exit 1
  fi

  for r in "${repos[@]}"; do
    update_one "$r"
  done

  echo
  echo "All selected source trees are now on latest stable tags or branches."
}

main "$@"
