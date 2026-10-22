#!/bin/sh
# Helper for the wallhub picker. Subcommands: list | gen | thumb <kind> <src> <dst> | current
DIR="${WALLHUB_DIR:-$HOME/Pictures/Walpappers}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/noctalia/wallpaper-hub/thumbs3"

thumb_path() {
  safe=$(printf %s "$1" | LC_ALL=C sed 's/[^A-Za-z0-9]/_/g')
  [ ${#safe} -gt 150 ] && safe=$(printf %s "$safe" | tail -c 150)
  printf '%s/%s.jpg' "$CACHE" "$safe"
}

files() {
  find "$DIR" -maxdepth 3 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.avif' \
    -o -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' -o -iname '*.mov' -o -iname '*.gif' \) 2>/dev/null | LC_ALL=C sort -f -V
}

kind_of() {
  case "$(printf %s "$1" | tr 'A-Z' 'a-z')" in
    *.mp4|*.mkv|*.webm|*.mov|*.gif) echo video ;;
    *) echo image ;;
  esac
}

# kind|path|thumb for every wallpaper, in one awk pass (no per-file forks).
list_all() {
  files | CACHE="$CACHE" LC_ALL=C awk '{
    f=$0; l=tolower(f)
    k = (l ~ /\.(mp4|mkv|webm|mov|gif)$/) ? "video" : "image"
    s=f; gsub(/[^A-Za-z0-9]/, "_", s)
    if (length(s) > 150) s = substr(s, length(s) - 149)
    print k "|" f "|" ENVIRON["CACHE"] "/" s ".jpg"
  }'
}

case "$1" in
  list)
    list_all
    ;;
  thumb)
    kind="$2"; src="$3"; dst="$4"
    mkdir -p "$CACHE"
    if [ "$kind" = video ]; then
      nice -n 19 ffmpeg -y -loglevel error -ss 1 -i "$src" -frames:v 1 -vf scale=960:-2 "$dst" >/dev/null 2>&1 \
        || nice -n 19 ffmpeg -y -loglevel error -i "$src" -frames:v 1 -vf scale=960:-2 "$dst" >/dev/null 2>&1
    else
      nice -n 19 magick "${src}[0]" -thumbnail '960x960>' "$dst" >/dev/null 2>&1
    fi
    ;;
  gen)
    mkdir -p "$CACHE"
    before=$("$0" missing | wc -l)
    list_all | while IFS='|' read -r k f t; do
      [ -s "$t" ] || printf '%s\0%s\0%s\0' "$k" "$f" "$t"
    done | xargs -0 -r -n3 -P4 "$0" thumb
    after=$("$0" missing | wc -l)
    echo $((before - after))   # thumbnails actually created
    ;;
  missing)
    list_all | while IFS='|' read -r k f t; do
      [ -s "$t" ] || echo "$f"
    done
    ;;
  banner)
    # Thumbnail of the current wallpaper (made on demand), for the launcher banner.
    cur=$("$0" current); [ -n "$cur" ] || exit 0
    t=$(thumb_path "$cur")
    [ -s "$t" ] || "$0" thumb "$(kind_of "$cur")" "$cur" "$t"
    echo "$t"
    ;;
  current)
    A="$HOME/.local/state/noctalia/mpvpaper/assignments.json"
    v=""
    [ -f "$A" ] && v=$(jq -r '(.assignments // {}) | (.["*"] // (to_entries | .[0].value) // empty)' "$A" 2>/dev/null)
    if [ -n "$v" ]; then echo "$v"; else noctalia msg wallpaper-get 2>/dev/null | head -1; fi
    ;;
esac
