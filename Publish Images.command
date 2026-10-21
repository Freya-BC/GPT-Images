#!/bin/zsh
# Double-click this file to upload new images and refresh GitHub Pages.
set -euo pipefail

cd "$(dirname "$0")"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

PAGES_BASE="https://freya-bc.github.io/GPT-Images"
SITE_TITLE="GPT-Images"

red=$'\033[31m'
green=$'\033[32m'
cyan=$'\033[36m'
reset=$'\033[0m'

echo
echo "${cyan}=== GPT-Images publish ===${reset}"
echo "Folder: $(pwd)"
echo

if ! command -v git >/dev/null 2>&1; then
  echo "${red}git is not installed.${reset}"
  read -k 1 "?Press any key to close…"
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "${red}GitHub CLI (gh) is not installed. Run: brew install gh${reset}"
  read -k 1 "?Press any key to close…"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "${red}Not logged in to GitHub CLI. Run: gh auth login${reset}"
  read -k 1 "?Press any key to close…"
  exit 1
fi

gh auth setup-git >/dev/null 2>&1 || true

# Collect image files in this folder (ignore junk)
images=()
for f in *.(png|jpg|jpeg|webp|gif|PNG|JPG|JPEG|WEBP|GIF)(N); do
  [[ -f "$f" ]] || continue
  [[ "$f" == .* ]] && continue
  images+=("$f")
done

if (( ${#images[@]} == 0 )); then
  echo "${red}No image files found in this folder.${reset}"
  read -k 1 "?Press any key to close…"
  exit 1
fi

# Stable sort
images=("${(@o)images}")

label_for() {
  local name="$1"
  name="${name%.*}"
  name="${name#Folkvangr_}"
  name="${name#Folkvangr-}"
  name="${name//_/ }"
  # Title-case-ish: keep as-is after underscore→space (filenames are already readable)
  print -r -- "$name"
}

echo "Found ${#images[@]} image(s):"
for f in "${images[@]}"; do
  echo "  • $f"
done
echo

# --- regenerate index.html ---
{
  cat <<'HTML_HEAD'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>GPT-Images</title>
  <style>
    :root {
      color-scheme: dark;
      --bg: #12100e;
      --panel: #1c1916;
      --text: #f3ece3;
      --muted: #b8aea2;
      --accent: #d4a574;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: Georgia, "Times New Roman", serif;
      background: var(--bg);
      color: var(--text);
    }
    header {
      padding: 2.5rem 1.5rem 1rem;
      max-width: 1200px;
      margin: 0 auto;
    }
    h1 {
      margin: 0 0 0.4rem;
      font-weight: 600;
      letter-spacing: 0.04em;
    }
    p {
      margin: 0;
      color: var(--muted);
    }
    code {
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 0.9em;
      color: var(--accent);
      word-break: break-all;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
      gap: 1.25rem;
      max-width: 1200px;
      margin: 0 auto;
      padding: 1.5rem;
    }
    figure {
      margin: 0;
      background: var(--panel);
      border-radius: 12px;
      overflow: hidden;
    }
    img {
      display: block;
      width: 100%;
      aspect-ratio: 16 / 10;
      object-fit: cover;
      background: #000;
    }
    figcaption {
      padding: 0.9rem 1rem 1.1rem;
    }
    figcaption strong {
      display: block;
      margin-bottom: 0.35rem;
    }
    button {
      margin-top: 0.7rem;
      background: transparent;
      color: var(--accent);
      border: 1px solid var(--accent);
      border-radius: 999px;
      padding: 0.35rem 0.8rem;
      cursor: pointer;
      font: inherit;
      font-size: 0.9rem;
    }
    button:hover { background: rgba(212, 165, 116, 0.15); }
  </style>
</head>
<body>
  <header>
    <h1>GPT-Images</h1>
    <p>Folkvangr backgrounds hosted on GitHub Pages. Use the <code>github.io</code> URL for faster loading than raw GitHub.</p>
  </header>
  <main class="grid" id="gallery"></main>
  <script>
    const images = [
HTML_HEAD

  first=1
  for f in "${images[@]}"; do
    label="$(label_for "$f")"
    # Escape for JS string
    js_file="${f//\\/\\\\}"
    js_file="${js_file//\"/\\\"}"
    js_label="${label//\\/\\\\}"
    js_label="${js_label//\"/\\\"}"
    if (( first )); then
      first=0
    else
      print -r -- ","
    fi
    printf '      ["%s", "%s"]' "$js_file" "$js_label"
  done
  print

  cat <<'HTML_TAIL'
    ];
    const base = new URL(".", location.href).href;
    const gallery = document.getElementById("gallery");
    for (const [file, label] of images) {
      const url = new URL(file, base).href;
      const figure = document.createElement("figure");
      figure.innerHTML = `
        <img src="${file}" alt="${label}" loading="lazy" decoding="async">
        <figcaption>
          <strong>${label}</strong>
          <code>${url}</code>
          <div><button type="button">Copy URL</button></div>
        </figcaption>
      `;
      figure.querySelector("button").addEventListener("click", async () => {
        await navigator.clipboard.writeText(url);
        figure.querySelector("button").textContent = "Copied";
        setTimeout(() => { figure.querySelector("button").textContent = "Copy URL"; }, 1200);
      });
      gallery.appendChild(figure);
    }
  </script>
</body>
</html>
HTML_TAIL
} > index.html

# --- regenerate README.md ---
{
  print -r -- "# ${SITE_TITLE}"
  print
  print -r -- "Folkvangr backgrounds, published on GitHub Pages for faster loading than raw GitHub."
  print
  print -r -- "**Site:** ${PAGES_BASE}/"
  print
  print -r -- "Double-click \`Publish Images.command\` after adding new images to upload them and refresh the gallery."
  print
  print -r -- "| Image | Pages URL |"
  print -r -- "|---|---|"
  for f in "${images[@]}"; do
    label="$(label_for "$f")"
    # Escape pipes in markdown table cells
    md_label="${label//|/\\|}"
    print -r -- "| ${md_label} | ${PAGES_BASE}/${f} |"
  done
  print
} > README.md

# Ensure Pages serves files as-is
touch .nojekyll

echo "${green}Updated gallery (index.html) and README.md${reset}"
echo

# Stage images + generated site files (+ this publisher)
git add -- "${images[@]}" index.html README.md .nojekyll "Publish Images.command"
# Drop deleted images from the repo if you removed files locally
git add -u -- .

if git diff --cached --quiet; then
  echo "Nothing new to upload — everything is already on GitHub."
  echo
  echo "Site: ${PAGES_BASE}/"
  echo
  read -k 1 "?Press any key to close…"
  exit 0
fi

echo "Changes to upload:"
git --no-pager diff --cached --stat
echo

commit_msg="Publish images $(date '+%Y-%m-%d %H:%M')"
git commit -m "$commit_msg"

echo
echo "Pushing to GitHub…"
git push origin HEAD

echo
echo "${green}Done.${reset} GitHub Pages will rebuild in about a minute."
echo "Gallery: ${PAGES_BASE}/"
echo
read -k 1 "?Press any key to close…"
