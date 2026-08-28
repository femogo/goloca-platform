# RUNBOOK — Diafonía TX/RX en un cable de consola serie

> **Tipo:** Diagnóstico de capa física
> **Severidad:** Media — impide operar por consola, y confunde el diagnóstico de otros problemas
> **Tiempo estimado:** 5 min
> **Origen:** Sesión 7, durante la recuperación del FortiGate
> **Entorno:** Cable USB-RJ45 FTDI · 9600 8N1 · Windows/PuTTY

---

## Síntoma

La consola serie muestra **entrada que nadie ha tecleado**. El caso característico: en un prompt de login aparecen intentos de autenticación en bucle cuyos "usuarios" son fragmentos del propio texto que el equipo acaba de imprimir.

```
fgt-prod-01 login: FortiGate-30E (15:27-01.31.2017)
Password: ************
Login incorrect
fgt-prod-01 login: Serial number: FGT30E<SERIAL>
Password: ****************
Login incorrect
fgt-prod-01 login: Total RAM: 1GB
Password: ***************************
Login incorrect
```

La pista que lo identifica: **el texto "tecleado" es literalmente el banner de arranque del equipo**. No es basura aleatoria ni caracteres mal decodificados — es contenido que el propio dispositivo transmitió hace un instante.

---

## Causa

Acoplamiento capacitivo entre las líneas de transmisión y recepción dentro del cable. El equipo transmite (TX), esa señal induce una copia débil en el par de recepción (RX), y el adaptador la interpreta como si el operador estuviera escribiendo. El bucle se realimenta: cada línea que el equipo imprime vuelve a entrar como pulsaciones.

Es un problema **de capa física**, no de configuración. Ni la velocidad, ni la paridad, ni el software tienen nada que ver.

Factores que lo favorecen:

- Cables de consola baratos, sin blindaje o con blindaje sin conectar a masa.
- Puertos USB frontales de torre o hubs sin alimentación, con referencia de masa peor que los traseros.
- El cable discurriendo paralelo y pegado a cables de alimentación.

---

## Por qué importa resolverlo antes de seguir

Dos razones prácticas, ambas comprobadas:

1. **Corrompe lo que escribes.** Una contraseña tecleada sobre una línea con ruido llega alterada. Si estás usando la cuenta `maintainer`, que solo es válida durante una ventana corta tras el arranque, el ruido te consume esa ventana sin que sepas si falló por el ruido o por la contraseña.
2. **Envenena el diagnóstico.** Los intentos fallidos que ves no son un ataque ni una configuración rara del equipo. Si no identificas la diafonía, pierdes tiempo investigando un problema que no existe.

---

## Cómo distinguirlo de otras cosas

| Observación | Diafonía | Otra causa |
|---|---|---|
| El texto espurio reproduce la salida del equipo | ✅ | — |
| Caracteres ilegibles o símbolos aleatorios | ❌ | Velocidad de baudios incorrecta |
| Nada en pantalla | ❌ | Cable mal conectado, equipo apagado, puerto equivocado |
| Solo ocurre durante el arranque y luego cesa | Posible, benigno | Ráfaga de datos del boot |
| Continúa con el equipo en reposo | ✅ Persistente | — |

**Prueba discriminante:** con el equipo ya arrancado y en reposo, pulsa Enter una vez y espera 10 segundos sin tocar nada. Si siguen apareciendo prompts o líneas por su cuenta, la diafonía es persistente y hay que corregirla.

---

## Procedimiento

### Paso 1 — Reasentar el conector RJ45

Desconéctalo del puerto Console y vuelve a insertarlo con firmeza hasta oír el clic. Un conector a medio encajar deja contactos con mala continuidad, que es una de las formas de generar el acoplamiento.

### Paso 2 — Cambiar el extremo USB a un puerto trasero

Si está en un hub, un alargador o un puerto frontal de torre, pásalo a un **puerto USB trasero de la placa base**. Suelen tener mejor blindaje y una referencia de masa más sólida.

### Paso 3 — Separar el cable de fuentes de interferencia

Aléjalo de cables de alimentación, regletas y transformadores. El acoplamiento crece cuanto más largo sea el tramo en que el cable de datos corre paralelo y pegado a uno de corriente.

### Paso 4 — Verificar

Espera 10 segundos sin tocar nada. Pulsa Enter una vez.

**Resultado esperado:** aparece un único prompt y la pantalla queda quieta.

---

## Checklist de verificación

- [ ] Con el equipo en reposo, no aparece ninguna línea que no hayas escrito.
- [ ] Un Enter produce exactamente un prompt nuevo.
- [ ] El texto que escribes aparece íntegro, sin caracteres insertados.

---

## Si persiste

Descartada la instalación física, el cable es sospechoso. Opciones, por orden de coste:

1. Probar otro puerto USB y, si es posible, otro ordenador — descarta que el problema esté en la referencia de masa del equipo.
2. Probar un cable de consola distinto.
3. Un adaptador USB-serie de calidad más un cable rollover convencional suele comportarse mejor que un cable de consola integrado barato.

Mientras no se resuelva, **no intentes procedimientos sensibles al tiempo** como la cuenta `maintainer`: acabarás sin saber si el fallo es tuyo o del cable.
