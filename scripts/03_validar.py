#!/usr/bin/env python3
"""Validación manual: recalcula cada resultado localmente (sin Hadoop) y lo
compara con la salida que los jobs dejaron en HDFS.

Uso (desde el host):  docker compose exec client python3 scripts/03_validar.py
"""
import heapq
import re
import subprocess
from collections import Counter, defaultdict

DATA = "/workspace/datasets"
OUT = "/taller/output"


def hdfs_cat(path):
    result = subprocess.run(["hdfs", "dfs", "-cat", f"{path}/part-*"],
                            capture_output=True, text=True, encoding="utf-8")
    if result.returncode != 0:
        raise SystemExit(f"No se pudo leer {path}: {result.stderr.strip()}")
    return [line for line in result.stdout.splitlines() if line]


def report(name, expected, actual, show):
    ok = expected == actual
    print(f"\n[{'OK' if ok else 'DIFERENTE'}] {name}: {len(expected)} claves esperadas, {len(actual)} en HDFS")
    if not ok:
        diff = [k for k in set(expected) | set(actual) if expected.get(k) != actual.get(k)]
        for key in sorted(diff)[:10]:
            print(f"   {key!r}: esperado={expected.get(key)} hdfs={actual.get(key)}")
    for line in show:
        print("   " + line)
    return ok


# ---------- Job 1: WordCount (mismo tokenizador que StringTokenizer de Java) ----------
words = Counter()
with open(f"{DATA}/quijote.txt", encoding="utf-8") as fh:
    for line in fh:
        words.update(t for t in re.split(r"[ \t\n\r\f]+", line) if t)
actual = {}
for line in hdfs_cat(f"{OUT}/wordcount"):
    word, count = line.rsplit("\t", 1)
    actual[word] = int(count)
top = heapq.nlargest(8, actual.items(), key=lambda kv: kv[1])
ok1 = report("WordCount", dict(words), actual,
             ["Top 8: " + ", ".join(f"{w}={c}" for w, c in top),
              f"Total de palabras: {sum(actual.values()):,}"])

# ---------- Job 2: promedio por tienda ----------
agg = defaultdict(lambda: [0, 0, None, None])
with open(f"{DATA}/transactions.csv", encoding="utf-8") as fh:
    next(fh)
    for line in fh:
        _, _, store, amount, status = line.strip().split(",")
        if status != "APPROVED":
            continue
        a = agg[store]
        v = int(amount)
        a[0] += 1
        a[1] += v
        a[2] = v if a[2] is None else min(a[2], v)
        a[3] = v if a[3] is None else max(a[3], v)
expected = {s: (c, t, f"{t / c:.2f}", mn, mx) for s, (c, t, mn, mx) in agg.items()}
actual, lines = {}, []
for line in hdfs_cat(f"{OUT}/promedio_tienda"):
    s, c, t, avg, mn, mx = line.split("\t")
    actual[s] = (int(c), int(t), avg, int(mn), int(mx))
    lines.append(f"{s:<13} n={int(c):>6,}  promedio=${float(avg):>12,.2f}")
ok2 = report("Promedio por tienda", expected, actual, lines)

# ---------- Jobs 3 y 4: logs ----------
hours, urls = Counter(), Counter()
with open(f"{DATA}/access.log", encoding="utf-8") as fh:
    for line in fh:
        i = line.find("[")
        hours[line[i + 13:i + 15]] += 1
        urls[line.split('"')[1].split(" ")[1].split("?")[0]] += 1

actual = {h: int(c) for h, c in (l.split("\t") for l in hdfs_cat(f"{OUT}/horas_pico"))}
peak = sorted(actual.items(), key=lambda kv: -kv[1])[:3]
ok3 = report("Horas pico", dict(hours), actual,
             ["Horas pico: " + ", ".join(f"{h}:00 ({c:,} peticiones)" for h, c in peak)])

expected = {rank: (url, c) for rank, (c, url) in
            enumerate(heapq.nlargest(10, ((c, u) for u, c in urls.items())), start=1)}
actual, lines = {}, []
for line in hdfs_cat(f"{OUT}/top_urls"):
    rank, url, c = line.split("\t")
    actual[int(rank)] = (url, int(c))
    lines.append(f"{rank:>2}. {url:<26} {int(c):>6,}")
ok4 = report("Top 10 URLs", expected, actual, lines)

print("\nRESULTADO:", "todos los jobs coinciden con el cálculo local"
      if all([ok1, ok2, ok3, ok4]) else "HAY DIFERENCIAS")
