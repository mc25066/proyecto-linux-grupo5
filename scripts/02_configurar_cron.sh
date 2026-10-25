#!/usr/bin/env bash
#===============================================================================
# 02_configurar_cron.sh
# Proyecto Final - Introducción al Software Libre (ISL135) - Sección 2
# 2.1 Permisos de ejecución de reporte_sistema.sh
# 2.2 Tarea de cron cada 30 minutos y registro en /var/log/proyecto/
#
# USO:  sudo bash /proyecto/scripts/02_configurar_cron.sh
# Requiere haber ejecutado antes 01_preparar_entorno.sh.
#===============================================================================
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Ejecuta el script con sudo (como root)."; exit 1; }

PROYECTO="/proyecto"
SCRIPT_REPORTE="${PROYECTO}/scripts/reporte_sistema.sh"
LOG_DIR="/var/log/proyecto"
LOG_FILE="${LOG_DIR}/reporte_sistema.log"

titulo() { echo; echo "==================== $* ===================="; }

#---------------------- 2.1 Script de monitoreo: permisos ---------------------
titulo "2.1 Permisos de ejecución de reporte_sistema.sh"
if [[ ! -f "$SCRIPT_REPORTE" ]]; then
    echo "No existe ${SCRIPT_REPORTE}."
    echo "Ejecuta primero 01_preparar_entorno.sh o copia reporte_sistema.sh a ${PROYECTO}/scripts/."
    exit 1
fi
chown adminsys:adminsys "$SCRIPT_REPORTE"
chmod 755 "$SCRIPT_REPORTE"
ls -l "$SCRIPT_REPORTE"
echo "--- Salida de prueba ---"
"$SCRIPT_REPORTE"

#---------------------------- 2.2 Automatización con cron ---------------------
titulo "2.2 Servicio cron"
if ! command -v crontab >/dev/null 2>&1; then
    apt-get update -y && apt-get install -y cron
fi
# Debian/Ubuntu: servicio "cron"; RHEL/Fedora: "crond"
systemctl enable --now cron 2>/dev/null || systemctl enable --now crond

titulo "2.2 Directorio y archivo de registro: ${LOG_FILE}"
mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 755 "$LOG_DIR"
chmod 644 "$LOG_FILE"
ls -ld "$LOG_DIR"
ls -l  "$LOG_FILE"

titulo "2.2 Tarea programada cada 30 minutos (crontab de root)"
CRON_LINE="*/30 * * * * ${SCRIPT_REPORTE} >> ${LOG_FILE} 2>&1"
# Reemplaza la línea si ya existía, para no duplicar la tarea
( crontab -l 2>/dev/null | grep -v -F "reporte_sistema.sh" || true
  echo "$CRON_LINE" ) | crontab -
crontab -l

titulo "2.2 Verificación inicial del registro"
# Primera ejecución manual para comprobar que el log se escribe correctamente
"$SCRIPT_REPORTE" >> "$LOG_FILE" 2>&1
tail -n 12 "$LOG_FILE"

titulo "SECCIÓN 2 COMPLETADA"
echo "Para confirmar que cron escribe solo, espera 30 minutos y ejecuta:"
echo "   tail -n 20 ${LOG_FILE}              (debe aparecer una entrada nueva)"
echo "   journalctl -u cron --since '1 hour ago'"
echo
echo "Siguiente paso (como adminsys): bash ${PROYECTO}/scripts/03_inicializar_git.sh <usuario_github>"
