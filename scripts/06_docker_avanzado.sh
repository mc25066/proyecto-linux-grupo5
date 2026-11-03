#!/usr/bin/env bash
#===============================================================================
# 06_docker_avanzado.sh
# Proyecto Final ISL135 - Grupo 5
# Seccion 6: Docker avanzado (6.1 Dockerfile personalizado, 6.2 contenedor)
#
# Uso:
#   bash /proyecto/scripts/06_docker_avanzado.sh
#   bash /proyecto/scripts/06_docker_avanzado.sh --sin-comparacion
#
# Requisitos: Docker instalado (seccion 4), y en su lugar /proyecto/Dockerfile
# (seccion 6.1) y /proyecto/web/index.html (seccion 5.1).
#
# Hace:
#   6.1  Construye la imagen servidor-grupo5 a partir de /proyecto/Dockerfile
#   6.2  Ejecuta el contenedor servidor-grupo5 (puerto host 8081 -> 80)
#        y lo compara con el Nginx oficial (nginx-basico, puerto 8080, con la
#        carpeta web/ montada)
#
# Es seguro volver a ejecutarlo: solo recrea el contenedor servidor-grupo5.
# La comparacion agrega una marca temporal al final de web/index.html y la
# quita al terminar (incluso si el script falla), dejando el archivo igual.
# Con --sin-comparacion no se toca el index.html.
#===============================================================================
set -Eeuo pipefail

PROYECTO="${PROYECTO:-/proyecto}"
IMAGEN="servidor-grupo5"
CONTENEDOR="servidor-grupo5"
PUERTO="8081"
OFICIAL="nginx-basico"
PUERTO_OFICIAL="8080"
INDEX="$PROYECTO/web/index.html"
MARCA="CAMBIO_DE_PRUEBA_6_2"
BACKUP=""

COMPARAR=1
case "${1:-}" in
    "") ;;
    --sin-comparacion) COMPARAR=0 ;;
    *) echo "Uso: bash $0 [--sin-comparacion]" >&2; exit 1 ;;
esac

titulo() { echo; echo "==================== $* ===================="; }
error() { echo "ERROR: $*" >&2; exit 1; }

# Espera hasta 20 segundos a que una URL responda con exito
esperar_http() {
    local url="$1" i
    for i in $(seq 1 20); do
        if curl -fsS -o /dev/null "$url" 2>/dev/null; then
            return 0
        fi
        sleep 1
    done
    return 1
}

# Devuelve a index.html su contenido original (se llama sola al salir)
restaurar_index() {
    if [[ -n "$BACKUP" && -f "$BACKUP" ]]; then
        cat "$BACKUP" > "$INDEX"
        rm -f "$BACKUP"
        BACKUP=""
        echo "index.html restaurado a su contenido original."
    fi
}
trap restaurar_index EXIT

# Muestra el comando y su resultado; devuelve 0 si la marca aparece
mostrar_marca() {
    local url="$1" salida
    echo "\$ curl -s $url | grep $MARCA"
    salida="$(curl -fsS "$url" | grep "$MARCA" || true)"
    if [[ -n "$salida" ]]; then
        echo "$salida"
    else
        echo "(sin resultados)"
    fi
    [[ -n "$salida" ]]
}

# Comprobaciones previas
command -v docker >/dev/null 2>&1 || error "Docker no esta instalado. Completa primero la seccion 4."
docker info >/dev/null 2>&1 || error "No se puede acceder al daemon Docker. Inicia Docker o usa sudo."
command -v curl >/dev/null 2>&1 || error "curl no esta instalado: sudo apt install -y curl"
[[ -f "$PROYECTO/Dockerfile" ]] || error "No existe $PROYECTO/Dockerfile (seccion 6.1)."
[[ -f "$INDEX" ]] || error "No existe $INDEX (seccion 5.1)."

#------------------------ 6.1 Dockerfile personalizado ------------------------
titulo "6.1 Dockerfile personalizado"
echo "\$ cat $PROYECTO/Dockerfile"
cat "$PROYECTO/Dockerfile"

