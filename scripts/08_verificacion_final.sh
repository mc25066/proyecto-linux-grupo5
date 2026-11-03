#!/usr/bin/env bash
#===============================================================================
# 08_verificacion_final.sh
# Proyecto Final ISL135 - Grupo 5
# Seccion 8: Pruebas y verificacion final (8.1 conectividad, 8.2 integral)
#
# Uso:
#   bash /proyecto/scripts/08_verificacion_final.sh
#
# Solo consulta: no crea, modifica ni borra nada del proyecto. La unica
# excepcion es el contenedor temporal alpine-test del ping (8.1), que se borra
# solo al terminar (--rm).
#
# Requisitos: los cuatro contenedores (nginx-basico, servidor-grupo5,
# nginx-red y nginx-volumen), la red red-proyecto y el cron de la seccion 2.
# Pide la contrasena de sudo para leer el crontab de root.
#
# Comprueba:
#   8.1  ping desde un contenedor Alpine a nginx-red (por nombre)
#   8.2  puertos 8080 a 8083 respondiendo 200, contenedores en ejecucion,
#        cron activo con la tarea cada 30 minutos y el log actualizandose,
#        y repositorio Git sin cambios pendientes
#
# Termina con codigo 0 si no hay fallos y con 1 si hay alguno.
#===============================================================================
set -uo pipefail

PROYECTO="${PROYECTO:-/proyecto}"
RED="red-proyecto"
OBJETIVO="nginx-red"
LOG="${LOG:-/var/log/proyecto/reporte_sistema.log}"
SCRIPT_CRON="reporte_sistema.sh"
MAX_MIN_LOG=35

CONTENEDORES=(nginx-basico servidor-grupo5 nginx-red nginx-volumen)
PUERTOS=(8080 8081 8082 8083)

OKS=0
AVISOS=0
FALLOS=0

titulo() { echo; echo "==================== $* ===================="; }
ok()     { echo "  [OK]    $*"; OKS=$((OKS + 1)); }
aviso()  { echo "  [AVISO] $*"; AVISOS=$((AVISOS + 1)); }
fallo()  { echo "  [FALLO] $*"; FALLOS=$((FALLOS + 1)); }

# Comprobaciones previas
if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker no esta instalado. Completa primero la seccion 4." >&2
    exit 1
fi
if ! docker info >/dev/null 2>&1; then
    echo "ERROR: no se puede acceder al daemon Docker. Inicia Docker o usa sudo." >&2
    exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl no esta instalado: sudo apt install -y curl" >&2
    exit 1
fi

#------------------------ 8.1 Pruebas de conectividad -------------------------
titulo "8.1 Pruebas de conectividad: ping desde Alpine a $OBJETIVO"
if ! docker network inspect "$RED" >/dev/null 2>&1; then
    fallo "No existe la red $RED (seccion 7.1)."
elif [[ -z "$(docker ps -q --filter "name=^/${OBJETIVO}\$" --filter status=running)" ]]; then
    fallo "El contenedor $OBJETIVO no esta en ejecucion (docker start $OBJETIVO)."
else
    docker rm -f alpine-test >/dev/null 2>&1
    echo "\$ docker run --rm --name alpine-test --network $RED alpine ping -c 4 $OBJETIVO"
    SALIDA="$(docker run --rm --name alpine-test --network "$RED" alpine ping -c 4 "$OBJETIVO" 2>&1)"
    echo "$SALIDA"
    if grep -q " 0% packet loss" <<<"$SALIDA"; then
        ok "ping a $OBJETIVO por nombre sin perdida de paquetes"
    else
        fallo "el ping a $OBJETIVO tuvo perdida de paquetes o no resolvio el nombre"
    fi
fi

#---------------------- 8.2 Servicios web en cada puerto ----------------------
titulo "8.2 Servicios web: puertos 8080 a 8083"
for i in "${!PUERTOS[@]}"; do
    puerto="${PUERTOS[$i]}"
    nombre="${CONTENEDORES[$i]}"
    echo "\$ curl -I http://localhost:$puerto"
    curl -sS -I --max-time 5 "http://localhost:$puerto" 2>&1 | head -n 2
    codigo="$(curl -s -o /dev/null --max-time 5 -w '%{http_code}' "http://localhost:$puerto")"
    if [[ "$codigo" == "200" ]]; then
        ok "puerto $puerto ($nombre) responde 200"
    else
        fallo "puerto $puerto ($nombre) responde '$codigo' (se esperaba 200)"
    fi
    echo
