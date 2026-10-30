#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# PlaybackGuard — Instalador Universal en 1 Comando (Emby & Jellyfin)
# Detecta contenedores Docker e instalaciones nativas automáticamente
# No requiere compilar ni instalar .NET SDK en la máquina del usuario.
# ==============================================================================

REPO_RAW_BASE="${PLAYBACKGUARD_REPO_RAW:-https://raw.githubusercontent.com/pituntiDEV/playback-guard-plugin/main}"
TMP_DIR="$(mktemp -d)"
chmod 755 "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "============================================================"
echo "  Instalador Automático de PlaybackGuard (Emby & Jellyfin)"
echo "============================================================"

# Si se ejecuta desde una copia local del repositorio, usa los archivos locales; si no, los descarga de GitHub
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || pwd)"
if [[ -f "$SCRIPT_DIR/dist/emby/PlaybackGuard.Emby.dll" && -f "$SCRIPT_DIR/dist/jellyfin/PlaybackGuard.Jellyfin.dll" ]]; then
    echo "[*] Usando binarios locales en $SCRIPT_DIR/dist/..."
    cp "$SCRIPT_DIR/dist/emby/PlaybackGuard.Emby.dll" "$TMP_DIR/PlaybackGuard.Emby.dll"
    cp "$SCRIPT_DIR/dist/jellyfin/PlaybackGuard.Jellyfin.dll" "$TMP_DIR/PlaybackGuard.Jellyfin.dll"
    cp "$SCRIPT_DIR/dist/jellyfin/meta.json" "$TMP_DIR/meta.json"
    if [[ -f "$SCRIPT_DIR/dist/jellyfin/thumb.png" ]]; then
        cp "$SCRIPT_DIR/dist/jellyfin/thumb.png" "$TMP_DIR/thumb.png"
    fi
else
    echo "[*] Descargando última versión compilada desde GitHub..."
    curl -fsSL "$REPO_RAW_BASE/dist/emby/PlaybackGuard.Emby.dll" -o "$TMP_DIR/PlaybackGuard.Emby.dll"
    curl -fsSL "$REPO_RAW_BASE/dist/jellyfin/PlaybackGuard.Jellyfin.dll" -o "$TMP_DIR/PlaybackGuard.Jellyfin.dll"
    curl -fsSL "$REPO_RAW_BASE/dist/jellyfin/meta.json" -o "$TMP_DIR/meta.json"
    curl -fsSL "$REPO_RAW_BASE/dist/jellyfin/thumb.png" -o "$TMP_DIR/thumb.png" 2>/dev/null || true
fi

chmod 644 "$TMP_DIR"/* 2>/dev/null || true

INSTALLED_ANY=0

# ------------------------------------------------------------------------------
# 1. Detectar contenedores Docker de Emby y Jellyfin (si Docker está activo)
# ------------------------------------------------------------------------------
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    # Buscar contenedores Emby
    EMBY_CONTAINERS="$(docker ps --format '{{.Names}} {{.Image}}' 2>/dev/null | awk 'tolower($0) ~ /emby/ {print $1}' || true)"
    for cname in $EMBY_CONTAINERS; do
        [[ -z "$cname" ]] && continue
        echo "[+] Contenedor Docker Emby detectado: $cname"
        docker exec "$cname" mkdir -p /config/plugins
        docker cp "$TMP_DIR/PlaybackGuard.Emby.dll" "$cname:/config/plugins/PlaybackGuard.Emby.dll"
        docker exec "$cname" chmod 664 /config/plugins/PlaybackGuard.Emby.dll 2>/dev/null || true
        docker restart "$cname" >/dev/null
        echo "    -> PlaybackGuard instalado y contenedor '$cname' reiniciado."
        INSTALLED_ANY=1
    done

    # Buscar contenedores Jellyfin
    JELLYFIN_CONTAINERS="$(docker ps --format '{{.Names}} {{.Image}}' 2>/dev/null | awk 'tolower($0) ~ /jellyfin/ {print $1}' || true)"
    for cname in $JELLYFIN_CONTAINERS; do
        [[ -z "$cname" ]] && continue
        echo "[+] Contenedor Docker Jellyfin detectado: $cname"
        docker exec "$cname" mkdir -p /config/plugins/PlaybackGuard
        docker cp "$TMP_DIR/PlaybackGuard.Jellyfin.dll" "$cname:/config/plugins/PlaybackGuard/PlaybackGuard.Jellyfin.dll"
        docker cp "$TMP_DIR/meta.json" "$cname:/config/plugins/PlaybackGuard/meta.json"
        if [[ -f "$TMP_DIR/thumb.png" ]]; then
            docker cp "$TMP_DIR/thumb.png" "$cname:/config/plugins/PlaybackGuard/thumb.png"
        fi
        docker exec "$cname" chmod -R 755 /config/plugins/PlaybackGuard 2>/dev/null || true
        docker restart "$cname" >/dev/null
        echo "    -> PlaybackGuard instalado y contenedor '$cname' reiniciado."
        INSTALLED_ANY=1
    done
fi

# ------------------------------------------------------------------------------
# 2. Detectar instalaciones NATIVAS de Emby en Linux (sin Docker)
# ------------------------------------------------------------------------------
declare -A EMBY_NATIVE_DIRS=()

# 2a. Revisar /etc/emby-server.conf si existe
if [[ -f "/etc/emby-server.conf" ]]; then
    CONF_DATA="$(grep -E '^EMBY_DATA=' /etc/emby-server.conf 2>/dev/null | tail -n 1 | cut -d= -f2- | tr -d '"'\''' || true)"
    if [[ -n "$CONF_DATA" && -d "$CONF_DATA" ]]; then
        EMBY_NATIVE_DIRS["$CONF_DATA"]=1
    fi
fi

# 2b. Detectar parámetro -programdata del proceso EmbyServer en ejecución (si no es el de un contenedor /config)
while IFS= read -r proc_line; do
    [[ -z "$proc_line" ]] && continue
    PDATA="$(echo "$proc_line" | sed -n 's/.*-programdata[= ]\([^ ]*\).*/\1/p' | tr -d '"'\''' || true)"
    if [[ -n "$PDATA" && "$PDATA" != "/config" && -d "$PDATA" ]]; then
        EMBY_NATIVE_DIRS["$PDATA"]=1
    fi
