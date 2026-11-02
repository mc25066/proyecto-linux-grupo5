#!/usr/bin/env bash
#===============================================================================
# 07_redes_volumenes.sh
# Proyecto Final ISL135 - Grupo 5
# Seccion 7: Redes y volumenes Docker
#
# Uso:
#   bash /proyecto/scripts/07_redes_volumenes.sh
#
# Crea:
#   - Red bridge: red-proyecto
#   - Contenedor Nginx: nginx-red, puerto host 8082 -> contenedor 80
#   - Volumen: volumen-web
#   - Contenedor Nginx: nginx-volumen, puerto host 8083 -> contenedor 80
#
# Es seguro volver a ejecutarlo: elimina y recrea solamente los dos
# contenedores administrados por este script. No elimina la red ni el volumen.
#===============================================================================
set -Eeuo pipefail

RED="red-proyecto"
VOLUMEN="volumen-web"
CONTENEDOR_RED="nginx-red"
CONTENEDOR_VOLUMEN="nginx-volumen"
IMAGEN="nginx:latest"

titulo() { echo; echo "==================== $* ===================="; }
error() { echo "ERROR: $*" >&2; exit 1; }

# Comprobar Docker y permisos
command -v docker >/dev/null 2>&1 || error "Docker no esta instalado. Completa primero la seccion 4."
docker info >/dev/null 2>&1 || error "No se puede acceder al daemon Docker. Inicia Docker o usa sudo."
command -v curl >/dev/null 2>&1 || echo "Aviso: curl no esta instalado; se omitira la prueba HTTP."

titulo "7.1 Crear la red personalizada"
if docker network inspect "$RED" >/dev/null 2>&1; then
    echo "La red $RED ya existe."
else
    docker network create --driver bridge "$RED"
fi
docker network inspect "$RED" --format 'Red: {{.Name}} | Driver: {{.Driver}}'

titulo "7.1 Ejecutar Nginx conectado a $RED"
docker rm -f "$CONTENEDOR_RED" >/dev/null 2>&1 || true
docker pull "$IMAGEN"
docker run -d \
    --name "$CONTENEDOR_RED" \
    --network "$RED" \
    --restart unless-stopped \
    -p 8082:80 \
    "$IMAGEN"

echo "Contenedor iniciado:"
docker ps --filter "name=^/${CONTENEDOR_RED}$" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo "Verificando la conexion a la red:"
docker network inspect "$RED" --format '{{range .Containers}}{{println .Name}}{{end}}'

titulo "7.2 Crear el volumen persistente"
if docker volume inspect "$VOLUMEN" >/dev/null 2>&1; then
    echo "El volumen $VOLUMEN ya existe."
else
    docker volume create "$VOLUMEN"
fi
docker volume inspect "$VOLUMEN" --format 'Volumen: {{.Name}} | Mountpoint: {{.Mountpoint}}'

titulo "7.2 Ejecutar Nginx usando el volumen"
docker rm -f "$CONTENEDOR_VOLUMEN" >/dev/null 2>&1 || true
docker run -d \
    --name "$CONTENEDOR_VOLUMEN" \
    --restart unless-stopped \
    -p 8083:80 \
    -v "$VOLUMEN":/usr/share/nginx/html \
    "$IMAGEN"

# Agrega una pagina identificable al volumen para demostrar que el contenido
# permanece aunque el contenedor se elimine y vuelva a crearse.
docker run --rm \
    -v "$VOLUMEN":/contenido \
    alpine:latest \
    sh -c 'printf "%s\n" "<!doctype html><html lang=\"es\"><head><meta charset=\"utf-8\"><title>Volumen Docker</title></head><body><h1>Seccion 7.2 - Volumen persistente</h1><p>Contenido almacenado en volumen-web.</p></body></html>" > /contenido/volumen.html'

echo "Contenedor y montaje:"
docker inspect "$CONTENEDOR_VOLUMEN" --format 'Contenedor: {{.Name}} | Estado: {{.State.Status}}{{range .Mounts}}{{printf "\nTipo: %s | Nombre: %s | Destino: %s" .Type .Name .Destination}}{{end}}'

titulo "Verificacion HTTP"
if command -v curl >/dev/null 2>&1; then
    echo "Puerto 8082 (Nginx en red personalizada):"
    curl -fsS http://localhost:8082/ >/dev/null && echo "HTTP correcto: http://localhost:8082"
    echo "Puerto 8083 (Nginx con volumen persistente):"
    curl -fsS http://localhost:8083/volumen.html
    echo
    echo "HTTP correcto: http://localhost:8083/volumen.html"
else
    echo "Abre en el navegador: http://localhost:8082 y http://localhost:8083/volumen.html"
fi

titulo "Resumen de contenedores"
docker ps --filter "name=^/${CONTENEDOR_RED}$" --filter "name=^/${CONTENEDOR_VOLUMEN}$"
echo
echo "SECCION 7 COMPLETADA"
echo "Red: $RED | Contenedor: $CONTENEDOR_RED | URL: http://localhost:8082"
echo "Volumen: $VOLUMEN | Contenedor: $CONTENEDOR_VOLUMEN | URL: http://localhost:8083/volumen.html"
echo "Para ver detalles: docker network inspect $RED"
echo "                  docker volume inspect $VOLUMEN"
