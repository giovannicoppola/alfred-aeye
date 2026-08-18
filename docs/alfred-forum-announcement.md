# introducing Aeye 🦉

**Draft for Alfred Forum → Share your Workflows**  
(also suitable as Gallery release blurb — shorten the Usage section if needed)

---

**Aeye**

Check your Cursor and Claude usage toward plan limits from Alfred.

![screenshot placeholder — attach a quick four-row overview capture when posting]

If you bounce between Cursor and Claude and keep opening dashboards just to see how much quota you have left, you might find this helpful.

**[Download](https://github.com/giovannicoppola/alfred-aeye/releases/latest)**  
**[GitHub](https://github.com/giovannicoppola/alfred-aeye)**

## Requirements

- Alfred 5 with Powerpack
- Python 3 (macOS `/usr/bin/python3` is fine)
- For Cursor rows: signed in to the **Cursor** app on this Mac
- For Claude rows: **Claude Code** signed in on this Mac
- Uncheck unused rows in Configure Workflow if you only use one platform

## Usage

- Launch with keyword (default: `aieye`) or a hotkey
- Four rows with a green → yellow → red circle meter:
  1. **Composer / Auto** (Cursor)
  2. **Other models** (Cursor) — same split as the spending page
  3. **Hourly** (Claude 5-hour session; Claude Code icon)
  4. **Weekly** (Claude)
- Results are cached for ~60 seconds

### Actions

- ⏎: copy the selected row
- ⌘⏎: open the service dashboard

### Reading the numbers

- Cursor `$x / $y` = included compute spend vs plan included limit (not necessarily billed dollars)
- `(🕐 68%, 11d, Tue Aug 21)` = % of period elapsed, then time until reset (`d` / `h` / `m`)
- Pace emoji after the parenthesis: 🐢 underspending · 🎯 on track · 🔥 overspending (spent % vs elapsed %)
- `(🕐 40%, 5h, 11:30pm)` on Hourly when a session is active
- `(🕐 14%, 6d, Tue 8pm)` on Weekly
- Claude `experimental` = percentages from Anthropic’s OAuth usage API (not the official statusline)

Keyword and which rows to show can be changed in **Configure Workflow** (all four rows on by default).

## Notes

- Cursor data comes from your local Cursor session via [cursor-usage](https://github.com/javaisbetterthanpython/cursor-usage) (vendored)
- Claude data comes from [Claude-Code-Usage-Monitor](https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor) (vendored), using local Claude Code auth + the opt-in usage API
- Both packages are bundled; no separate `pip install` for end users
- I reviewed the vendored packages before shipping; see [SECURITY.md](https://github.com/giovannicoppola/alfred-aeye/blob/main/SECURITY.md)

## Feedback

… is welcome!  
https://github.com/giovannicoppola/alfred-aeye/issues

---

### Suggested forum topic title

`introducing Aeye 🦉 — Cursor & Claude usage toward limits`

### Gallery one-liner (if needed)

`See Cursor and Claude usage toward plan limits from Alfred.`
