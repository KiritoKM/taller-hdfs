#!/usr/bin/env bash
# Fallo 3 — Matar un NodeManager mientras corre un job MapReduce.
#
#   bash scripts/fallas/03_matar_nodemanager.sh          # mata el NM que NO tiene el ApplicationMaster
#   bash scripts/fallas/03_matar_nodemanager.sh am       # mata el NM que SÍ tiene el ApplicationMaster
#
# Se usa "docker compose kill" (SIGKILL): simula una caída abrupta, sin que el
# NodeManager alcance a avisarle al ResourceManager. El RM lo marca LOST cuando
# deja de recibir heartbeats (30 s en este laboratorio).
source "$(dirname "$0")/comun.sh"
MODE="${1:-worker}"
NAME="fallo-nodemanager-$MODE"

{
log "=== Nodos YARN antes del fallo ==="
yarn_nodes

launch_slow_job "$NAME" "evidencias/fallo_03_${MODE}_cliente.log"

# Esperar a que haya maps corriendo en ambos nodos
until [[ "$(job_tasks "$APP" 2>/dev/null)" =~ mapsRunning=([1-9][0-9]*) ]] && (( BASH_REMATCH[1] >= 6 )); do sleep 3; done
INFO=$(app_info "$APP" | tr -d '\r'); AM_NODE=$(awk '{print $3}' <<<"$INFO")
log "ApplicationMaster en: $AM_NODE"
log "Tareas: $(job_tasks "$APP")"
yarn_nodes

if [[ "$MODE" == "am" ]]; then VICTIM="$AM_NODE"
else VICTIM=$([[ "$AM_NODE" == "nodemanager1" ]] && echo nodemanager2 || echo nodemanager1); fi

# Nodos LOST de experimentos anteriores siguen en la lista: se espera uno NUEVO.
lost_before=$(yarn_nodes | grep -c "LOST")
log "=== MATANDO $VICTIM (SIGKILL) con el job en RUNNING ==="
docker compose kill "$VICTIM"

t0=$(date +%s)
until (( $(yarn_nodes | grep -c "LOST") > lost_before )); do sleep 3; done
log "El ResourceManager marcó el nodo como LOST tras $(( $(date +%s) - t0 )) s"
yarn_nodes

wait_app_finished "$APP"

log "=== Resultado ==="
c yarn application -status "$APP" | grep -E "State|Final-State|Diagnostics|AM Host"
log "Intentos del ApplicationMaster:"
c yarn applicationattempt -list "$APP" | grep -E "appattempt_"
compare_with_reference "$NAME"

log "=== Recuperando $VICTIM ==="
docker compose start "$VICTIM"
sleep 15
yarn_nodes
} 2>&1 | tee "evidencias/fallo_03_matar_nodemanager_${MODE}.txt"
