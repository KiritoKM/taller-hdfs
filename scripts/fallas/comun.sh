#!/usr/bin/env bash
# Funciones comunes de los experimentos de fallos. Se ejecutan desde el HOST
# (Git Bash en Windows, o bash en Linux/macOS), en la raíz del proyecto.
set -uo pipefail
export MSYS_NO_PATHCONV=1   # evita que Git Bash convierta rutas como /taller en C:/...

cd "$(dirname "$0")/../.."
mkdir -p evidencias

ts()   { date +%H:%M:%S; }
log()  { echo "[$(ts)] $*"; }
c()    { docker compose exec -T client "$@" 2>&1 | grep -v -E "^WARNING|INFO client\.|INFO sasl\.|INFO conf\.Configuration"; }

dn_report() {  # resumen corto de DataNodes vivos/muertos
  c hdfs dfsadmin -report | grep -E "Live datanodes|Dead datanodes|Under replicated|Missing blocks|^Name:"
}

fsck_summary() {  # fsck <ruta> resumido
  c hdfs fsck "${1:-/taller/input}" | grep -E "Status:|Total blocks|Under-replicated blocks|Mis-replicated|Missing blocks|Corrupt blocks|Average block replication|Number of data-nodes"
}

wait_dead_datanodes() {  # espera hasta que el NameNode reporte N nodos muertos
  local n="$1" t0=$(date +%s)
  until c hdfs dfsadmin -report | grep "Dead datanodes ($n)" >/dev/null; do sleep 2; done
  log "El NameNode ya reporta $n DataNode(s) muerto(s) tras $(( $(date +%s) - t0 )) s"
}

jmx() {  # jmx <bean> <atributo>: lee un contador numérico del NameNode, ej. jmx FSNamesystem UnderReplicatedBlocks
  curl -s "http://localhost:9870/jmx?qry=Hadoop:service=NameNode,name=$1" | grep -o "\"$2\" : [0-9]*" | grep -o '[0-9]*$'
}

yarn_nodes() { c yarn node -list -all | grep -E "Total Nodes|Node-State|nodemanager"; }

app_id_by_name() {  # último application id con ese nombre
  c python3 -c "
import json, urllib.request
apps = json.load(urllib.request.urlopen('http://resourcemanager:8088/ws/v1/cluster/apps'))['apps']['app']
ids = sorted(a['id'] for a in apps if a['name'] == '$1')
print(ids[-1] if ids else '')"
}

launch_slow_job() {  # launch_slow_job <nombre> <logfile>: job "horas pico" con maps lentos, en segundo plano
  local name="$1" logfile="$2" delay="${MAPPER_DELAY:-20}"
  c hdfs dfs -rm -r -f -skipTrash "/taller/output/$name" >/dev/null
  local previous; previous=$(app_id_by_name "$name" | tr -d '\r')   # ejecución anterior con el mismo nombre
  docker compose exec -T client bash -c "hadoop jar \$HADOOP_STREAMING_JAR \
      -D mapreduce.job.name=$name \
      -files /workspace/jobs/horas_pico/mapper.py,/workspace/jobs/comun/sum_reducer.py \
      -cmdenv MAPPER_DELAY=$delay \
      -mapper 'python3 mapper.py' -combiner 'python3 sum_reducer.py' -reducer 'python3 sum_reducer.py' \
      -input /taller/input/logs -output /taller/output/$name" >"$logfile" 2>&1 &
  JOB_PID=$!
  APP=""
  until [[ -n "$APP" && "$APP" != "$previous" ]]; do sleep 2; APP=$(app_id_by_name "$name" | tr -d '\r'); done
  log "Job $name lanzado como $APP (cada map tarda >= ${delay}s)"
}

wait_app_finished() {  # imprime el progreso hasta que termina la aplicación
  local app="$1"
  while true; do
    local info; info=$(app_info "$app" | tr -d '\r')
    log "app: $info | $(job_tasks "$app" | tr -d '\r')"
    [[ "$info" == FINISHED* || "$info" == FAILED* || "$info" == KILLED* ]] && break
    sleep 8
  done
  wait "$JOB_PID" 2>/dev/null || true
}

compare_with_reference() {  # compara la salida de un job con la del job normal horas_pico
  if diff <(c hdfs dfs -cat "/taller/output/$1/part-*") <(c hdfs dfs -cat /taller/output/horas_pico/part-*) >/dev/null; then
    log "VALIDACIÓN: la salida de $1 es IDÉNTICA a la del job sin fallos (horas_pico)"
  else
    log "VALIDACIÓN: la salida de $1 DIFIERE de la del job sin fallos"
  fi
}

app_info() {  # estado de la aplicación: state finalStatus nodo-del-AM progreso
  c python3 -c "
import json, urllib.request
a = json.load(urllib.request.urlopen('http://resourcemanager:8088/ws/v1/cluster/apps/$1'))['app']
print(a['state'], a['finalStatus'], a.get('amHostHttpAddress', '-').split(':')[0], f\"{a['progress']:.0f}%\")"
}

job_tasks() {  # resumen de tareas del job en ejecución (vía proxy del AM) o terminado (JobHistory)
  local job="${1/application_/job_}"
  c python3 -c "
import json, urllib.request
for url in ('http://resourcemanager:8088/proxy/$1/ws/v1/mapreduce/jobs/$job',
            'http://historyserver:19888/ws/v1/history/mapreduce/jobs/$job'):
    try:
        j = json.load(urllib.request.urlopen(url, timeout=5))['job']
        break
    except Exception:
        continue
else:
    raise SystemExit('job no disponible todavía')
keys = ['state', 'mapsCompleted', 'mapsTotal', 'mapsRunning', 'reducesCompleted', 'reducesRunning',
        'successfulMapAttempts', 'failedMapAttempts', 'killedMapAttempts',
        'successfulReduceAttempts', 'failedReduceAttempts', 'killedReduceAttempts']
print('  '.join(f'{k}={j[k]}' for k in keys if k in j))"
}
