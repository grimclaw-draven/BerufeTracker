# BerufeTracker

[English](../README.md) · [Deutsch](de.md) · [Français](fr.md) · [Español](es.md) · [Português](pt-BR.md) · [Italiano](it.md) · [Русский](ru.md) · [한국어](ko.md) · [简体中文](zh-CN.md) · [繁體中文](zh-TW.md)

¿Cuánto Mineral de cobre, Paño de lino y Flor de paz te falta todavía para subir tus profesiones a 300? BerufeTracker lo calcula: para cada profesión, hasta los materiales básicos y entre todos tus personajes y bancos.

Para **WoW Forever**, en el idioma de tu cliente de juego: inglés, alemán, francés, español, portugués, italiano, ruso, coreano y chino (simplificado y tradicional).

## Funciones

**Materiales**
- Necesidad total de todas las profesiones, desglosada hasta los materiales básicos. Un Lingote de bronce, por ejemplo, cuenta como Lingotes de cobre y de estaño, y estos a su vez como mineral.
- Se descuenta lo que tienes en las bolsas, el banco y el buzón de todos tus personajes de tu facción actual. Si [BagBrother/Bagnon](https://www.curseforge.com/wow/addons/bagnon) está instalado, también se incluyen los personajes que BerufeTracker aún no conoce.
- Filtros: «Personaje actual» (predeterminado) muestra solo las profesiones del personaje conectado. «Todos los personajes (profesiones aprendidas)» suma todos los personajes de tu facción con sus propias profesiones y habilidad. «Profesiones aprendidas (mejor personaje)» cuenta cada profesión aprendida una vez, «Todas las profesiones (también sin aprender)» cada profesión una vez, las no aprendidas desde 1, o elige un solo personaje. La ruta muestra solo las profesiones de la selección; para un personaje, las profesiones aún no aprendidas solo muestran su primer instructor. Las profesiones de recolección se pueden excluir.
- Al pasar el ratón se muestra la necesidad por profesión, el precio y el coste de compra, cómo se reparte el stock entre tus personajes y dónde conseguir el material: nodos con zonas, enemigos con niveles y los vendedores más cercanos de tu facción.
- El escaneo de la casa de subastas muestra cuánto costaría comprarlo todo en lugar de recolectarlo tú mismo. Materiales y Ruta muestran el mismo coste de compra, con instructores y recetas incluidos.

**Ruta**
- La ruta paso a paso de cada profesión, con cuánto queda pendiente.
- Elige tu guía: Metabot, RankedBoost, Wowhead, wowtbc.gg, GoldGoblin o wow-professions, por profesión o para todas a la vez.
- **Ruta calculada más barata:** una guía propia, independiente de las demás guías. Para cada punto de habilidad elige la más barata de todas las recetas de la profesión (datos de juego de Forever), según el color de la receta y la probabilidad de subir, con precios de la casa de subastas, vendedores, instructores y recetas. Las recetas conocidas y los materiales que ya tienes cuentan como gratis; los artículos de vendedor con existencias limitadas solo cuentan si están en la casa de subastas; las recetas con tiempo de reutilización se excluyen. **Ruta más barata de las guías** hace lo mismo con los pasos de las demás guías. **Ruta calculada más rápida** elige las recetas con el menor tiempo de fabricación y tiene en cuenta también los tiempos de reutilización de materiales como el paño lunar. Tus rutas propias nunca son más caras que ninguna de las otras guías y se recalculan al abrir la ventana.
- Cada guía muestra el tiempo de fabricación y el coste desde tu habilidad actual; los menús de guías comparan el coste de todas las guías.
- Las recetas que faltan se marcan junto con dónde encontrarlas.
- Las visitas al instructor aparecen en el punto adecuado de la ruta, con el instructor más cercano que te enseña el siguiente rango.

**Puntos de ruta**
- Ctrl+clic izquierdo en un instructor o un material coloca un punto de ruta hacia el instructor o vendedor más cercano.
- Una barra con una flecha de dirección y una descripción muestra el destino. Al hacer clic en ella se abre el mapa en el destino.
- El mapa también muestra una etiqueta. Cuando compartes el marcador del mapa en el chat, la descripción se envía con él.
- El punto de ruta desaparece en cuanto hablas con el PNJ.

**En el juego**
- Las descripciones de objetos (bolsas, banco, casa de subastas, botín) muestran cuánto te falta todavía con tu filtro actual.
- Los filones de mineral y las hierbas del mundo muestran lo que aún necesitas de ellos y si recolectarlos todavía te da puntos de habilidad.
- Los enemigos muestran qué materiales que necesitas sueltan, además del paño de los humanoides y el cuero de las bestias (desuello) de su nivel.
- Las armas y armaduras muestran qué materiales de encantamiento da aproximadamente desencantarlas, si los necesitas.
- La ventana de profesión del juego enmarca la receta que tu ruta recomienda a continuación; al pasar el ratón ves qué guía la recomienda, los materiales necesarios y qué personajes los tienen.

**Ventana**
- Pestaña Personajes: nivel, hermandad, oro, profesiones y materiales de cada personaje; los bancos de hermandad siguen a los personajes de su hermandad. Tú eliges qué inventario cuenta.
- La ventana se puede redimensionar; las profesiones desplegadas se recuerdan por personaje.

## Uso

- `/berufe` o el botón del minimapa abre la ventana.
- Para los precios, abre la casa de subastas y haz clic en «Escanear precios» (o `/berufe scan`).
- `/berufe skill <profesión> <valor>` fija una habilidad a mano si no se detecta. Sin valor, vuelve a aplicarse la detección automática.
- Cada personaje tiene que conectarse una vez con el addon para que se conozcan sus profesiones. Su banco se registra en cuanto lo abres una vez.

## Limitaciones

- Los nombres de objetos, instructores, vendedores y nodos proceden del juego y de QuestieDB. En italiano, y para las pocas recetas sin objeto fabricado (como los encantamientos), los nombres aparecen en inglés. Las ubicaciones de las recetas solo están disponibles en alemán e inglés.
- Las distancias son en línea recta y solo valen en el mismo continente.
- No todas las recetas tienen una ubicación conocida.
- Los datos de vendedores y ubicaciones proceden de QuestieDB y pueden contener algún error.

## Fuentes y agradecimientos

- **Rutas:** [Metabot](https://metabot.gg/en/wow-forever/professions), [RankedBoost](https://rankedboost.com/world-of-warcraft/forever/), [Wowhead](https://www.wowhead.com/forever/profession-leveling-guides), [wowtbc.gg](https://wowtbc.gg/warcraftforever/), [GoldGoblin](https://classic.goldgoblin.net/berufe/) y [wow-professions](https://www.wow-professions.com/forever/). Las rutas se han resumido para el addon. Encontrarás las guías completas con todas las explicaciones en los sitios respectivos; el enlace se muestra en la selección de guía del addon.
- **Instructores, vendedores y ubicaciones** se generaron a partir de QuestieDB (GPLv3). Gracias al equipo de Questie y a todos los colaboradores. BerufeTracker no es un proyecto del equipo de Questie.
- Las **probabilidades y cantidades de botín** de los enemigos proceden de la [base de datos cMaNGOS Classic](https://github.com/cmangos/classic-db) (GPLv3). Son valores de Classic 1.12 y pueden variar en WoW Forever.
- **Recetas, colores de habilidad y componentes** de la «Ruta calculada más barata» proceden de los datos de juego de WoW Forever a través de [wago.tools](https://wago.tools); costes de instructores y existencias de vendedores de la base de datos cMaNGOS Classic.

## Licencia

GPLv3, ver `LICENSE.md`.
