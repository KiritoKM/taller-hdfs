#!/usr/bin/env bash
# Punto 3 del taller: verificar la ejecución de los jobs (YARN, logs, HDFS).
# Uso (desde el host):  docker compose exec client bash scripts/04_verificar.sh
set -uo pipefail

echo "== Aplicaciones en YARN (todos los estados) =="
yarn application -list -appStates ALL 2>/dev/null

echo
echo "== Estado y contadores de cada job (REST de ResourceManager y JobHistory) =="
python3 /workspace/scripts/yarn_resumen.py

FAILED_APP=$(python3 /workspace/scripts/yarn_resumen.py failed-id)
if [[ -n "$FAILED_APP" ]]; then
  echo
  echo "== Logs agregados del job FAILED ($FAILED_APP): causa del error =="
  yarn logs -applicationId "$FAILED_APP" 2>/dev/null \
    | grep -a -o -E "RuntimeError: Falla intencional.*|PipeMapRed.waitOutputThreads\(\): subprocess failed with code [0-9]+" \
    | sort | uniq -c
  echo "(cada línea es un mensaje repetido N veces: un map falló en todos sus intentos -> job FAILED)"
fi

echo
echo "== Salidas en HDFS =="
hdfs dfs -ls /taller/output/*
for d in promedio_tienda horas_pico top_urls; do
  echo "--- hdfs dfs -cat /taller/output/$d/part-00000"
  hdfs dfs -cat /taller/output/$d/part-00000
done
echo "--- WordCount (10 palabras más frecuentes)"
hdfs dfs -cat /taller/output/wordcount/part-r-00000 2>/dev/null | sort -t$'	' -k2 -nr | head -10
