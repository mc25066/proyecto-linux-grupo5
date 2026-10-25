#!/usr/bin/env bash
#===============================================================================
# 03_inicializar_git.sh
# Proyecto Final - Introducción al Software Libre (ISL135) - Sección 3
# Inicializa el repositorio Git en /proyecto, hace el primer commit y lo asocia
# al repositorio remoto de GitHub "proyecto-linux-grupo5".
#
# USO (como adminsys, NO como root):
#   bash /proyecto/scripts/03_inicializar_git.sh <usuario_github> [https|ssh]
#   Ejemplo: bash /proyecto/scripts/03_inicializar_git.sh jorgemelendez https
#
# Variables opcionales:  GRUPO (por defecto 5), VISIBILIDAD (public|private,
#                        por defecto public; solo aplica si se usa la CLI "gh")
#
# AUTENTICACIÓN: no se guardan credenciales en el script.
#   - HTTPS: GitHub pide usuario y un Personal Access Token (no la contraseña).
#   - SSH  : requiere una llave pública agregada en GitHub (Settings > SSH keys).
#   - Opción cómoda: instalar la CLI y ejecutar "gh auth login" antes del script.
#===============================================================================
set -euo pipefail

GITHUB_USER="${1:-}"
PROTOCOLO="${2:-https}"
GRUPO="${GRUPO:-5}"
VISIBILIDAD="${VISIBILIDAD:-public}"
REPO="proyecto-linux-grupo${GRUPO}"
PROYECTO="${PROYECTO:-/proyecto}"
RAMA="main"

titulo() { echo; echo "==================== $* ===================="; }

[[ -n "$GITHUB_USER" ]] || { echo "Uso: bash $0 <usuario_github> [https|ssh]"; exit 1; }
[[ "$PROTOCOLO" == "https" || "$PROTOCOLO" == "ssh" ]] || { echo "Protocolo: https o ssh."; exit 1; }
[[ $EUID -ne 0 ]] || { echo "No ejecutes este script como root. Usa: su - adminsys"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "Git no está instalado: sudo apt install -y git"; exit 1; }
[[ -d "$PROYECTO" ]] || { echo "No existe ${PROYECTO}. Ejecuta antes 01_preparar_entorno.sh"; exit 1; }

if [[ "$PROTOCOLO" == "ssh" ]]; then
    URL="git@github.com:${GITHUB_USER}/${REPO}.git"
else
    URL="https://github.com/${GITHUB_USER}/${REPO}.git"
fi
URL="${URL_REMOTA:-$URL}"

cd "$PROYECTO"

#------------------------- Repositorio local ----------------------------------
titulo "3.1 Inicialización del repositorio en ${PROYECTO}"
if [[ -d .git ]]; then
    echo "El repositorio ya estaba inicializado."
else
    git init -b "$RAMA" 2>/dev/null || { git init; git symbolic-ref HEAD "refs/heads/${RAMA}"; }
fi

# Identidad para los commits (cada integrante debe usar la suya)
if [[ -z "$(git config user.name || true)" ]]; then
    read -rp "Tu nombre completo (aparecerá en los commits): " NOMBRE
    git config user.name "$NOMBRE"
fi
if [[ -z "$(git config user.email || true)" ]]; then
    read -rp "Tu correo (el mismo de tu cuenta de GitHub): " CORREO
    git config user.email "$CORREO"
fi
echo "Autor de los commits: $(git config user.name) <$(git config user.email)>"

titulo "3.1 Archivos base de la estructura"
if [[ ! -f .gitignore ]]; then
cat > .gitignore <<'EOF'
# Archivos temporales y de editores
*.swp
*.swo
*~
.DS_Store

# Registros y secretos (nunca subir credenciales)
*.log
.env
*.key
*.pem
EOF
fi
# Git no versiona directorios vacíos: .gitkeep conserva la estructura
for d in datos web capturas; do
    [[ -d "$d" ]] && touch "$d/.gitkeep"
done

titulo "3.1 Primer commit"
git add -A
if git diff --cached --quiet; then
    echo "No hay cambios nuevos para confirmar."
else
    git commit -m "Estructura inicial del proyecto Linux grupo ${GRUPO}"
fi

#------------------------- Repositorio remoto (GitHub) ------------------------
titulo "3.2 Repositorio remoto: ${GITHUB_USER}/${REPO}"
if git remote get-url origin &>/dev/null; then
    echo "El remoto 'origin' ya existe: $(git remote get-url origin)"
else
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        echo "Creando el repositorio con la CLI de GitHub (${VISIBILIDAD})..."
        gh repo create "${GITHUB_USER}/${REPO}" "--${VISIBILIDAD}" \
            --description "Proyecto final ISL135 - Servidor Linux automatizado con Docker (Grupo ${GRUPO})" \
            --source=. --remote=origin \
            || echo "Aviso: no se pudo crear con gh (¿ya existe?). Se intentará asociar el remoto."
    fi
    if ! git remote get-url origin &>/dev/null; then
        echo "Crea el repositorio VACÍO '${REPO}' en https://github.com/new"
        echo "(sin README, sin .gitignore y sin licencia) y luego presiona Enter."
        read -r _
        git remote add origin "$URL"
    fi
fi

titulo "3.2 Envío del código a GitHub"
git push -u origin "$RAMA" || {
    echo "Falló el push. Revisa la autenticación (token de acceso o llave SSH) y vuelve a ejecutar."
    exit 1
}

titulo "Verificación"
git remote -v
git log --oneline -n 5
git status -sb

titulo "SECCIÓN 3 COMPLETADA"
echo "Siguiente paso: crear README.md (descripción y pasos de instalación) y subirlo:"
echo "   git add README.md && git commit -m 'Agrega README' && git push"
