#!/usr/bin/env python3
"""
Simple web server that serves a gallery of the Now in Android app's
screenshot tests on port 3000, so the app's UI is visible in a web preview.

This is a Base44 sandbox helper — it is not part of the Android app itself.
"""
import html
import http.server
import os
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PORT = int(os.environ.get("PORT", "3000"))

# Directories to scan for screenshots, with display labels.
SCREENSHOT_DIRS = [
    ("App Screen Sizes", REPO_ROOT / "app" / "src" / "testDemo" / "screenshots"),
    ("For You Screen", REPO_ROOT / "feature" / "foryou" / "src" / "test" / "screenshots"),
    ("Design System — Background", REPO_ROOT / "core" / "designsystem" / "src" / "test" / "screenshots" / "Background"),
    ("Design System — Buttons", REPO_ROOT / "core" / "designsystem" / "src" / "test" / "screenshots" / "Button"),
    ("Design System — Filter Chips", REPO_ROOT / "core" / "designsystem" / "src" / "test" / "screenshots" / "FilterChip"),
    ("Design System — Icon Buttons", REPO_ROOT / "core" / "designsystem" / "src" / "test" / "screenshots" / "IconButton"),
    ("Design System — Loading Wheel", REPO_ROOT / "core" / "designsystem" / "src" / "test" / "screenshots" / "LoadingWheel"),
    ("Design System — Navigation", REPO_ROOT / "core" / "designsystem" / "src" / "test" / "screenshots" / "Navigation"),
    ("Design System — Tags", REPO_ROOT / "core" / "designsystem" / "src" / "test" / "screenshots" / "Tag"),
    ("Design System — Tabs", REPO_ROOT / "core" / "designsystem" / "src" / "test" / "screenshots" / "Tabs"),
    ("Design System — Top App Bar", REPO_ROOT / "core" / "designsystem" / "src" / "test" / "screenshots" / "TopAppBar"),
]

APK_PATH = REPO_ROOT / "app" / "build" / "outputs" / "apk" / "demo" / "debug" / "app-demo-debug.apk"


def collect_screenshots():
    """Return list of (category, [relative_path, ...])."""
    result = []
    for label, dirpath in SCREENSHOT_DIRS:
        if not dirpath.is_dir():
            continue
        pngs = sorted(dirpath.glob("*.png"), key=lambda p: p.name)
        if not pngs:
            continue
        rels = [str(p.relative_to(REPO_ROOT)) for p in pngs]
        result.append((label, rels))
    return result


def pretty_name(filename):
    """Turn 'compactWidth_compactHeight_showsNavigationBar.png' into something readable."""
    name = Path(filename).stem
    name = name.replace("_", " ")
    # Insert spaces before capital letters that follow lowercase
    name = re.sub(r"([a-z])([A-Z])", r"\1 \2", name)
    return name


