# P1.1 — Por qué un troncal VLAN hacia el hipervisor

> **Proyecto:** P1 · Infraestructura Base
> **Mini-proyecto:** 1.1 — Segmentación de red
> **Estado:** Decisión cerrada (sesión 7) · implementación pendiente (fase C)
> **Revisa:** decisión 4.1 del roadmap, que originalmente descartaba VLANs por completo
> **Documentos relacionados:** [`01-network-architecture.md`](01-network-architecture.md)

---

## 1. La decisión original y por qué se revisó

El roadmap cerró en su día esta decisión:

> *Segmentación por puertos físicos del FortiGate, no VLAN tagging. Razón: el switch DGS-1005P es no gestionable.*

El razonamiento era correcto para el problema que tenía delante: un switch sin soporte 802.1Q no transporta tramas etiquetadas, así que las VLANs no son una opción en el cableado físico del laboratorio.

Lo que la decisión no previó es que **el hipervisor tiene una sola tarjeta de red**.

El problema apareció al planificar la zona DMZ:

> *"cuando hablas del nginx en P2 conectarlo a internal4, ¿a qué tarjeta? el proxmox solo tiene un ethernet"*

Es una objeción demoledora. El reverse proxy de P2 va a ser una máquina virtual sobre Proxmox. Una VM solo alcanza la red a la que esté puenteado su bridge, y el bridge cuelga de la única NIC física, que está enchufada a un único puerto del cortafuegos. Con segmentación puramente física:

- Si esa NIC está en SERVERS, **toda** VM está en SERVERS.
- La zona DMZ existiría como interfaz del FortiGate, con su subred y sus políticas, y **ningún servidor podría alcanzarla**.

La arquitectura era irrealizable, y no se habría descubierto hasta empezar P2.

---

## 2. Alternativas evaluadas

### Opción A — Una NIC física por zona (adaptadores USB)

Un adaptador USB 3.0-Gigabit por cada zona que deba alojar VMs, cada uno a su puerto del cortafuegos, cada uno con su bridge en Proxmox.

| A favor | En contra |
|---|---|
| Conceptualmente simple: un cable, una zona | No escala: cada zona nueva es otro adaptador y otro puerto |
| Mantiene la coherencia con la decisión 4.1 | Un USB-Ethernet es frágil como infraestructura permanente: se desconecta, se recalienta, el driver falla |
| Aislamiento físico real | Consume los puertos del cortafuegos, que son cuatro en total |
| | Coste recurrente |

### Opción B — Troncal 802.1Q hacia el hipervisor

Un único enlace entre la NIC del hipervisor y un puerto del cortafuegos, transportando todas las zonas etiquetadas. Proxmox etiqueta por VM; el FortiGate termina una subinterfaz VLAN por zona.

| A favor | En contra |
|---|---|
| Escala sin hardware: una zona nueva es una VLAN nueva | Introduce una capa conceptual más que depurar |
| Libera puertos del cortafuegos | Un fallo del enlace afecta a todas las zonas a la vez |
| Es el patrón estándar en virtualización de producción | Requiere entender el etiquetado para diagnosticar |
| Añade 802.1Q al portfolio, que no lo cubría | |

---

## 3. Decisión: troncal, con un matiz importante

**Se adopta la opción B para el plano de datos, manteniendo la opción física para el plano de gestión.**

La clave para no contradecir la decisión original está en delimitar su alcance. El veto a las VLANs se justificaba por un switch que no las soporta — pero **en el enlace entre Proxmox y el FortiGate no hay ningún switch**. Es punto a punto, cable directo entre dos dispositivos que sí hablan 802.1Q perfectamente.

La restricción que motivaba la decisión simplemente **no aplica a ese tramo**. Sigue aplicando al cableado físico, donde el switch no gestionable continúa obligando a segmentar por puertos.

De ahí el modelo híbrido:

| Tramo | Segmentación | Motivo |
|---|---|---|
| Equipos físicos ↔ FortiGate | Puertos físicos | El switch intermedio no transporta etiquetas |
| Proxmox ↔ FortiGate | Troncal 802.1Q | Enlace directo, sin switch de por medio |

