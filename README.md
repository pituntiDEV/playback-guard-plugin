# PlaybackGuard — Plugin Premium para Emby y Jellyfin

Plugin de control de reproducciones en tiempo real, validación de suscripción (`expirationDate`), límite de pantallas simultáneas (`maxConnections`) mediante API externa, límite global del servidor, protección anti-abuso y notificaciones automáticas de estrenos con póster para Telegram, Discord y Webhook.

> 🔐 **Requiere Llave de Licencia (License Key):** Una vez instalado el plugin, entra a **Plugins → PlaybackGuard** en tu panel de Emby o Jellyfin e ingresa tu llave `PG-XXXX-XXXX-XXXX` para desbloquear todas las funciones.

---

## Instalación Súper Fácil

### Opción A: Instalación Automática en 1 Comando (Linux Docker y Nativo)
Si tu servidor Emby o Jellyfin corre en Linux (con **Docker** o **instalación nativa**), ejecuta este único comando. Detectará automáticamente tus servidores Emby y/o Jellyfin, instalará el plugin y reiniciará el servicio:

```bash
curl -fsSL https://raw.githubusercontent.com/pituntiDEV/playback-guard-plugin/main/quick-install.sh | sudo bash
```

---

### Opción B: Instalar desde el Catálogo de Repositorios de Jellyfin
1. Entra a tu panel de **Jellyfin → Panel de Control → Plugins → Repositorios**.
2. Haz clic en el botón **`+`** para añadir un nuevo repositorio:
   - **Nombre del Repositorio:** `PlaybackGuard`
   - **URL del Repositorio:**
     ```text
     https://raw.githubusercontent.com/pituntiDEV/playback-guard-plugin/main/manifest.json
     ```
3. Ve a la pestaña **Catálogo**, busca **PlaybackGuard**, haz clic en **Instalar** y reinicia Jellyfin.

---

### Opción C: Instalación Manual Copiando el Archivo `.dll` (Windows / NAS / Docker)
Descarga los archivos compilados de la carpeta [`dist/`](./dist) de este repositorio:

- **Para Emby:**
  1. Descarga [`dist/emby/PlaybackGuard.Emby.dll`](./dist/emby/PlaybackGuard.Emby.dll).
  2. Pega el archivo dentro de la carpeta `plugins` de tu servidor Emby (en Docker: `/config/plugins/`, en Linux nativo: `/var/lib/emby/plugins/`).
  3. Reinicia Emby Server.

- **Para Jellyfin:**
  1. Crea una carpeta llamada `PlaybackGuard` dentro de la carpeta `plugins` de Jellyfin (en Docker: `/config/plugins/PlaybackGuard/`, en Linux nativo: `/var/lib/jellyfin/plugins/PlaybackGuard/`).
  2. Descarga y pega ahí [`dist/jellyfin/PlaybackGuard.Jellyfin.dll`](./dist/jellyfin/PlaybackGuard.Jellyfin.dll), [`dist/jellyfin/meta.json`](./dist/jellyfin/meta.json) y [`dist/jellyfin/thumb.png`](./dist/jellyfin/thumb.png).
  3. Reinicia Jellyfin Server.
