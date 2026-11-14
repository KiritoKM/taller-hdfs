#!/usr/bin/env python3
"""Mapper: peticiones por hora del día (análisis de logs / horas pico).

Entrada : línea de log Apache  ...[10/Nov/2026:19:37:28 -0500] "GET / HTTP/1.1" ...
Salida  : HH \t 1

Variable opcional MAPPER_DELAY (segundos): hace que cada map tarde más.
Se usa solo en los experimentos de tolerancia a fallos para tener tiempo de
detener nodos mientras el job está en RUNNING.
"""
import os
import sys
import time

delay = float(os.environ.get("MAPPER_DELAY", "0"))
if delay:
    time.sleep(delay)

for line in sys.stdin:
    start = line.find("[")
    if start == -1:
        continue
    # [dd/Mon/yyyy:HH:MM:SS  -> la hora está 13 caracteres después del '['
    hour = line[start + 13:start + 15]
    if hour.isdigit():
        print(f"{hour}\t1")
