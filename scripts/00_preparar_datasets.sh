#!/usr/bin/env bash
# Prepara los 3 datasets del taller en ./datasets (se ejecuta desde el HOST).
#   - transactions.csv : copiado del repositorio de ejemplo (85.000 transacciones)
#   - access.log       : log web sintético con horas pico (200.000 líneas, semilla fija)
#   - quijote.txt      : "Don Quijote" (Proyecto Gutenberg, dominio público)
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p datasets

[[ -f datasets/transactions.csv ]] || curl -fsSL   https://raw.githubusercontent.com/CloudComputingUAO/HDFS/main/datasets/transactions.csv -o datasets/transactions.csv

[[ -f datasets/access.log ]] || docker run --rm -v "$PWD":/w -w /w python:3.12-alpine \
  python scripts/generate_access_log.py --output datasets/access.log --rows 200000

[[ -f datasets/quijote.txt ]] || curl -fsSL https://www.gutenberg.org/cache/epub/2000/pg2000.txt -o datasets/quijote.txt

ls -la datasets
