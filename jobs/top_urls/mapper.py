#!/usr/bin/env python3
"""Mapper: cuenta peticiones por URL (sin query string).

Entrada : línea de log Apache ... "GET /productos?page=3 HTTP/1.1" 200 ...
Salida  : /productos \t 1
"""
import sys

for line in sys.stdin:
    try:
        request = line.split('"')[1]          # GET /productos?page=3 HTTP/1.1
        url = request.split(" ")[1].split("?")[0]
    except IndexError:
        continue                              # línea mal formada
    print(f"{url}\t1")