def build_html():
    sections = collect_screenshots()
    apk_built = APK_PATH.is_file()

    cards = []
    for label, files in sections:
        thumbs = []
        for f in files:
            name = pretty_name(f)
            thumbs.append(
                f'<div class="card">'
                f'<img loading="lazy" src="/static/{html.escape(f)}" alt="{html.escape(name)}" />'
                f'<span class="caption">{html.escape(name)}</span>'
                f'</div>'
            )
        cards.append(
            f'<section><h2>{html.escape(label)}</h2>'
            f'<div class="grid">{"".join(thumbs)}</div>'
            f'</section>'
        )

    build_badge = (
        '<span class="badge ok">✓ APK built</span>'
        if apk_built
        else '<span class="badge pending">⏳ Build in progress…</span>'
    )

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Now in Android — Preview</title>
<style>
  :root {{
    --bg: #1a1b1f;
    --surface: #2a2b30;
    --primary: #6750a4;
    --on-surface: #e6e1e5;
    --on-surface-dim: #a0a0a8;
    --accent: #d0bcff;
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: var(--bg);
    color: var(--on-surface);
    padding: 24px;
    max-width: 1200px;
    margin: 0 auto;
  }}
  header {{ margin-bottom: 32px; }}
  h1 {{ font-size: 1.75rem; margin-bottom: 8px; }}
  h1 .material {{ color: var(--accent); }}
  .subtitle {{ color: var(--on-surface-dim); font-size: 0.95rem; margin-bottom: 12px; max-width: 700px; line-height: 1.5; }}
  .badges {{ display: flex; gap: 8px; flex-wrap: wrap; }}
  .badge {{
    font-size: 0.8rem; padding: 4px 12px; border-radius: 999px; font-weight: 600;
  }}
  .badge.ok {{ background: #1b5e20; color: #a5d6a7; }}
  .badge.pending {{ background: #4e3c0f; color: #ffe082; }}
  .badge.info {{ background: var(--surface); color: var(--on-surface-dim); }}
  section {{ margin-bottom: 40px; }}
  h2 {{
    font-size: 1.2rem; color: var(--accent); margin-bottom: 16px;
    padding-bottom: 8px; border-bottom: 1px solid var(--surface);
  }}
  .grid {{
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
    gap: 16px;
  }}
  .card {{
    background: var(--surface);
    border-radius: 12px;
    overflow: hidden;
    transition: transform 0.15s;
  }}
  .card:hover {{ transform: scale(1.03); }}
  .card img {{
    width: 100%; display: block; border-bottom: 1px solid rgba(255,255,255,0.06);
    background: #000;
  }}
  .caption {{
    display: block; padding: 8px 12px; font-size: 0.78rem;
    color: var(--on-surface-dim); line-height: 1.3;
  }}
  footer {{
    margin-top: 48px; padding-top: 24px; border-top: 1px solid var(--surface);
    color: var(--on-surface-dim); font-size: 0.82rem; line-height: 1.6;
  }}
  a {{ color: var(--accent); }}
</style>
</head>
<body>
  <header>
    <h1>Now in <span class="material">Android</span></h1>
    <p class="subtitle">
      A fully functional Android app built entirely with Kotlin and Jetpack Compose, following
      Android design and development best practices. This preview shows the app's UI through
      its Roborazzi screenshot tests. The <code>demoDebug</code> variant uses static local data.
    </p>
    <div class="badges">
      {build_badge}
      <span class="badge info">Kotlin 2.3.0 · Jetpack Compose · Material 3</span>
      <span class="badge info">compileSdk 36 · minSdk 23</span>
    </div>
  </header>
  {''.join(cards)}
  <footer>
    <p>This is a native Android application — it cannot run interactively in a web browser.</p>
    <p>The screenshots above are generated by the project's Roborazzi screenshot tests
    (<code>./gradlew verifyRoborazziDemoDebug</code>) and are committed to the repository.</p>
    <p>Source: <a href="https://github.com/android/nowinandroid">github.com/android/nowinandroid</a></p>
  </footer>
</body>
</html>"""


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/" or self.path == "":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            body = build_html().encode()
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        if self.path.startswith("/static/"):
            rel = self.path[len("/static/"):]
            file_path = REPO_ROOT / rel
            # Prevent path traversal
            try:
                file_path = file_path.resolve()
                file_path.relative_to(REPO_ROOT)
            except (ValueError, RuntimeError):
                self.send_error(403)
                return
            if file_path.is_file():
                self.send_response(200)
                self.send_header("Content-Type", "image/png")
                self.send_header("Content-Length", str(file_path.stat().st_size))
                self.end_headers()
                with open(file_path, "rb") as f:
                    self.wfile.write(f.read())
                return
            self.send_error(404)
            return

        self.send_error(404)

    def log_message(self, fmt, *args):
        pass  # quiet


if __name__ == "__main__":
    server = http.server.HTTPServer(("0.0.0.0", PORT), Handler)
    print(f"Now in Android preview server on http://0.0.0.0:{PORT}")
    server.serve_forever()
