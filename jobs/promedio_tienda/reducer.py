#!/usr/bin/env python3
"""Reducer / combiner: fusiona agregados (suma, conteo, min, max) por tienda.

  python3 reducer.py partial  -> se usa como COMBINER: emite el agregado parcial
  python3 reducer.py          -> se usa como REDUCER : emite el resultado final

Salida final: store \t transacciones \t total_cop \t promedio_cop \t min_cop \t max_cop
"""
import sys

partial = len(sys.argv) > 1 and sys.argv[1] == "partial"


def emit(store, total, count, low, high):
    if partial:
        print(f"{store}\t{total}\t{count}\t{low}\t{high}")
    else:
        print(f"{store}\t{count}\t{total}\t{total / count:.2f}\t{low}\t{high}")


current = None
total = count = 0
low = high = None

for line in sys.stdin:
    store, s, c, mn, mx = line.rstrip("\n").split("\t")
    s, c, mn, mx = int(s), int(c), int(mn), int(mx)
    if store != current:
        if current is not None:
            emit(current, total, count, low, high)
        current, total, count, low, high = store, 0, 0, mn, mx
    total += s
    count += c
    low = min(low, mn)
    high = max(high, mx)

if current is not None:
    emit(current, total, count, low, high)