titulo "6.1 Construir la imagen $IMAGEN"
echo "\$ docker build -t $IMAGEN $PROYECTO"
docker build -t "$IMAGEN" "$PROYECTO"
echo
echo "\$ docker images $IMAGEN"
docker images "$IMAGEN"

#--------------------- 6.2 Contenedor con imagen personalizada ----------------
titulo "6.2 Ejecutar el contenedor $CONTENEDOR (puerto $PUERTO)"
docker rm -f "$CONTENEDOR" >/dev/null 2>&1 || true
echo "\$ docker run -d --name $CONTENEDOR -p $PUERTO:80 $IMAGEN"
docker run -d --name "$CONTENEDOR" -p "$PUERTO":80 "$IMAGEN"
echo
docker ps --filter "name=^/${CONTENEDOR}\$" --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

titulo "6.2 Verificar el servidor en el puerto $PUERTO"
esperar_http "http://localhost:$PUERTO" || error "El puerto $PUERTO no responde. Revisa: docker logs $CONTENEDOR"
echo "\$ curl http://localhost:$PUERTO"
curl -fsS "http://localhost:$PUERTO"
echo
echo "HTTP correcto: http://localhost:$PUERTO"

#---------------------- Comparacion con el Nginx oficial ----------------------
if [[ "$COMPARAR" -eq 1 ]]; then
    titulo "6.2 Comparacion con el Nginx oficial ($OFICIAL, puerto $PUERTO_OFICIAL)"

    # El Nginx oficial debe estar corriendo con la carpeta web/ montada
    if docker ps -a --format '{{.Names}}' | grep -qx "$OFICIAL"; then
        docker start "$OFICIAL" >/dev/null
    else
        docker run -d --name "$OFICIAL" -p "$PUERTO_OFICIAL":80 \
            -v "$PROYECTO/web":/usr/share/nginx/html nginx >/dev/null
    fi
    esperar_http "http://localhost:$PUERTO_OFICIAL" || error "El puerto $PUERTO_OFICIAL no responde. Revisa: docker logs $OFICIAL"

    if [[ ! -w "$INDEX" ]]; then
        echo "Aviso: no hay permiso de escritura en $INDEX; se omite la comparacion."
    else
        BACKUP="$(mktemp)"
        cat "$INDEX" > "$BACKUP"
        printf '<!-- %s -->\n' "$MARCA" >> "$INDEX"
        echo "Se agrego una marca temporal al final de index.html ($MARCA)."
        echo

        EN_OFICIAL=0
        EN_PERSONAL=0
        mostrar_marca "http://localhost:$PUERTO_OFICIAL" && EN_OFICIAL=1
        echo
        mostrar_marca "http://localhost:$PUERTO" && EN_PERSONAL=1
        echo

        if [[ "$EN_OFICIAL" -eq 1 && "$EN_PERSONAL" -eq 0 ]]; then
            echo "RESULTADO:"
            echo "  - El contenedor del $PUERTO_OFICIAL ($OFICIAL) refleja el cambio al instante,"
            echo "    porque monta la carpeta $PROYECTO/web."
            echo "  - El contenedor del $PUERTO ($CONTENEDOR) NO cambia hasta reconstruir la imagen,"
            echo "    porque el contenido quedo copiado dentro de ella (COPY)."
        else
            echo "AVISO: resultado inesperado (8080 con marca: $EN_OFICIAL, 8081 con marca: $EN_PERSONAL)."
        fi

        echo
        restaurar_index
        if grep -q "$MARCA" "$INDEX"; then
            echo "AVISO: la marca sigue en $INDEX; quitala a mano."
        else
            echo "Verificado: $INDEX ya no tiene la marca de prueba."
        fi
    fi
fi

titulo "Resumen"
docker ps --filter "name=^/${CONTENEDOR}\$" --filter "name=^/${OFICIAL}\$" \
    --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
echo
echo "SECCION 6 COMPLETADA"
echo "Imagen: $IMAGEN | Contenedor: $CONTENEDOR | URL: http://localhost:$PUERTO"
