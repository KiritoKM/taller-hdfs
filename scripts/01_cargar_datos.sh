#!/usr/bin/env bash
# Carga los datasets en HDFS con una estructura de directorios por fuente.
# Uso (desde el host):  docker compose exec client bash scripts/01_cargar_datos.sh
set -euo pipefail

echo "== Estado del clúster =="
hdfs dfsadmin -report | grep -E "Live datanodes|Dead datanodes|^Name:|DFS Used%" || true
yarn node -list -all

echo
echo "== Estructura de entrada en HDFS =="
hdfs dfs -mkdir -p /taller/input/libros /taller/input/transacciones /taller/input/logs /taller/output
hdfs dfs -put -f /workspace/datasets/quijote.txt       /taller/input/libros/
hdfs dfs -put -f /workspace/datasets/transactions.csv  /taller/input/transacciones/
hdfs dfs -put -f /workspace/datasets/access.log        /taller/input/logs/

hdfs dfs -ls -R -h /taller/input
echo
hdfs dfs -du -h /taller/input

echo
echo "== Bloques y réplicas =="
for f in /taller/input/libros/quijote.txt /taller/input/transacciones/transactions.csv /taller/input/logs/access.log; do
  echo "--- $f"
  hdfs fsck "$f" -files -blocks -locations | grep -E "bytes, replicated|Total blocks|Average block replication|Under-replicated|Status" || true
done
