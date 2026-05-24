# P1.6 — Instalación de Docker Engine

> **Proyecto:** P1 · Infraestructura Base
> **Mini-proyecto:** 1.6 — Linux baseline + Docker
> **Host:** `app-prod-01` (120) · Ubuntu 24.04 LTS
> **Estado:** Cerrado (sesión 4)
> **Versión instalada:** Docker 29.5.2 + Compose v2
> **Documentos relacionados:** [`06-linux-baseline-spec.md`](06-linux-baseline-spec.md)

---

## 1. Propósito

Docker Engine sobre `app-prod-01`, que en P2 alojará el stack de Goloca AI (FastAPI + PostgreSQL + Redis + NGINX). Solo en app01: el bastión no corre cargas, no lleva runtime de contenedores.

## 2. Decisión: repo oficial de Docker, no `apt install docker.io`

Hay dos formas de instalar Docker en Ubuntu, y la diferencia importa.

| Método | Fuente | Problema |
|---|---|---|
| `apt install docker.io` | Repos de Ubuntu | Versión empaquetada por Ubuntu, casi siempre desactualizada. Sin Compose v2 integrado. Ciclo de parches atado a Ubuntu, no a Docker |
| Repo oficial `download.docker.com` (**elegido**) | Docker Inc. | Versión actual, Compose v2 como plugin, parches directos del fabricante |

En producción, la versión del runtime de contenedores no es un detalle: afecta a features de seguridad, compatibilidad con Kubernetes (P3) y disponibilidad de parches. Instalar la versión vieja de los repos de la distro es el atajo que se paga después. Se usa el repo oficial.

## 3. Procedimiento

Resumen (el script reproducible vive en `infrastructure/docker/install-docker-ubuntu.sh`):

1. Dependencias: `ca-certificates`, `curl`.
2. Clave GPG oficial de Docker en `/etc/apt/keyrings/`.
3. Repo de Docker añadido a `apt sources`, fijado a la arquitectura y release correctos.
4. `apt update` + instalación de 5 paquetes: `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`.
5. `systemctl enable --now docker` — habilitado **y** arrancado. El `enable` explícito evita la trampa del incidente SSH (servicio que corre pero no arranca tras reboot).
6. `usermod -aG docker ubuntu` — permite usar Docker sin `sudo` (implicación de seguridad en sección 5).

## 4. Validación (más allá de `hello-world`)

`docker run hello-world` confirma que el runtime arranca, pero no prueba nada de red ni de servicio real. Validación efectiva ejecutada:

```
docker run -d -p 8080:80 --name test-nginx nginx:alpine
```

Comprobaciones:
- `docker ps` → contenedor `Up`, mapeo `0.0.0.0:8080->80/tcp`.
- `curl -I localhost:8080` → `HTTP/1.1 200 OK`.
- `docker logs test-nginx` → petición registrada desde `172.17.0.1` (gateway del bridge `docker0`).

El último punto es el que enseña algo: la petición no llega desde `127.0.0.1` sino desde `172.17.0.1`, la IP del gateway de la red bridge por defecto de Docker (`docker0`). Eso confirma que el tráfico pasa por la capa de red de Docker, no directo. Entender ese salto de red es el preludio del networking de contenedores de P2.

Limpieza: `docker rm -f test-nginx`. Nada efímero se queda corriendo.

## 5. Implicación de seguridad: grupo docker = root

`usermod -aG docker ubuntu` permite ejecutar Docker sin `sudo`. Comodidad real, pero con coste: **pertenecer al grupo `docker` equivale a root efectivo**. El daemon de Docker corre como root, y cualquiera que pueda hablar con su socket puede montar el sistema de archivos del host dentro de un contenedor y escalar a root trivialmente.

Esto es DT-07, reafirmada. Mitigación actual: el patrón bastión limita quién llega a app01 (solo vía bastión). Resolución prevista:
- **P3:** migración a Kubernetes con RBAC, que cambia el modelo de acceso al runtime.
- **P6:** estudio de Docker rootless, que ejecuta el daemon sin privilegios de root.

Se acepta el trade-off en P1-P2 (comodidad operativa en un host de acceso restringido), con resolución planificada. No es un descuido: es una deuda con fecha.

## 6. Trampa de red conocida (a resolver en P2)

Docker reescribe las reglas de `iptables` al arrancar contenedores con puertos publicados. Esto puede **saltarse UFW**: un contenedor con `-p 8080:80` queda expuesto aunque UFW no tenga regla para 8080. UFW y Docker operan sobre `iptables` en capas distintas y Docker gana.

No es un fallo de configuración, es cómo funciona Docker por defecto. Se documenta aquí y se corrige en P2 (cuando haya servicios reales expuestos), con las técnicas estándar: `DOCKER-USER` chain o `iptables=false` + gestión manual. En P1, con un solo contenedor de prueba efímero, no es crítico — pero hay que saberlo antes de exponer servicios reales.

## 7. Deuda técnica derivada

| ID | Deuda | Resolución |
|---|---|---|
| DT-07 | Grupo docker = root | P3 RBAC, P6 rootless |
| — | Docker reescribe iptables, salta UFW | P2: DOCKER-USER chain |
