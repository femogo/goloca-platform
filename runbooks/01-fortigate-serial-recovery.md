# RUNBOOK — Recuperar un FortiGate sin credenciales (consola serie + `maintainer`)

> **Tipo:** Recuperación de acceso a equipo de red
> **Severidad:** Alta — el equipo es inalcanzable por red y no se conoce la contraseña
> **Tiempo estimado:** 15-30 min (más el tiempo de conseguir el cable adecuado)
> **Origen:** Sesión 7 · desviación D-06 (FortiGate de segunda mano con configuración previa)
> **Entorno:** FortiGate 30E · FortiOS 6.2.5 · Windows como terminal

---

## ⚠️ Cuándo usar este runbook

- Equipo de segunda mano con una configuración desconocida y contraseña de `admin` no documentada.
- El botón de reset físico no responde al procedimiento estándar.
- No hay acceso por red porque no se conoce el direccionamiento configurado.

## Cuándo NO usarlo

- Si conoces la contraseña de `admin`: entra por la interfaz web y usa `execute factoryreset`.
- Si el botón de reset funciona: es más rápido.
- **Si el equipo está en producción con configuración que quieres conservar.** Este procedimiento termina borrándola.

---

## Lo que hay que entender antes de empezar

`maintainer` es una cuenta de emergencia de FortiOS con dos propiedades que determinan todo el procedimiento:

1. **Solo funciona por consola serie.** Nunca por red, ni por SSH, ni por la interfaz web. Por eso el cable no es opcional.
2. **Solo es válida durante una ventana corta tras el arranque.** No es una cuenta permanente que puedas usar cuando quieras. Si tardas en teclearla, falla — y el fallo es indistinguible de una contraseña incorrecta.

Su contraseña es `bcpb` seguido del **número de serie** del equipo, en mayúsculas y sin espacios:

```
bcpbFGT30E<SERIAL>
```

El serial aparece en el propio banner de arranque, en la pegatina del chasis, y en `get system status`.

> **Implicación de seguridad:** cualquiera con acceso físico al puerto de consola y conocimiento del serial entra en el equipo. Por eso el serial se trata como credencial y se redacta en la documentación pública. La cuenta puede desactivarse con `set admin-maintainer disable` — si el dueño anterior lo hizo, este procedimiento no funciona y hay que ir al menú de arranque.

---

## Precondiciones

- **Cable USB-RJ45 con chip FTDI.** Un cable DB9-RJ45 no sirve en un portátil moderno sin adaptador serie.
- Cliente de terminal serie (PuTTY, `screen`, `minicom`).
- Acceso físico al equipo, para poder cortarle la alimentación.

---

## Procedimiento

### Paso 1 — Conectar y localizar el puerto COM

Extremo USB al ordenador, extremo RJ45 al puerto rotulado **Console** (no a un puerto LAN ni al WAN).

En Windows, `Administrador de dispositivos → Puertos (COM y LPT)` debe mostrar una entrada nueva tipo `USB Serial Port (COMx)`. Anota `x`.

**Si no aparece:** prueba otro puerto USB (preferiblemente trasero). Si sigue sin aparecer, el cable puede llevar un chip Prolific o CH340 que necesita driver aparte.

### Paso 2 — Abrir la sesión serie

Parámetros de FortiGate: **9600 baudios, 8 bits de datos, sin paridad, 1 bit de parada, sin control de flujo** (9600 8N1).

En PuTTY: `Connection type: Serial`, `Serial line: COMx`, `Speed: 9600`. Verifica en `Connection → Serial` que el control de flujo está en `None`.

La ventana se abre en negro. Es normal: hasta que el equipo transmita algo no hay nada que mostrar.

### Paso 3 — Arrancar el equipo y capturar el banner

Corta la alimentación, espera 5 segundos y vuelve a enchufar. Deben aparecer las líneas de arranque.

Anota el **número de serie**, que sale en las primeras líneas:

```
FortiGate-30E (15:27-01.31.2017)
Ver:05000016
Serial number: FGT30E<SERIAL>
```

> **Trampa:** `Ver:05000016` es la versión de **BIOS/bootloader**, no de FortiOS. No la confundas al buscar documentación. La versión real del sistema operativo se obtiene después con `get system status`.

### Paso 4 — Estabilizar la consola antes de intentar el login

Si aparecen intentos de login que tú no has escrito, **para y resuelve eso primero**: ver [`01-serial-console-crosstalk.md`](01-serial-console-crosstalk.md). Intentar teclear la contraseña de `maintainer` sobre una línea con ruido la corrompe a mitad y consume la ventana de validez.

### Paso 5 — Entrar como `maintainer`, inmediatamente tras un arranque

Prepara la contraseña en el portapapeles **antes** de reiniciar. Luego:

1. Corta y restablece la alimentación.
2. En cuanto aparezca **por primera vez** el prompt `login:`, escribe `maintainer` y Enter. No esperes.
3. En `Password:`, pega con **clic derecho** (en PuTTY el clic derecho pega; `Ctrl+V` no funciona en sesión serie) y Enter.

Resultado esperado:

```
Welcome!
fgt-prod-01 #
```

**Si falla:** no lo reintentes sin reiniciar. La ventana ya ha pasado. Repite el ciclo de alimentación y sé más rápido. Si falla siendo rápido dos veces seguidas, asume que la cuenta está desactivada y pasa al menú de arranque (`press any key to display configuration menu` durante el boot).

### Paso 6 — Restablecer a fábrica

Con acceso ya conseguido:

```
execute factoryreset
```

Confirma con `y`. El equipo reinicia y queda con `admin` sin contraseña y la interfaz interna en `192.168.1.99/24`.

En el primer login, FortiOS obliga a establecer una contraseña nueva.

---

## Checklist de verificación

- [ ] La consola muestra el arranque sin caracteres espurios.
- [ ] `maintainer` da acceso a un prompt `#`.
- [ ] Tras `factoryreset`, `admin` entra y fuerza cambio de contraseña.
- [ ] `get system status` reporta la versión real de FortiOS y el serial.
- [ ] `get system interface` muestra la interfaz interna en `192.168.1.99/24`.

---

## Trampas comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `Login incorrect` con la contraseña correcta | Ventana de `maintainer` agotada | Ciclo de alimentación y teclear en el primer prompt |
| Caracteres ilegibles en pantalla | Velocidad distinta de 9600 | Ajustar baudios |
| Logins espurios que no has escrito | Diafonía TX/RX del cable | Ver runbook de diafonía |
| No aparece puerto COM | Cable sin chip FTDI, o puerto USB problemático | Cambiar de puerto; verificar el chip |
| Se confunde la versión de BIOS con la de FortiOS | El banner muestra `Ver:` del bootloader | Usar `get system status` |
| Bloques `config ... end` pegados se corrompen | A 9600 baudios el pegado multilínea se solapa | Introducir los comandos de uno en uno |

---

## Después de recuperar el acceso

El equipo queda en fábrica, sin contraseña conocida por nadie más, pero también **sin ninguna configuración**. Antes de conectarlo a nada:

1. Cambia la contraseña de `admin` (FortiOS lo fuerza).
2. Establece hostname, NTP y zona horaria — sin hora correcta los logs no sirven para correlacionar nada.
3. **Verifica cada cambio contra la configuración guardada** (`get system global`), no contra el eco de la consola. En esta plataforma se comprobó que el equipo acepta visualmente comandos que no llegan a aplicarse.
4. Haz un backup de configuración en cuanto haya algo que perder.
