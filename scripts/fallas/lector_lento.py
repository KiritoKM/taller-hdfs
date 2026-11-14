#!/usr/bin/env python3
"""Copia un archivo a stdout a velocidad limitada: lector_lento.py <archivo> <MiB/s>."""
import sys
import time

path, rate = sys.argv[1], float(sys.argv[2])
chunk = 256 * 1024
with open(path, "rb") as src:
    while data := src.read(chunk):
        sys.stdout.buffer.write(data)
        sys.stdout.buffer.flush()
        time.sleep(len(data) / (rate * 1024 * 1024))
