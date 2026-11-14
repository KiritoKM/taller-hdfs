#!/usr/bin/env python3
"""Mapper: promedio de ventas APROBADAS por tienda.

Entrada : transaction_id,timestamp,store,amount_cop,status   (CSV)
Salida  : store \t suma \t conteo \t minimo \t maximo
          (un agregado parcial por línea, así el combiner y el reducer
           usan el mismo formato y el promedio se calcula al final)
"""
import sys

for line in sys.stdin:
    parts = line.strip().split(",")
    if len(parts) != 5 or parts[0] == "transaction_id":
        continue  # encabezado o línea corrupta
    _, _, store, amount, status = parts
    if status != "APPROVED":
        continue
    try:
        value = int(amount)
    except ValueError:
        continue
    print(f"{store}\t{value}\t1\t{value}\t{value}")
