#!/usr/bin/env bash
# Fallo 1 — Apagar un DataNode y observar detección, re-replicación y regreso del nodo.
# Uso (desde el host):  bash scripts/fallas/01_apagar_datanode.sh
# Nota: comun.sh usa "set -o pipefail"; por eso las esperas usan "grep ... >/dev/null" y no
# "grep -q" (grep -q cierra el pipe antes de tiempo y el pipeline se reporta como fallido).
source "$(dirname "$0")/comun.sh"
NODE="${1:-datanode1}"
FILE=/taller/input/logs/access.log

{
log "=== ESTADO INICIAL ==="
dn_report
fsck_summary /taller/input
log "Ubicación de los 3 primeros bloques de $FILE:"
c hdfs fsck "$FILE" -files -blocks -locations | grep -E "^[0-9]+\. " | head -3 | sed -E 's/DatanodeInfoWithStorage\[([0-9.]+):[0-9]+,[^]]*\]/\1/g'
log "Checksum antes del fallo:"; c hdfs dfs -checksum "$FILE"

log "=== APAGANDO $NODE ==="
docker compose stop "$NODE"
log "Inmediatamente después (el NameNode aún no lo sabe):"
dn_report | head -2

# Los contadores se leen del JMX del NameNode (http://localhost:9870/jmx): es instantáneo,
# a diferencia de fsck, y permite seguir la re-replicación segundo a segundo.
t0=$(date +%s)
until [[ "$(jmx FSNamesystemState NumDeadDataNodes)" == "1" ]]; do sleep 1; done
log "El NameNode declaró muerto el nodo tras $(( $(date +%s) - t0 )) s"
dn_report

under() { fsck_summary /taller/input | grep -o "Under-replicated blocks:[[:space:]]*[0-9]*" | grep -o '[0-9]*$'; }

# El NameNode quita los bloques del nodo muerto en segundo plano: el conteo tarda unos segundos
# en subir y luego baja a medida que se re-replica. Se sigue hasta verlo volver a 0
# (si en 45 s nunca sube, el nodo apagado no tenía bloques de /taller/input).
log "Re-replicación: bloques infra-replicados según fsck (y el contador de la UI, Overview):"
t1=$(date +%s); seen=0
while true; do
  u=$(under)
  log "  fsck=${u:-?}  UI=$(jmx FSNamesystem UnderReplicatedBlocks)"
  (( ${u:-0} > 0 )) && seen=1
  (( seen == 1 )) && [[ "$u" == "0" ]] && break
  (( seen == 0 )) && (( $(date +%s) - t1 > 45 )) && break
  sleep 3
done
log "Re-replicación completa: $(( $(date +%s) - t1 )) s desde que se detectó el nodo muerto"

log "Lectura completa del archivo con $NODE todavía apagado (debe dar 200000 líneas):"
c bash -c "hdfs dfs -cat $FILE | wc -l"
fsck_summary /taller/input
c hdfs fsck "$FILE" -files -blocks -locations | grep -E "^[0-9]+\. " | head -3 | sed -E 's/DatanodeInfoWithStorage\[([0-9.]+):[0-9]+,[^]]*\]/\1/g'
log "Checksum después del fallo (debe ser idéntico):"; c hdfs dfs -checksum "$FILE"

log "=== RECUPERANDO $NODE ==="
docker compose start "$NODE"
until c hdfs dfsadmin -report | grep "Live datanodes (3)" >/dev/null; do sleep 3; done
log "El nodo volvió. Sus réplicas antiguas ahora sobran (over-replicated) y el NameNode borra el exceso:"
sleep 15
dn_report
fsck_summary /taller/input
} 2>&1 | tee evidencias/fallo_01_apagar_datanode.txt
