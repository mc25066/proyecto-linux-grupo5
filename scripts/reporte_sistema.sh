#!/usr/bin/env bash
#===============================================================================
# reporte_sistema.sh
# Proyecto Final - Introducción al Software Libre (ISL135) - Sección 2.1
# Ubicación en el servidor: /proyecto/scripts/reporte_sistema.sh
#
# Muestra: fecha y hora, nombre del host, usuarios conectados, espacio libre en
# el disco principal, memoria RAM disponible y contenedores Docker activos.
# La salida se registra cada 30 minutos mediante cron (ver 02_configurar_cron.sh).
#===============================================================================

echo "=============== REPORTE DEL SISTEMA ==============="
echo "Fecha y hora        : $(date '+%Y-%m-%d %H:%M:%S')"
echo "Nombre del host     : $(hostname)"
echo "Usuarios conectados : $(who | wc -l)"
echo "Espacio libre en /  : $(df -h / | awk 'NR==2 {print $4}')"
echo "RAM disponible      : $(free -h | awk '/^Mem:/ {print $7}')"
if command -v docker >/dev/null 2>&1; then
    echo "Contenedores activos: $(docker ps -q 2>/dev/null | wc -l)"
else
    echo "Contenedores activos: Docker no instalado"
fi
echo "==================================================="
