#!/usr/bin/env bash
#===============================================================================
# 01_preparar_entorno.sh
# Proyecto Final - Introducción al Software Libre (ISL135) - Ciclo II 2026
# Sección 1: Preparación del entorno servidor (1.1 y 1.2)
#
# REQUISITOS MÍNIMOS DEL SERVIDOR
#   - Anfitrión : macOS con UTM (Apple Virtualization o QEMU)
#   - SO invitado: Ubuntu Server 22.04/24.04 LTS o Debian 12, 64 bits
#                  (imagen ARM64 si el Mac tiene procesador Apple Silicon)
#   - Recursos VM: 2 vCPU, 2 GB de RAM (4 GB recomendado para Docker), 20 GB de disco
#   - Red        : acceso a Internet y un usuario con privilegios de sudo
#   - Paquetes   : bash, cron, procps y coreutils (incluidos por defecto)
#
# USO:  sudo bash 01_preparar_entorno.sh [numero_de_grupo]    (por defecto: 5)
#
# Deja en la misma carpeta los 4 archivos: 01_preparar_entorno.sh,
# 02_configurar_cron.sh, 03_inicializar_git.sh y reporte_sistema.sh.
# Al final, este script los instala en /proyecto/scripts/.
#
# NOTA: el usuario "técnico" del enunciado se crea como "tecnico" (sin tilde),
#       porque los nombres de usuario en Linux deben evitar caracteres acentuados.
# NOTA: no se guardan contraseñas en el script; se piden por teclado (passwd).
#===============================================================================
set -euo pipefail

GRUPO="${1:-5}"
[[ "$GRUPO" =~ ^[0-9]+$ ]] || { echo "El número de grupo debe ser numérico."; exit 1; }
[[ $EUID -eq 0 ]]          || { echo "Ejecuta el script con sudo (como root)."; exit 1; }

HOST_NUEVO="servidor-grupo${GRUPO}"
PROYECTO="/proyecto"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

titulo() { echo; echo "==================== $* ===================="; }

#------------------------ 1.1 Administración básica ---------------------------
titulo "1.1 Nombre del host: ${HOST_NUEVO}"
hostnamectl set-hostname "$HOST_NUEVO"
# Mantener /etc/hosts coherente para evitar el aviso "unable to resolve host"
if grep -qE '^127\.0\.1\.1' /etc/hosts; then
    sed -i -E "s/^127\.0\.1\.1.*/127.0.1.1 ${HOST_NUEVO}/" /etc/hosts
else
    echo "127.0.1.1 ${HOST_NUEVO}" >> /etc/hosts
fi
hostnamectl

titulo "1.1 Grupos: soporte y web"
for g in soporte web; do
    getent group "$g" >/dev/null || groupadd "$g"
done
getent group soporte web

titulo "1.1 Usuarios: adminsys, tecnico, visitante"
NUEVOS=()
for u in adminsys tecnico visitante; do
    if id "$u" &>/dev/null; then
        echo "El usuario $u ya existe."
    else
        useradd -m -s /bin/bash "$u"
        echo "Usuario $u creado."
        NUEVOS+=("$u")
    fi
done
for u in "${NUEVOS[@]}"; do
    echo "Asigna la contraseña de $u:"
    passwd "$u" || echo "Pendiente: ejecuta 'sudo passwd $u' más tarde."
done

titulo "1.1 Asignación de usuarios a grupos"
# Debian/Ubuntu usan el grupo "sudo"; RHEL/Fedora usan "wheel"
ADMIN_GROUP="$(getent group sudo >/dev/null && echo sudo || echo wheel)"
usermod -aG "$ADMIN_GROUP" adminsys    # adminsys  -> privilegios de sudo
usermod -aG soporte        tecnico     # tecnico   -> soporte
usermod -aG web            visitante   # visitante -> web
for u in adminsys tecnico visitante; do id "$u"; done

#------------------- 1.2 Estructura de directorios y permisos -----------------
titulo "1.2 Estructura de directorios en ${PROYECTO}"
mkdir -p "$PROYECTO"/{datos,web,scripts,capturas}
chown adminsys:adminsys "$PROYECTO" "$PROYECTO/scripts" "$PROYECTO/capturas"
chown adminsys:soporte  "$PROYECTO/datos"     # datos/ -> grupo soporte
chown adminsys:web      "$PROYECTO/web"       # web/   -> grupo web
# El "2" de 2775 es el bit setgid: los archivos nuevos heredan el grupo del directorio
chmod 2775 "$PROYECTO/datos" "$PROYECTO/web"
chmod 755  "$PROYECTO" "$PROYECTO/scripts" "$PROYECTO/capturas"
ls -ld "$PROYECTO" "$PROYECTO"/*

titulo "1.2 Prueba de herencia de grupo"
sudo -u tecnico   touch "$PROYECTO/datos/prueba_herencia.tmp" || echo "FALLO en datos/"
sudo -u visitante touch "$PROYECTO/web/prueba_herencia.tmp"   || echo "FALLO en web/"
ls -l "$PROYECTO/datos/prueba_herencia.tmp" "$PROYECTO/web/prueba_herencia.tmp"
rm -f "$PROYECTO/datos/prueba_herencia.tmp" "$PROYECTO/web/prueba_herencia.tmp"

#------------------- Instalación de los scripts en /proyecto/scripts ----------
titulo "Instalación de los scripts en ${PROYECTO}/scripts"
if [[ "$SCRIPT_DIR" != "$PROYECTO/scripts" ]]; then
    for f in 01_preparar_entorno.sh 02_configurar_cron.sh 03_inicializar_git.sh reporte_sistema.sh; do
        if [[ -f "$SCRIPT_DIR/$f" ]]; then
            install -m 755 -o adminsys -g adminsys "$SCRIPT_DIR/$f" "$PROYECTO/scripts/$f"
        else
            echo "Aviso: no se encontró $f en $SCRIPT_DIR"
        fi
    done
fi
ls -l "$PROYECTO/scripts"

titulo "SECCIÓN 1 COMPLETADA"
echo "Host: $(hostname)  |  Proyecto: ${PROYECTO}"
echo "Siguiente paso: sudo bash ${PROYECTO}/scripts/02_configurar_cron.sh"
