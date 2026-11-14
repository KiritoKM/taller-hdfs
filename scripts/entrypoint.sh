#!/usr/bin/env bash
set -euo pipefail

role="${1:-}"

case "$role" in
  namenode)
    if [[ ! -f /data/name/current/VERSION ]]; then
      if [[ -n "$(find /data/name -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
        echo "NameNode directory is not empty but has no VERSION file. Refusing to format." >&2
        exit 1
      fi
      hdfs namenode -format -nonInteractive
    fi
    exec hdfs namenode
    ;;
  datanode)
    exec hdfs datanode
    ;;
  resourcemanager)
    exec yarn resourcemanager
    ;;
  nodemanager)
    exec yarn nodemanager
    ;;
  historyserver)
    # El HistoryServer crea sus directorios en HDFS al arrancar: esperamos a que
    # el NameNode salga de safemode para que no falle en el primer intento.
    until hdfs dfsadmin -safemode get 2>/dev/null | grep -q "OFF"; do
      echo "Esperando a que HDFS salga de safemode..."
      sleep 5
    done
    exec mapred historyserver
    ;;
  client)
    exec tail -f /dev/null
    ;;
  *)
    exec "$@"
    ;;
esac
