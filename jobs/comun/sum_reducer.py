#!/usr/bin/env python3
"""Reducer/combiner genérico: suma los valores enteros de cada clave.

Entrada (ordenada por clave): clave \t n
Salida                      : clave \t suma
"""
import sys

current, total = None, 0
for line in sys.stdin:
    key, value = line.rstrip("\n").rsplit("\t", 1)
    if key != current:
        if current is not None:
            print(f"{current}\t{total}")
        current, total = key, 0
    total += int(value)

if current is not None:
    print(f"{current}\t{total}")
