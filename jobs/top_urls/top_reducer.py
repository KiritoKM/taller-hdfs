#!/usr/bin/env python3
"""Reducer Top-N: suma por URL y al final emite solo las N más visitadas.

Debe ejecutarse con UN solo reducer (-numReduceTasks 1) para que el ranking
sea global y no por partición.

Salida: posicion \t url \t visitas
"""
import heapq
import sys

n = int(sys.argv[1]) if len(sys.argv) > 1 else 10
totals = []
current, total = None, 0

for line in sys.stdin:
    key, value = line.rstrip("\n").rsplit("\t", 1)
    if key != current:
        if current is not None:
            totals.append((total, current))
        current, total = key, 0
    total += int(value)
if current is not None:
    totals.append((total, current))

for rank, (visits, url) in enumerate(heapq.nlargest(n, totals), start=1):
    print(f"{rank}\t{url}\t{visits}")