done

#------------------------ 8.2 Contenedores en ejecucion -----------------------
titulo "8.2 Contenedores en ejecucion"
echo "\$ docker ps"
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
echo
for c in "${CONTENEDORES[@]}"; do
    if [[ -n "$(docker ps -q --filter "name=^/${c}\$" --filter status=running)" ]]; then
        ok "$c en ejecucion"
    else
        fallo "$c no esta en ejecucion (docker start $c)"
    fi
done

#--------------------------- 8.2 Script de monitoreo --------------------------
titulo "8.2 Script de monitoreo con cron"
echo "\$ systemctl is-active cron"
ESTADO="$(systemctl is-active cron 2>/dev/null)"
echo "${ESTADO:-desconocido}"
if [[ "$ESTADO" == "active" ]]; then
    ok "servicio cron activo"
else
    fallo "el servicio cron no esta activo (sudo systemctl enable --now cron)"
fi

echo
echo "\$ sudo crontab -l"
TAREA="$(sudo crontab -l 2>/dev/null | grep -F "$SCRIPT_CRON" | grep -v '^#')"
if [[ -z "$TAREA" ]]; then
    fallo "no hay tarea de cron para $SCRIPT_CRON (ejecuta 02_configurar_cron.sh)"
else
    echo "$TAREA"
    if [[ "$TAREA" == '*/30 '* ]]; then
        ok "tarea programada cada 30 minutos"
    else
        aviso "la tarea existe pero no es */30; revisa la frecuencia"
    fi
fi

echo
echo "\$ tail $LOG"
if [[ ! -f "$LOG" ]]; then
    fallo "no existe el log $LOG"
else
    ENTRADAS="$(grep -c 'REPORTE DEL SISTEMA' "$LOG")"
    echo "Reportes registrados en el log: $ENTRADAS"
    echo "Ultimas marcas de tiempo:"
    grep 'Fecha y hora' "$LOG" | tail -n 4
    EDAD=$(( ( $(date +%s) - $(stat -c %Y "$LOG") ) / 60 ))
    if [[ "$EDAD" -le "$MAX_MIN_LOG" ]]; then
        ok "el log se actualizo hace $EDAD minuto(s)"
    else
        aviso "la ultima escritura del log fue hace $EDAD minutos (cron escribe cada 30; la VM pudo estar apagada)"
    fi
fi

echo
echo "\$ sudo journalctl -u cron --since '2 hours ago' (ejecuciones de $SCRIPT_CRON)"
sudo journalctl -u cron --since '2 hours ago' 2>/dev/null | grep -F "$SCRIPT_CRON" | tail -n 3
echo "(fin de las ejecuciones registradas)"

#------------------------------ 8.2 Repositorio Git ---------------------------
titulo "8.2 Repositorio Git"
if [[ ! -d "$PROYECTO/.git" ]]; then
    fallo "no hay repositorio Git en $PROYECTO"
else
    echo "\$ git status -sb"
    git -C "$PROYECTO" status -sb
    echo
    echo "\$ git log --oneline -n 5"
    git -C "$PROYECTO" log --oneline -n 5
    echo

    if ! PENDIENTES="$(git -C "$PROYECTO" status --porcelain 2>&1)"; then
        fallo "git no pudo leer el repositorio: $PENDIENTES"
        echo "        Si dice 'dubious ownership': git config --global --add safe.directory $PROYECTO"
    elif [[ -z "$PENDIENTES" ]]; then
        ok "sin cambios pendientes en el repositorio"
    else
        fallo "hay cambios sin confirmar (git add y git commit)"
    fi

    if SIN_SUBIR="$(git -C "$PROYECTO" rev-list --count '@{u}..HEAD' 2>/dev/null)"; then
        if [[ "$SIN_SUBIR" -gt 0 ]]; then
            aviso "$SIN_SUBIR commit(s) local(es) sin subir a GitHub (git push)"
        else
            ok "todo lo confirmado ya esta en GitHub"
        fi
    else
        aviso "la rama actual no tiene remoto configurado"
    fi
fi

#---------------------------------- Resumen -----------------------------------
titulo "Resumen de la verificacion"
echo "Correctas: $OKS | Avisos: $AVISOS | Fallos: $FALLOS"
if [[ "$FALLOS" -eq 0 ]]; then
    echo "VERIFICACION FINAL SUPERADA"
    exit 0
else
    echo "VERIFICACION FINAL CON FALLOS: revisa las lineas [FALLO]"
    exit 1
fi
