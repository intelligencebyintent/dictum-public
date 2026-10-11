"""Score cleanup bakeoff results against paragraphs.json and print a Markdown report.

Usage: python3 -I score.py results/A.json [results/B.json ...]

Automatic checks per output (run 1; the report notes when runs differ):
- Facts kept: the paragraph's "include" patterns that are present.
- Problems: "exclude" patterns found (corrected-away values, leftover fillers,
  answered content), missing structure (paragraph breaks, numbered lists),
  em dashes, a preamble, wrapping quotes, leftover tags, or an error/refusal.
- Added words: words in the output that were never spoken (numbers excepted).
  Catches invented sentences and misspelled names.
- Distance: word edit distance to the hand-written reference, as a % of the
  reference length. Lower is closer. A rough guide only: a different but valid
  wording also counts as distance.
"""
import json
import re
import statistics
import sys
from pathlib import Path

HERE = Path(__file__).parent
SUITE = json.loads((HERE / "paragraphs.json").read_text())
PARAS = {p["id"]: p for p in SUITE["paragraphs"]}

GLOBAL = [
    (r"\b(um|uh|uhm|erm?)\b", "filler left in"),
    (r"—|\s--\s", "em dash"),
    (r"^\s*(here('s| is)|sure\b|okay, here|cleaned)", "preamble"),
    (r"^\s*[\"“].*[\"”]\s*$", "wrapped in quotes"),
    (r"</?transcript", "tags left in"),
]


def words(text):
    text = text.lower().replace("’", "'")
    text = re.sub(r"(?<=\d),(?=\d)", "", text)
    text = re.sub(r"[^\w'%]+", " ", text)
    return text.split()


def distance(a, b):
    prev = list(range(len(b) + 1))
    for i, x in enumerate(a, 1):
        cur = [i]
        for j, y in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x != y)))
        prev = cur
    return prev[-1]


def check(p, out, error):
    if error or out is None:
        return {"facts": 0, "fact_total": len(p["include"]), "problems": [f"error: {error}"], "distance": None}
    flags = re.IGNORECASE | re.MULTILINE
    missing = [pat for pat in p["include"] if not re.search(pat, out, flags)]
    problems = [f"kept “{m.group(0)}”" for pat in p.get("exclude", []) if (m := re.search(pat, out, flags))]
    problems += [f"missing structure ({pat})" for pat in p.get("structure", []) if not re.search(pat, out)]
    problems += [label for pat, label in GLOBAL if re.search(pat, out, flags | re.DOTALL)]
    problems += [f"dropped: {pat}" for pat in missing]
    spoken = set(words(p["raw"]))
    added = sorted({w for w in words(out) if w not in spoken and not re.fullmatch(r"\d[\d%]*(st|nd|rd|th)?", w)})
    if added:
        problems.append("added words: " + ", ".join(added))
    ref = words(p["reference"])
    return {
        "facts": len(p["include"]) - len(missing),
        "fact_total": len(p["include"]),
        "problems": problems,
        "distance": round(100 * distance(words(out), ref) / len(ref)),
    }


def pct(values, q):
    values = sorted(values)
    return values[min(len(values) - 1, int(round(q * (len(values) - 1))))]


def main(paths):
    results = [r for path in paths for r in json.loads(Path(path).read_text())]
    prompts = list(dict.fromkeys(r.get("prompt", "system-prompt.txt") for r in results))
    for r in results:
        # Label by model, plus the prompt when the report compares prompts.
        if len(prompts) > 1:
            r["model"] = f'{r["model"]} \u00b7 {r.get("prompt", "system-prompt.txt").removesuffix(".txt")}'
    models = list(dict.fromkeys(r["model"] for r in results))
    by = {(r["model"], r["paragraph"], r["run"]): r for r in results}

    print("# Cleanup bakeoff\n")
    print(f"Sources: {', '.join(Path(p).name for p in paths)}. Prompts: {', '.join(f'`{p}`' for p in prompts)}. "
          "Ten synthetic paragraphs, temperature 0.\n")

    print("## Summary\n")
    print("| Model | Median | p95 | First call | Facts kept | Outputs with problems | Avg distance | Runs identical |")
    print("|---|---|---|---|---|---|---|---|")
    scored = {}
    for m in models:
        rows = [r for r in results if r["model"] == m]
        ms = [r["ms"] for r in rows if not r.get("error")]
        first = by.get((m, min(PARAS), 1), {}).get("ms")
        checks = {pid: check(PARAS[pid], by[(m, pid, 1)].get("output"), by[(m, pid, 1)].get("error")) for pid in PARAS if (m, pid, 1) in by}
        scored[m] = checks
        facts = sum(c["facts"] for c in checks.values())
        total = sum(c["fact_total"] for c in checks.values())
        flagged = sum(1 for c in checks.values() if c["problems"])
        dists = [c["distance"] for c in checks.values() if c["distance"] is not None]
        runs = sorted({r["run"] for r in rows})
        same = sum(1 for pid in PARAS if len({by[(m, pid, n)].get("output") for n in runs if (m, pid, n) in by}) == 1)
        print(f"| {m} | {statistics.median(ms):.0f} ms | {pct(ms, 0.95):.0f} ms | {first} ms | {facts}/{total} | "
              f"{flagged}/10 | {statistics.mean(dists):.0f}% | {same}/10 |")

    print("\n## Latency by paragraph (median of runs, ms)\n")
    print("| # | Paragraph | Words | " + " | ".join(models) + " |")
    print("|---|---|---|" + "---|" * len(models))
    for pid, p in PARAS.items():
        cells = []
        for m in models:
            vals = [r["ms"] for r in results if r["model"] == m and r["paragraph"] == pid and not r.get("error")]
            cells.append(f"{statistics.median(vals):.0f}" if vals else "error")
        print(f"| {pid} | {p['title']} | {len(p['raw'].split())} | " + " | ".join(cells) + " |")

    print("\n## Outputs\n")
    for pid, p in PARAS.items():
        print(f"### {pid}. {p['title']} ({p['app']})\n")
        print(f"**Raw transcript**\n\n> {p['raw']}\n")
        print("**Reference**\n\n" + "\n".join(f"> {line}" for line in p["reference"].split("\n")) + "\n")
        for m in models:
            r = by.get((m, pid, 1))
            if not r:
                continue
            c = scored[m][pid]
            text = r.get("output") if r.get("output") is not None else f"(error: {r['error']})"
            runs = sorted({x["run"] for x in results if x["model"] == m and x["paragraph"] == pid})
            differs = len({by[(m, pid, n)].get("output") for n in runs}) > 1
            dist = "n/a" if c["distance"] is None else f"{c['distance']}%"
            print(f"**{m}** ({r['ms']} ms; facts {c['facts']}/{c['fact_total']}; distance {dist}"
                  f"{'; runs differ' if differs else ''})\n")
            print("\n".join(f"> {line}" for line in text.split("\n")) + "\n")
            if c["problems"]:
                print("Problems: " + "; ".join(c["problems"]) + "\n")


if __name__ == "__main__":
    main(sys.argv[1:])
