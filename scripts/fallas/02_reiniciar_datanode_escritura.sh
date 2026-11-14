#!/usr/bin/env bash
# Fallo 2 — Reiniciar un DataNode MIENTRAS se escribe un archivo grande en HDFS.
# El cliente detecta el nodo caído en el pipeline de escritura, lo excluye y
# continúa con los nodos restantes (pipeline recovery).
# Uso (desde el host):  bash scripts/fallas/02_reiniciar_datanode_escritura.sh
source "$(dirname "$0")/comun.sh"
NODE="${1:-datanode2}"

{
log "Generando un archivo de 60 MiB en el cliente (60 bloques de 1 MiB)..."
c bash -c "head -c 60M /dev/urandom > /tmp/grande.bin && md5sum /tmp/grande.bin"
c hdfs dfs -mkdir -p /taller/fallas
c hdfs dfs -rm -f -skipTrash /taller/fallas/grande.bin >/dev/null

# La escritura se limita a ~3 MiB/s (el cliente lee por stdin a esa velocidad) para que
# dure ~20 s y el reinicio del DataNode ocurra en mitad de la escritura.
log "Iniciando hdfs dfs -put (~3 MiB/s) en segundo plano..."
docker compose exec -T client bash -c "python3 /workspace/scripts/fallas/lector_lento.py /tmp/grande.bin 3 \
  | hdfs dfs -put - /taller/fallas/grande.bin" > evidencias/fallo_02_put_cliente.log 2>&1 &
PUT_PID=$!
sleep 7
log "Bloques escritos antes del fallo: $(c hdfs fsck /taller/fallas -openforwrite -files -blocks | grep -c blk_)"

log "=== REINICIANDO $NODE durante la escritura ==="
docker compose restart "$NODE"

wait "$PUT_PID"; rc=$?
log "hdfs dfs -put terminó con código $rc"

log "Mensajes del cliente HDFS durante el fallo (recuperación del pipeline):"
grep -E "Exception in createBlockOutputStream|Excluding datanode|Error Recovery|Recovering|bad datanode|DataStreamer Exception|Abandoning" \
  evidencias/fallo_02_put_cliente.log | sed -E 's/^[0-9-]+ //' | cut -c1-200 | head -12

log "Integridad: MD5 local vs MD5 del archivo leído desde HDFS"
c bash -c "md5sum /tmp/grande.bin | cut -d' ' -f1; hdfs dfs -cat /taller/fallas/grande.bin | md5sum | cut -d' ' -f1"
fsck_summary /taller/fallas/grande.bin
} 2>&1 | tee evidencias/fallo_02_reiniciar_datanode_escritura.txt
