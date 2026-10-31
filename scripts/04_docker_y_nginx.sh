#!/usr/bin/env bash
#===============================================================================
# 04_docker_y_nginx.sh
# Proyecto Final - Introducción al Software Libre (ISL135) - Secciones 4 y 5
# 4.1 Instalación y configuración de Docker
# 4.2 Verificación inicial (hello-world)
# 5.1 Contenedor Nginx básico (puerto 8080, monta /proyecto/web)
# 5.2 Verificación del servicio web
#
# USO:  sudo bash /proyecto/scripts/04_docker_y_nginx.sh
# Requiere haber ejecutado antes 01_preparar_entorno.sh (usuarios y /proyecto).
# Se puede ejecutar varias veces: no duplica contenedores ni usuarios.
#===============================================================================
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Ejecuta el script con sudo (como root)."; exit 1; }

PROYECTO="/proyecto"
WEB_DIR="${PROYECTO}/web"
CONTENEDOR="nginx-basico"
USUARIO_ACTUAL="${SUDO_USER:-}"

titulo() { echo; echo "==================== $* ===================="; }

#------------------------ 4.1 Instalación y configuración ---------------------
titulo "4.1 Instalación de Docker"
apt-get update -y
apt-get install -y docker.io curl
docker --version

titulo "4.1 Habilitar e iniciar el servicio"
systemctl enable --now docker
systemctl is-active docker

titulo "4.1 Usuarios en el grupo docker (uso sin sudo)"
for u in adminsys tecnico ${USUARIO_ACTUAL:+"$USUARIO_ACTUAL"}; do
    if id "$u" &>/dev/null; then
        usermod -aG docker "$u"
        id "$u"
    else
        echo "Aviso: el usuario $u no existe. Ejecuta antes 01_preparar_entorno.sh"
    fi
done
echo "Nota: cierra sesión y vuelve a entrar para usar Docker sin sudo."

#------------------------ 4.2 Verificación inicial ----------------------------
titulo "4.2 Contenedor de prueba hello-world"
docker rm -f prueba-hello-world >/dev/null 2>&1 || true
docker run --name prueba-hello-world hello-world
docker ps -a

#------------------------ 5.1 Contenedor Nginx básico -------------------------
titulo "5.1 Archivo index.html en ${WEB_DIR}"
# El index.html personalizado del grupo se versiona en el repositorio (web/).
if [[ ! -f "${WEB_DIR}/index.html" ]]; then
    echo "No existe ${WEB_DIR}/index.html."
    echo "Trae el repositorio con 'git pull' o crea el archivo con el contenido del grupo."
    exit 1
fi
chmod 644 "${WEB_DIR}/index.html"
ls -l "${WEB_DIR}/index.html"

titulo "5.1 Contenedor ${CONTENEDOR} (8080 -> 80, segundo plano)"
docker rm -f "$CONTENEDOR" >/dev/null 2>&1 || true
docker run -d \
    --name "$CONTENEDOR" \
    --restart unless-stopped \
    -p 8080:80 \
    -v "${WEB_DIR}:/usr/share/nginx/html" \
    nginx
docker ps --filter "name=${CONTENEDOR}"

#------------------------ 5.2 Verificación del servicio web -------------------
titulo "5.2 Verificación con curl"
sleep 2
curl -s http://localhost:8080
echo
curl -sI http://localhost:8080 | head -n 1

titulo "5.2 Logs del contenedor"
docker logs --tail 20 "$CONTENEDOR"

titulo "SECCIONES 4 Y 5 COMPLETADAS"
echo "Abre http://localhost:8080 en el navegador para ver la página."