### Precedente en producción

Llevar un troncal al hipervisor y repartir las VLANs dentro es cómo funciona la virtualización en cualquier entorno serio: un ESXi con un port group por VLAN, un Proxmox con bridge VLAN-aware, un Hyper-V con un switch virtual en modo trunk. La alternativa de una tarjeta por red solo se ve en instalaciones muy pequeñas o donde hay un requisito explícito de separación física.

Que un candidato entienda y sepa depurar un troncal es una expectativa razonable en un puesto de infraestructura. Que monte cuatro adaptadores USB, no.

---

## 4. Uso de la NIC USB: separar gestión de datos

El adaptador USB estaba previsto en el roadmap para dar al bastión una pata en la zona de gestión (decisión 4.5, deuda DT-01). Con el troncal eso ya no hace falta: el bastión llega a MGMT etiquetando en VLAN 10, sin hardware adicional.

El adaptador se reasigna a algo de más valor: **la interfaz de gestión del propio hipervisor**.

```
   nic0 (integrada) ──► internal3 ──► TRONCAL, sin IP
        └── vmbr0 VLAN-aware ── plano de datos de las VMs

   NIC USB ─────────► grupo MGMT ──► 10.10.0.10
        └── vmbr1 ── gestión del host
```

**Por qué:** si el plano de gestión y el de datos comparten interfaz, un error en la configuración de VLANs, bridges o cortafuegos deja al hipervisor incomunicado. Separándolos, la gestión sobrevive a los errores del plano de datos.

Esto no es una preocupación abstracta en esta instalación concreta: **el servidor no tiene monitor ni teclado conectados**, y recuperarlo físicamente es costoso. La sesión 7 dedicó un procedimiento entero a migrar su dirección sin perder acceso precisamente por eso. Una vía de gestión que no depende de la configuración que estás tocando vale mucho.

Es el equivalente a la interfaz de gestión dedicada de un ESXi, o a una red de gestión fuera de banda.

---

## 5. Consecuencias

**Se gana:**

- La DMZ de P2 es realizable.
- Zonas nuevas sin hardware: K3s, observabilidad, lo que traiga P3 y P4.
- Un plano de gestión que sobrevive a los errores del plano de datos.
- 802.1Q, bridges VLAN-aware y depuración de etiquetado incorporados al recorrido formativo.
- Se cierra DT-01 sin comprar nada.

**Se paga:**

- Una capa más donde las cosas fallan en silencio. Una VM con la etiqueta equivocada arranca, tiene enlace, y no habla con nadie — sin ningún error visible.
- El troncal es un punto único de fallo para todas las zonas virtuales.
- Hay que verificar el etiquetado en dos sitios (Proxmox y FortiGate) y que coincidan.

**Modos de fallo a anticipar:**

| Fallo | Síntoma | Dónde mirar |
|---|---|---|
| VM sin VLAN asignada | Enlace sí, tráfico no | `qm config <id>`, campo `tag` |
| VLAN correcta, subinterfaz ausente en el cortafuegos | Tramas descartadas en silencio | Interfaces del FortiGate |
| Bridge no VLAN-aware | Todas las VMs en la misma red pese a las etiquetas | `bridge vlan show` en Proxmox |
| VLAN nativa mal entendida | Tráfico sin etiquetar cayendo en la zona equivocada | Configuración del puerto troncal |

---

## 6. Qué se descartó y por qué conviene recordarlo

No se eligió el troncal porque las VLANs sean intrínsecamente mejores. Se eligió porque **la restricción que justificaba descartarlas no aplicaba al tramo donde hacían falta**.

La lección operativa no es sobre VLANs: es sobre revisar el alcance de una decisión cerrada cuando aparece un dato que no se tenía. La decisión 4.1 no era incorrecta — era incompleta, y se tomó sin conocer un detalle del inventario. Acotarla es preferible a arrastrarla hasta que bloquee un proyecto entero.
