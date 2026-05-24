# RUNBOOK — Instalar Docker Engine desde el repo oficial + validación real

> **Tipo:** Provisión de runtime
> **Severidad:** Baja — instalación, no recuperación
> **Tiempo estimado:** 10-15 min
> **Origen:** Sesión 4 (P1.6) — Docker 29.5.2 en app-prod-01
> **Entorno:** Ubuntu 24.04 LTS

---

## ⚠️ Cuándo usar este runbook

Para instalar Docker Engine en un host Ubuntu **desde el repositorio oficial de Docker**, no desde el paquete `docker.io` de la distro. Aplica a hosts que vayan a correr cargas de contenedores (en Goloca AI: app01 y futuros nodos; **no** el bastión, que no corre cargas).

## Por qué el repo oficial y no `apt install docker.io`

| | `apt install docker.io` | Repo oficial (este runbook) |
|---|---|---|
| Versión | La que empaquetó Ubuntu, suele estar atrasada | Actual, parcheada por Docker |
| Compose v2 | No incluido como plugin | Incluido (`docker-compose-plugin`) |
| Ciclo de parches | Atado a Ubuntu | Directo de Docker |

En producción, la versión del runtime afecta a seguridad, compatibilidad con Kubernetes (P3) y features. El paquete viejo de la distro es el atajo que se paga después.

## Precondiciones

- Host Ubuntu 24.04 con acceso a internet (salida HTTPS).
- Permisos sudo.
- Baseline del host ya aplicado (este es el paso 6 del baseline, va después del hardening).

---

## Procedimiento

### Paso 1 — Dependencias y limpieza previa

Elimina cualquier Docker viejo de la distro que pudiera haber:

```bash
sudo apt remove -y docker.io docker-doc docker-compose podman-docker containerd runc 2>/dev/null
sudo apt update
sudo apt install -y ca-certificates curl
```

(El `remove` no falla si no había nada; el `2>/dev/null` silencia el ruido.)

### Paso 2 — Clave GPG oficial de Docker

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

La clave verifica que los paquetes vienen de verdad de Docker. Sin ella, `apt` rechaza el repo.

### Paso 3 — Añadir el repositorio

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
```

El `$(. /etc/os-release && echo "$VERSION_CODENAME")` detecta automáticamente el codename de Ubuntu (`noble` en 24.04), así el runbook no se ata a una versión concreta.

### Paso 4 — Instalar Docker Engine + Compose

```bash
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Cinco paquetes: el engine, el CLI, el runtime de contenedores, buildx y Compose v2.

### Paso 5 — Habilitar y arrancar (con enable explícito)

```bash
sudo systemctl enable --now docker
```

`--now` arranca el servicio ya; `enable` garantiza que arranca en futuros reboots. **El enable explícito evita la trampa del incidente DT-17** (servicio que corre pero no arranca tras reboot). Verifica las dos dimensiones:

```bash
systemctl is-active docker     # active
systemctl is-enabled docker    # enabled
```

### Paso 6 — Permitir uso sin sudo

```bash
sudo usermod -aG docker $USER
```

> **Implicación de seguridad:** pertenecer al grupo `docker` equivale a **root efectivo** (el daemon corre como root y se puede abusar para escalar). Aceptable en un host de acceso restringido vía bastión; en producción real se estudia rootless Docker. Esto es DT-07.

Cierra sesión y vuelve a entrar (o `newgrp docker`) para que el grupo surta efecto.

---

## Validación (más allá de hello-world)

`docker run hello-world` solo confirma que el engine arranca. No prueba red ni servicio. Validación real con un contenedor que escucha en un puerto:

### Paso 7 — Levantar NGINX efímero

```bash
docker run -d -p 8080:80 --name test-nginx nginx:alpine
```

### Paso 8 — Verificar las tres capas

```bash
docker ps                    # contenedor Up, mapeo 0.0.0.0:8080->80/tcp
curl -I localhost:8080       # HTTP/1.1 200 OK
docker logs test-nginx       # petición registrada desde 172.17.0.1
```

Lectura del paso de logs: la petición aparece originada en `172.17.0.1`, que es el **gateway del bridge `docker0`** (la red por defecto de Docker), no `127.0.0.1`. Eso confirma que el tráfico atraviesa la capa de red de Docker, no va directo. Entender ese salto es el preludio del networking de contenedores de P2.

### Paso 9 — Limpieza

```bash
docker rm -f test-nginx
```

Nada efímero se queda corriendo.

---

## Verificación final (checklist)

- [ ] `docker --version` muestra versión actual (no la vieja de la distro)
- [ ] `docker compose version` responde (Compose v2 como plugin)
- [ ] `systemctl is-active docker` → `active`
- [ ] `systemctl is-enabled docker` → `enabled`
- [ ] Contenedor de prueba responde 200 OK
- [ ] Tráfico visto desde `172.17.0.1` en logs (red bridge funcionando)
- [ ] Contenedor de prueba eliminado

## Trampas comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `apt update` falla con error de clave GPG | Clave mal descargada o permisos | Rehacer paso 2; `chmod a+r` en la clave |
| `permission denied` al usar docker sin sudo | Grupo no aplicado a la sesión | Cerrar sesión y reentrar, o `newgrp docker` |
| Codename incorrecto en el repo | `os-release` no detectado | Verificar `. /etc/os-release && echo $VERSION_CODENAME` |
| Contenedor expone puerto pese a UFW | Docker reescribe iptables, salta UFW | Conocido (DT). Se corrige en P2 con DOCKER-USER chain |
| Docker no arranca tras reboot | Faltó `enable` | `sudo systemctl enable docker` |

## Trampa de red para P2: Docker vs UFW

Docker manipula `iptables` directamente al publicar puertos (`-p`). Esto **se salta UFW**: un contenedor con `-p 8080:80` queda accesible aunque UFW no tenga regla para 8080. No es un bug, es el diseño por defecto de Docker. En P1 con un contenedor de prueba efímero no es crítico, pero **antes de exponer servicios reales en P2** hay que resolverlo (chain `DOCKER-USER` o gestión manual de iptables). Documentado para no exponer servicios sin querer cuando empiece el stack aplicativo.
