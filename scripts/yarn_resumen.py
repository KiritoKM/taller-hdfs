#!/usr/bin/env python3
"""Resumen de los jobs consultando las APIs REST de YARN y del JobHistory Server.

  python3 scripts/yarn_resumen.py            -> tabla de aplicaciones y jobs
  python3 scripts/yarn_resumen.py failed-id  -> imprime el id del último job con finalStatus FAILED
"""
import json
import sys
import urllib.request

RM = "http://resourcemanager:8088/ws/v1/cluster/apps"
JHS = "http://historyserver:19888/ws/v1/history/mapreduce/jobs"


def get(url):
    with urllib.request.urlopen(url, timeout=10) as resp:
        return json.load(resp)


apps = sorted((get(RM).get("apps") or {}).get("app", []), key=lambda a: a["id"])

if len(sys.argv) > 1 and sys.argv[1] == "failed-id":
    failed = [a["id"] for a in apps if a["finalStatus"] == "FAILED"]
    print(failed[-1] if failed else "")
    sys.exit(0)

print("Aplicaciones (ResourceManager):")
for a in apps:
    print(f"  {a['id']}  {a['name']:<28} state={a['state']:<9} final={a['finalStatus']:<10} "
          f"{a['elapsedTime'] // 1000:>4}s  nodo-AM={a.get('amHostHttpAddress', '-')}")

print("\nJobs MapReduce (JobHistory Server):")
jobs = sorted((get(JHS).get("jobs") or {}).get("job", []), key=lambda j: j["id"])
for j in jobs:
    detail = get(f"{JHS}/{j['id']}")["job"]
    print(f"  {j['id']}  {j['name']:<28} {j['state']:<9} "
          f"maps {j['mapsCompleted']}/{j['mapsTotal']}  reduces {j['reducesCompleted']}/{j['reducesTotal']}  "
          f"intentos map: ok={detail['successfulMapAttempts']} failed={detail['failedMapAttempts']} "
          f"killed={detail['killedMapAttempts']}")
