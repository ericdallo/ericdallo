#!/usr/bin/env bash
# Renders the README tiles (live downloads and stars) and contact buttons, in dark and light variants.
set -euo pipefail
cd "$(dirname "$0")"

FONT="-apple-system,BlinkMacSystemFont,'Segoe UI','Noto Sans',Helvetica,Arial,sans-serif"

gh_api() {
  curl -sfL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "https://api.github.com/$1"
}

stars() {
  gh_api "repos/$1" | jq .stargazers_count
}

release_downloads() {
  local total=0 page=1 json
  while :; do
    json=$(gh_api "repos/$1/releases?per_page=100&page=$page") || return 1
    [ "$(jq length <<<"$json")" -eq 0 ] && break
    total=$((total + $(jq '[.[].assets[].download_count] | add // 0' <<<"$json")))
    page=$((page + 1))
  done
  echo "$total"
}

melpa_downloads() {
  jq ".\"$1\"" <<<"$MELPA"
}

human() {
  awk -v n="$1" 'BEGIN {
    if (n >= 1e6) s = sprintf("%.1fM", n / 1e6)
    else if (n >= 1e4) s = sprintf("%.0fk", n / 1e3)
    else if (n >= 1e3) s = sprintf("%.1fk", n / 1e3)
    else s = n
    sub(/\.0/, "", s)
    print s
  }'
}

logo_file() {
  local f
  for f in logos/"$1"-"$2".* logos/"$1".*; do
    [ -e "$f" ] && { echo "$f"; return; }
  done
  echo "no logo for $1" >&2
  return 1
}

data_uri() {
  local mime=image/png
  [[ $1 == *.svg ]] && mime=image/svg+xml
  printf 'data:%s;base64,%s' "$mime" "$(base64 -w0 "$1")"
}

theme() {
  case "$1" in
    dark) BG="#151b23" BORDER="#30363d" FG="#e6edf3" MUTED="#8b949e" NUM_FROM="#bd93f9" NUM_TO="#ff79c6" STAR="#f1fa8c" GLOW_OPACITY=".32" ;;
    light) BG="#ffffff" BORDER="#d0d7de" FG="#1f2328" MUTED="#59636e" NUM_FROM="#8250df" NUM_TO="#bf3989" STAR="#bf8700" GLOW_OPACITY=".18" ;;
  esac
}

tile() {
  local id=$1 name=$2 glow=$3 repo=$4 source=$5 downloads stars mode logo
  if [[ $source == melpa:* ]]; then downloads=$(melpa_downloads "${source#melpa:}"); else downloads=$(release_downloads "$repo"); fi
  stars=$(stars "$repo")
  [[ $downloads =~ ^[0-9]+$ && $stars =~ ^[0-9]+$ ]] || { echo "could not fetch counts for $id" >&2; return 1; }
  for mode in dark light; do
    theme "$mode"
    logo=$(logo_file "$id" "$mode")
    cat >"tile-$id-$mode.svg" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="192" height="208" viewBox="0 0 192 208" font-family="$FONT">
  <defs>
    <radialGradient id="glow" cx="50%" cy="24%" r="62%">
      <stop offset="0" stop-color="$glow" stop-opacity="$GLOW_OPACITY"/>
      <stop offset="1" stop-color="$glow" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="num" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="$NUM_FROM"/>
      <stop offset="1" stop-color="$NUM_TO"/>
    </linearGradient>
  </defs>
  <g transform="translate(4 0)">
    <rect x=".5" y=".5" width="183" height="207" rx="17.5" fill="$BG"/>
    <rect x=".5" y=".5" width="183" height="207" rx="17.5" fill="url(#glow)" stroke="$BORDER"/>
    <image href="$(data_uri "$logo")" x="24" y="26" width="136" height="56" preserveAspectRatio="xMidYMid meet"/>
    <text x="92" y="130" text-anchor="middle" font-size="34" font-weight="700" fill="url(#num)">$(human "$downloads")</text>
    <text x="92" y="150" text-anchor="middle" font-size="10" font-weight="600" letter-spacing="2" fill="$MUTED">DOWNLOADS</text>
    <line x1="18" y1="168.5" x2="166" y2="168.5" stroke="$BORDER"/>
    <text x="18" y="191" font-size="13.5" font-weight="600" fill="$FG">$name</text>
    <text x="166" y="191" text-anchor="end" font-size="12.5" fill="$MUTED"><tspan fill="$STAR">★</tspan> $(human "$stars")</text>
  </g>
</svg>
EOF
  done
}

contact() {
  local id=$1 icon=$2 mode
  for mode in dark light; do
    theme "$mode"
    cat >"contact-$id-$mode.svg" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="56" height="44" viewBox="0 0 56 44" color="$FG">
  <circle cx="28" cy="22" r="21.5" fill="$BG" stroke="$BORDER"/>
  <g transform="translate(19 13) scale(.75)" fill="currentColor">$icon</g>
</svg>
EOF
  done
}

MELPA=$(curl -sfL https://melpa.org/download_counts.json)

tile clojure-lsp clojure-lsp "#8fb5fe" clojure-lsp/clojure-lsp releases
tile eca ECA "#14b8c8" editor-code-assistant/eca releases
tile lsp-mode lsp-mode "#a77bf3" emacs-lsp/lsp-mode melpa:lsp-mode
tile lsp-dart lsp-dart "#29b6f6" emacs-lsp/lsp-dart melpa:lsp-dart

contact website '<g fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><ellipse cx="12" cy="12" rx="4" ry="10"/><path d="M2 12h20"/></g>'
contact x '<path d="M14.234 10.162 22.977 0h-2.072l-7.591 8.824L7.251 0H.258l9.168 13.343L.258 24H2.33l8.016-9.318L16.749 24h6.993zm-2.837 3.299-.929-1.329L3.076 1.56h3.182l5.965 8.532.929 1.329 7.754 11.09h-3.182z"/>'
contact linkedin '<path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/>'
contact sponsors '<path d="M17.625 1.499c-2.32 0-4.354 1.203-5.625 3.03-1.271-1.827-3.305-3.03-5.625-3.03C3.129 1.499 0 4.253 0 8.249c0 4.275 3.068 7.847 5.828 10.227a33.14 33.14 0 0 0 5.616 3.876l.028.017.008.003-.001.003c.163.085.342.126.521.125.179.001.358-.041.521-.125l-.001-.003.008-.003.028-.017a33.14 33.14 0 0 0 5.616-3.876C20.932 16.096 24 12.524 24 8.249c0-3.996-3.129-6.75-6.375-6.75zm-.919 15.275a30.766 30.766 0 0 1-4.703 3.316l-.004-.002-.004.002a30.955 30.955 0 0 1-4.703-3.316c-2.677-2.307-5.047-5.298-5.047-8.523 0-2.754 2.121-4.5 4.125-4.5 2.06 0 3.914 1.479 4.544 3.684.143.495.596.797 1.086.796.49.001.943-.302 1.085-.796.63-2.205 2.484-3.684 4.544-3.684 2.004 0 4.125 1.746 4.125 4.5 0 3.225-2.37 6.216-5.048 8.523z"/>'
contact patreon '<path d="M22.957 7.21c-.004-3.064-2.391-5.576-5.191-6.482-3.478-1.125-8.064-.962-11.384.604C2.357 3.231 1.093 7.391 1.046 11.54c-.039 3.411.302 12.396 5.369 12.46 3.765.047 4.326-4.804 6.068-7.141 1.24-1.662 2.836-2.132 4.801-2.618 3.376-.836 5.678-3.501 5.673-7.031Z"/>'