done < <(ps -eo args 2>/dev/null | grep -E '[E]mbyServer|[e]mby-server' || true)

# 2c. Revisar rutas estándar nativas de Emby en Linux
for candidate in "/var/lib/emby" "/var/lib/emby-server" "/opt/emby-server/programdata" "/home/emby"; do
    if [[ -d "$candidate" ]]; then
        # Verificar que parece un directorio de Emby (contiene config, data, plugins o logs, o existe el servicio emby-server)
        if [[ -d "$candidate/config" || -d "$candidate/data" || -d "$candidate/plugins" || -f "/usr/lib/systemd/system/emby-server.service" || -f "/lib/systemd/system/emby-server.service" || -d "/opt/emby-server" ]]; then
            EMBY_NATIVE_DIRS["$candidate"]=1
        fi
    fi
done

# Si el paquete nativo /opt/emby-server existe pero aún no se ha creado /var/lib/emby
if [[ ${#EMBY_NATIVE_DIRS[@]} -eq 0 && ( -d "/opt/emby-server" || -f "/usr/lib/systemd/system/emby-server.service" || -f "/lib/systemd/system/emby-server.service" ) ]]; then
    mkdir -p /var/lib/emby
    EMBY_NATIVE_DIRS["/var/lib/emby"]=1
fi

EMBY_NATIVE_INSTALLED=0
for emby_dir in "${!EMBY_NATIVE_DIRS[@]}"; do
    echo "[+] Instalación nativa de Emby detectada en: $emby_dir"
    mkdir -p "$emby_dir/plugins"
    cp -f "$TMP_DIR/PlaybackGuard.Emby.dll" "$emby_dir/plugins/PlaybackGuard.Emby.dll"

    # Ajustar propietario y permisos para que el usuario 'emby' pueda leer y auto-actualizar el plugin
    DIR_OWNER="$(stat -c '%U:%G' "$emby_dir" 2>/dev/null || echo "")"
    if id "emby" >/dev/null 2>&1; then
        chown -R emby:emby "$emby_dir/plugins" 2>/dev/null || chown emby "$emby_dir/plugins/PlaybackGuard.Emby.dll" 2>/dev/null || true
    elif [[ -n "$DIR_OWNER" && "$DIR_OWNER" != "root:root" ]]; then
        chown -R "$DIR_OWNER" "$emby_dir/plugins" 2>/dev/null || true
    fi
    chmod 755 "$emby_dir/plugins" 2>/dev/null || true
    chmod 664 "$emby_dir/plugins/PlaybackGuard.Emby.dll" 2>/dev/null || true

    echo "    -> Copiado en $emby_dir/plugins/PlaybackGuard.Emby.dll (permisos ajustados)."
    EMBY_NATIVE_INSTALLED=1
    INSTALLED_ANY=1
done

if [[ "$EMBY_NATIVE_INSTALLED" -eq 1 ]]; then
    echo "[*] Reiniciando servicio nativo emby-server..."
    systemctl restart emby-server 2>/dev/null || service emby-server restart 2>/dev/null || true
    echo "    -> Servicio emby-server reiniciado."
fi

# ------------------------------------------------------------------------------
# 3. Detectar instalaciones NATIVAS de Jellyfin en Linux (sin Docker)
# ------------------------------------------------------------------------------
declare -A JELLYFIN_NATIVE_DIRS=()

if [[ -f "/etc/default/jellyfin" ]]; then
    JF_DATA="$(grep -E '^JELLYFIN_DATA_DIR=' /etc/default/jellyfin 2>/dev/null | tail -n 1 | cut -d= -f2- | tr -d '"'\''' || true)"
    if [[ -n "$JF_DATA" && -d "$JF_DATA" ]]; then
        JELLYFIN_NATIVE_DIRS["$JF_DATA"]=1
    fi
fi

for candidate in "/var/lib/jellyfin"; do
    if [[ -d "$candidate" ]]; then
        JELLYFIN_NATIVE_DIRS["$candidate"]=1
    fi
done

JELLYFIN_NATIVE_INSTALLED=0
for jf_dir in "${!JELLYFIN_NATIVE_DIRS[@]}"; do
    echo "[+] Instalación nativa de Jellyfin detectada en: $jf_dir"
    mkdir -p "$jf_dir/plugins/PlaybackGuard"
    cp -f "$TMP_DIR/PlaybackGuard.Jellyfin.dll" "$jf_dir/plugins/PlaybackGuard/PlaybackGuard.Jellyfin.dll"
    cp -f "$TMP_DIR/meta.json" "$jf_dir/plugins/PlaybackGuard/meta.json"
    if [[ -f "$TMP_DIR/thumb.png" ]]; then
        cp -f "$TMP_DIR/thumb.png" "$jf_dir/plugins/PlaybackGuard/thumb.png"
    fi

    DIR_OWNER="$(stat -c '%U:%G' "$jf_dir" 2>/dev/null || echo "")"
    if id "jellyfin" >/dev/null 2>&1; then
        chown -R jellyfin:jellyfin "$jf_dir/plugins/PlaybackGuard" 2>/dev/null || true
    elif [[ -n "$DIR_OWNER" && "$DIR_OWNER" != "root:root" ]]; then
        chown -R "$DIR_OWNER" "$jf_dir/plugins/PlaybackGuard" 2>/dev/null || true
    fi
    chmod 755 "$jf_dir/plugins" "$jf_dir/plugins/PlaybackGuard" 2>/dev/null || true
    chmod 664 "$jf_dir/plugins/PlaybackGuard/"* 2>/dev/null || true

    echo "    -> Copiado en $jf_dir/plugins/PlaybackGuard/ (permisos ajustados)."
    JELLYFIN_NATIVE_INSTALLED=1
    INSTALLED_ANY=1
done

if [[ "$JELLYFIN_NATIVE_INSTALLED" -eq 1 ]]; then
    echo "[*] Reiniciando servicio nativo jellyfin..."
    systemctl restart jellyfin 2>/dev/null || service jellyfin restart 2>/dev/null || true
    echo "    -> Servicio jellyfin reiniciado."
fi

# ------------------------------------------------------------------------------
# 4. Resultado final
# ------------------------------------------------------------------------------
if [[ "$INSTALLED_ANY" -eq 0 ]]; then
    echo "[!] No se detectó ningún contenedor activo ni carpeta estándar."
    echo "    Los archivos descargados se guardaron en ./playbackguard-plugins/"
    mkdir -p ./playbackguard-plugins/emby ./playbackguard-plugins/jellyfin/PlaybackGuard
    cp -f "$TMP_DIR/PlaybackGuard.Emby.dll" ./playbackguard-plugins/emby/
    cp -f "$TMP_DIR/PlaybackGuard.Jellyfin.dll" ./playbackguard-plugins/jellyfin/PlaybackGuard/
    cp -f "$TMP_DIR/meta.json" ./playbackguard-plugins/jellyfin/PlaybackGuard/
    if [[ -f "$TMP_DIR/thumb.png" ]]; then
        cp -f "$TMP_DIR/thumb.png" ./playbackguard-plugins/jellyfin/PlaybackGuard/
    fi
else
    echo "============================================================"
    echo "  ¡Instalación completada! Entra al panel de Emby/Jellyfin"
    echo "  -> Plugins -> PlaybackGuard para configurarlo."
    echo "============================================================"
fi
