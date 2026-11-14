#!/usr/bin/env bash
# Fallo 4 — Interrumpir tareas durante la fase Map y durante la fase Reduce.
# Se matan (SIGKILL) los procesos de las tareas dentro de los NodeManagers, sin
# tumbar el nodo: YARN marca esos intentos como FAILED y MapReduce los reintenta
# (hasta mapreduce.map.maxattempts / mapreduce.reduce.maxattempts = 4).
# Uso (desde el host):  bash scripts/fallas/04_matar_tareas_map_reduce.sh
source "$(dirname "$0")/comun.sh"
NAME="fallo-tareas-map-reduce"

kill_in_nms() {  # kill_in_nms <patrón de proceso>
  for nm in nodemanager1 nodemanager2; do
    local n; n=$(docker compose exec -T "$nm" pgrep -fc "$1" | tr -d '\r')
    docker compose exec -T "$nm" pkill -9 -f "$1" || true
    log "  $nm: ${n:-0} proceso(s) que coinciden con '$1' terminados con SIGKILL"
  done
}

{
MAPPER_DELAY=25 launch_slow_job "$NAME" "evidencias/fallo_04_cliente.log"

until [[ "$(job_tasks "$APP" 2>/dev/null)" =~ mapsRunning=([1-9][0-9]*) ]] && (( BASH_REMATCH[1] >= 6 )); do sleep 3; done
log "Fase MAP en curso: $(job_tasks "$APP")"
log "=== MATANDO los mappers Python en ejecución ==="
kill_in_nms "python3 mapper.py"
sleep 5
log "Después de matar mappers: $(job_tasks "$APP")"

# Esperar a que el reducer esté corriendo (arranca cuando hay maps terminados: slowstart)
until [[ "$(job_tasks "$APP" 2>/dev/null)" =~ reducesRunning=1 ]]; do sleep 3; done
log "Fase REDUCE (shuffle) en curso: $(job_tasks "$APP")"
log "=== MATANDO la JVM del reducer (YarnChild ..._r_...) ==="
kill_in_nms "YarnChild.*_r_0"
sleep 5
log "Después de matar el reducer: $(job_tasks "$APP")"

wait_app_finished "$APP"

log "=== Intentos fallidos registrados por el JobHistory ==="
JOB="${APP/application_/job_}"
c python3 -c "
import json, urllib.request
base = 'http://historyserver:19888/ws/v1/history/mapreduce/jobs/$JOB/tasks'
for t in json.load(urllib.request.urlopen(base))['tasks']['task']:
    atts = json.load(urllib.request.urlopen(f\"{base}/{t['id']}/attempts\"))['taskAttempts']['taskAttempt']
    if len(atts) > 1:
        print(t['id'], t['type'], '->', ', '.join(f\"{a['id'][-2:]}:{a['state']}@{a['nodeHttpAddress'].split(':')[0]}\" for a in atts))
"
compare_with_reference "$NAME"
} 2>&1 | tee evidencias/fallo_04_matar_tareas_map_reduce.txt
