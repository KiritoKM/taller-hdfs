#!/usr/bin/env python3
"""Mapper que falla a propósito para observar el estado FAILED en YARN.

Lee unas líneas y lanza una excepción: cada intento del map termina con
código distinto de 0, YARN lo reintenta (mapreduce.map.maxattempts = 4) y
cuando se agotan los intentos el job queda FAILED.
"""
import sys

for number, line in enumerate(sys.stdin, start=1):
    if number == 100:
        raise RuntimeError("Falla intencional del taller: registro corrupto simulado")
    print(f"{line.split(',')[2] if ',' in line else 'x'}\t1")
