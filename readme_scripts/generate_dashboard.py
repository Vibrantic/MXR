#!/usr/bin/env python3
"""Regenerate readme/dashboard.svg with fresh star/fork/watcher counts.

Stdlib only. Only rewrites the file when the counts actually changed,
so the scheduled workflow doesn't create noise commits.
"""
import datetime
import json
import os
import re
import sys
import urllib.request
from pathlib import Path
from xml.sax.saxutils import escape

REPO = os.environ.get("GITHUB_REPOSITORY", "Vibrantic/MXR")
OUT = Path(__file__).resolve().parent.parent / "readme" / "dashboard.svg"

W, H, TOP = 720, 330, 36
FONT = "'Courier New', Consolas, 'DejaVu Sans Mono', monospace"
BR, MID, DIM = "#00ff66", "#00cc52", "#00913a"
PROMPT = "operator@lindos:~$".replace(" ", "&#160;") + "&#160;"


def fetch_counts():
    req = urllib.request.Request(
        f"https://api.github.com/repos/{REPO}",
        headers={"Accept": "application/vnd.github+json", "User-Agent": "mxr-dashboard"},
    )
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req, timeout=20) as r:
        d = json.load(r)
    return d["stargazers_count"], d["forks_count"], d["subscribers_count"]


def render(stars, forks, watchers, date):
    cols = [24, 252, 480]
    heads = ["SYSTEM / METADATA", "REPOSITORY METRICS", "CONNECTION & STATE"]
    data = [
        [("MXR", "TERMINAL RPG"), ("VERSION", "ALPHA 0.0.1"), ("ENGINE", "GODOT 4.7.2")],
        [("STARS", str(stars)), ("FORKS", str(forks)), ("WATCHERS", str(watchers))],
        [("LINDOS", "ONLINE"), ("CONNECTION", "ROGAN"), ("STATE", "ACTIVE DEV")],
    ]
    cw, pad, bh = 7.4, 10, 26
    out, defs, n = [], "", 0

    for x, h in zip(cols, heads):
        out.append(f'<text x="{x}" y="112" fill="{BR}" font-weight="bold" font-size="13">{escape(h)}</text>')
    out.append(f'<line x1="24" y1="122" x2="{W-24}" y2="122" stroke="{BR}" stroke-opacity="0.6" stroke-dasharray="4 4"/>')

    for c, x in enumerate(cols):
        for r, (k, v) in enumerate(data[c]):
            y = 140 + r * 42
            lw, vw = len(k) * cw + 2 * pad, len(v) * cw + 2 * pad
            n += 1
            defs += f'<clipPath id="b{n}"><rect x="{x}" y="{y}" width="{lw+vw:.1f}" height="{bh}" rx="4"/></clipPath>'
            out.append(
                f'<g clip-path="url(#b{n})"><rect x="{x}" y="{y}" width="{lw:.1f}" height="{bh}" fill="#0a2614"/>'
                f'<rect x="{x+lw:.1f}" y="{y}" width="{vw:.1f}" height="{bh}" fill="{BR}"/></g>'
                f'<rect x="{x}" y="{y}" width="{lw+vw:.1f}" height="{bh}" rx="4" fill="none" stroke="{BR}"/>'
                f'<text x="{x+pad}" y="{y+17}" fill="{MID}" font-weight="bold" font-size="12">{escape(k)}</text>'
                f'<text x="{x+lw+pad:.1f}" y="{y+17}" fill="#0d1117" font-weight="bold" font-size="12">{escape(v)}</text>'
            )

    cursor_x = 24 + len("operator@lindos:~$ ") * 8.4
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" data-counts="{stars},{forks},{watchers}" role="img" aria-label="MXR dashboard: Terminal RPG, Alpha 0.0.1, Godot 4.7.2, {stars} stars, {forks} forks, {watchers} watchers, LindOS online, connection ROGAN, state active dev">
  <defs>
    <filter id="glow" x="-5%" y="-5%" width="110%" height="110%"><feGaussianBlur stdDeviation="3" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
    <clipPath id="clip"><rect x="2" y="2" width="{W-4}" height="{H-4}" rx="8"/></clipPath>
    {defs}
  </defs>
  <rect x="2" y="2" width="{W-4}" height="{H-4}" rx="8" fill="#0d1117" stroke="{BR}" filter="url(#glow)"/>
  <g clip-path="url(#clip)"><rect x="2" y="2" width="{W-4}" height="{TOP}" fill="#0a2614"/><line x1="2" y1="{TOP+2}" x2="{W-2}" y2="{TOP+2}" stroke="{BR}" stroke-opacity="0.5"/></g>
  <circle cx="22" cy="20" r="5" fill="{BR}"/><circle cx="40" cy="20" r="5" fill="#00a844"/><circle cx="58" cy="20" r="5" fill="#00611f"/>
  <text x="{W/2}" y="25" text-anchor="middle" font-family="{FONT}" font-size="13" fill="{MID}">dashboard</text>
  <g font-family="{FONT}" font-size="14">
    <text x="24" y="76"><tspan fill="{DIM}">{PROMPT}</tspan><tspan fill="{BR}">lindos --dashboard</tspan></text>
    {"".join(out)}
    <text x="24" y="276" fill="{DIM}" font-size="12"># repo metrics snapshot: {date}</text>
    <text x="24" y="304" fill="{DIM}">{PROMPT}</text>
    <rect x="{cursor_x:.1f}" y="291" width="9" height="16" fill="{BR}"><animate attributeName="opacity" values="1;1;0;0" dur="1.1s" repeatCount="indefinite"/></rect>
  </g>
</svg>
'''


def main():
    try:
        counts = fetch_counts()
    except Exception as e:  # never overwrite the file with bad data
        print(f"Could not fetch repo metrics: {e}", file=sys.stderr)
        return 1

    key = ",".join(map(str, counts))
    if OUT.exists():
        m = re.search(r'data-counts="([\d,]+)"', OUT.read_text(encoding="utf-8"))
        if m and m.group(1) == key:
            print(f"Counts unchanged ({key}); nothing to do.")
            return 0

    date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(render(*counts, date), encoding="utf-8")
    print(f"Updated {OUT.name}: stars/forks/watchers = {key}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
