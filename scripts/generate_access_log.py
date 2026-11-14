"""Genera un log de accesos web (formato Apache combined) con horas pico.

La semilla es fija, así que el archivo es reproducible y los resultados de los
jobs se pueden validar manualmente.
"""
import argparse
import random
from datetime import datetime, timedelta
from pathlib import Path

# Peso relativo de cada hora del día: picos a media mañana y en la noche.
HOUR_WEIGHTS = [
    1, 1, 1, 1, 1, 2,        # 00-05
    4, 7, 10, 14, 18, 17,    # 06-11  (pico 10-11)
    12, 10, 9, 9, 10, 12,    # 12-17
    15, 20, 22, 16, 8, 3,    # 18-23  (pico 19-20)
]

URLS = [
    ("/", 30), ("/productos", 22), ("/productos/celulares", 14),
    ("/productos/portatiles", 12), ("/carrito", 10), ("/checkout", 6),
    ("/login", 9), ("/api/v1/precios", 8), ("/api/v1/inventario", 5),
    ("/blog/ofertas-noviembre", 7), ("/contacto", 3), ("/ayuda/envios", 4),
    ("/static/app.js", 11), ("/static/styles.css", 11), ("/favicon.ico", 6),
]

STATUSES = [(200, 86), (304, 5), (404, 5), (500, 3), (503, 1)]
METHODS = [("GET", 90), ("POST", 10)]
AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0)",
    "Mozilla/5.0 (Linux; Android 14)",
    "curl/8.5.0",
]


def weighted(rnd, pairs):
    values, weights = zip(*pairs)
    return rnd.choices(values, weights=weights, k=1)[0]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="datasets/access.log")
    parser.add_argument("--rows", type=int, default=200000)
    args = parser.parse_args()

    rnd = random.Random(2026)
    day = datetime(2026, 11, 10)
    path = Path(args.output)
    path.parent.mkdir(parents=True, exist_ok=True)

    with path.open("w", encoding="utf-8", newline="\n") as out:
        for _ in range(args.rows):
            hour = rnd.choices(range(24), weights=HOUR_WEIGHTS, k=1)[0]
            ts = day + timedelta(hours=hour, minutes=rnd.randrange(60), seconds=rnd.randrange(60))
            ip = f"181.{rnd.randint(48, 63)}.{rnd.randint(0, 255)}.{rnd.randint(1, 254)}"
            url = weighted(rnd, URLS)
            if rnd.random() < 0.15:
                url += f"?page={rnd.randint(1, 9)}"
            status = weighted(rnd, STATUSES)
            size = 0 if status == 304 else rnd.randint(200, 90000)
            out.write(
                f'{ip} - - [{ts.strftime("%d/%b/%Y:%H:%M:%S")} -0500] '
                f'"{weighted(rnd, METHODS)} {url} HTTP/1.1" {status} {size} '
                f'"-" "{rnd.choice(AGENTS)}"\n'
            )

    print(f"Generated {args.rows} log lines in {path} ({path.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
