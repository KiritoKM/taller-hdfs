#!/usr/bin/env bash
# Ejecuta los jobs MapReduce del taller.
# Uso (desde el host):
#   docker compose exec client bash scripts/02_ejecutar_jobs.sh            # los 4 jobs
#   docker compose exec client bash scripts/02_ejecutar_jobs.sh wordcount  # solo uno
#   (wordcount | promedio | horas | top | falla)
set -uo pipefail

J=/workspace/jobs
OUT=/taller/output
EVID=/workspace/evidencias
mkdir -p "$EVID"

run() {  # run <nombre> <comando...>   -> guarda la salida del cliente en evidencias/
  local name="$1"; shift
  hdfs dfs -rm -r -f -skipTrash "$OUT/$name" >/dev/null 2>&1
  echo "=================== JOB: $name ==================="
  local start=$(date +%s)
  "$@" 2>&1 | tee "$EVID/job_${name}.log"
  local rc=${PIPESTATUS[0]}
  echo ">>> $name terminó con código $rc en $(( $(date +%s) - start )) s"
  return 0
}

job_wordcount() {
  # Job 1 — WordCount NATIVO (Java, jar de ejemplos de Hadoop)
  run wordcount hadoop jar "$HADOOP_EXAMPLES_JAR" wordcount \
    -D mapreduce.job.name=wordcount-quijote \
    /taller/input/libros "$OUT/wordcount"
}

job_promedio() {
  # Job 2 — Promedio por clave (Streaming + combiner)
  run promedio_tienda hadoop jar "$HADOOP_STREAMING_JAR" \
    -D mapreduce.job.name=promedio-ventas-por-tienda \
    -files "$J/promedio_tienda/mapper.py,$J/promedio_tienda/reducer.py" \
    -mapper "python3 mapper.py" \
    -combiner "python3 reducer.py partial" \
    -reducer "python3 reducer.py" \
    -input /taller/input/transacciones -output "$OUT/promedio_tienda"
}

job_horas() {
  # Job 3 — Análisis de logs: horas pico (Streaming + combiner)
  run horas_pico hadoop jar "$HADOOP_STREAMING_JAR" \
    -D mapreduce.job.name=horas-pico-access-log \
    -files "$J/horas_pico/mapper.py,$J/comun/sum_reducer.py" \
    -mapper "python3 mapper.py" \
    -combiner "python3 sum_reducer.py" \
    -reducer "python3 sum_reducer.py" \
    -input /taller/input/logs -output "$OUT/horas_pico"
}

job_top() {
  # Job 4 — Top 10 URLs más visitadas (Streaming, un solo reducer)
  run top_urls hadoop jar "$HADOOP_STREAMING_JAR" \
    -D mapreduce.job.name=top10-urls \
    -D mapreduce.job.reduces=1 \
    -files "$J/top_urls/mapper.py,$J/top_urls/top_reducer.py,$J/comun/sum_reducer.py" \
    -mapper "python3 mapper.py" \
    -combiner "python3 sum_reducer.py" \
    -reducer "python3 top_reducer.py 10" \
    -input /taller/input/logs -output "$OUT/top_urls"
}

job_falla() {
  # Job 5 — Falla intencional: para observar reintentos y el estado FAILED
  run falla_intencional hadoop jar "$HADOOP_STREAMING_JAR" \
    -D mapreduce.job.name=falla-intencional \
    -files "$J/falla_intencional/mapper.py" \
    -mapper "python3 mapper.py" -reducer NONE \
    -input /taller/input/transacciones -output "$OUT/falla_intencional"
}

case "${1:-all}" in
  wordcount) job_wordcount ;;
  promedio)  job_promedio ;;
  horas)     job_horas ;;
  top)       job_top ;;
  falla)     job_falla ;;
  all)       job_wordcount; job_promedio; job_horas; job_top ;;
  *) echo "Job desconocido: $1" >&2; exit 1 ;;
esac

echo
echo "== Salidas en HDFS =="
hdfs dfs -ls -R "$OUT" | grep -v "_temporary" || true
