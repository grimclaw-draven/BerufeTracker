# BerufeTracker

[English](README.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português](README.pt-BR.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [한국어](README.ko.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md)

¿Cuánto Mineral de cobre, Paño de lino y Flor de paz te falta todavía para subir tus profesiones a 300? BerufeTracker lo calcula: para cada profesión, hasta los materiales básicos y entre todos tus personajes y bancos.

Para **WoW Forever**, en el idioma de tu cliente de juego: inglés, alemán, francés, español, portugués, italiano, ruso, coreano y chino (simplificado y tradicional).

## Funciones

**Materiales**
- Necesidad total de todas las profesiones, desglosada hasta los materiales básicos. Un Lingote de bronce, por ejemplo, cuenta como Lingotes de cobre y de estaño, y estos a su vez como mineral.
- Se descuenta lo que tienes en las bolsas, el banco y el buzón de todos tus personajes de tu facción actual. Si [BagBrother/Bagnon](https://www.curseforge.com/wow/addons/bagnon) está instalado, también se incluyen los personajes que BerufeTracker aún no conoce.
- Filtros: «Todas las profesiones» suma todos los personajes de tu facción con sus propias profesiones y habilidad. «Profesiones aprendidas» cuenta cada profesión aprendida una vez, «Cada profesión una vez» cada profesión una vez, incluidas las no aprendidas, o elige un solo personaje. Las profesiones de recolección se pueden excluir.
- Al pasar el ratón se muestra la necesidad por profesión, el precio y el coste de compra, cómo se reparte el stock entre tus personajes y dónde conseguir el material: nodos con zonas, enemigos con niveles y los vendedores más cercanos de tu facción.
- El escaneo de la casa de subastas muestra cuánto costaría comprarlo todo en lugar de recolectarlo tú mismo.

**Ruta**
- La ruta paso a paso de cada profesión, con cuánto queda pendiente.
- Elige tu guía: Metabot, RankedBoost, Wowhead, wowtbc.gg, GoldGoblin o wow-professions, por profesión o para todas a la vez.
- Las recetas que faltan se marcan junto con dónde encontrarlas.
- Las visitas al instructor aparecen en el punto adecuado de la ruta, con el instructor más cercano que te enseña el siguiente rango.

**Puntos de ruta**
- Ctrl+clic izquierdo en un instructor o un material coloca un punto de ruta hacia el instructor o vendedor más cercano.
- Una barra con una flecha de dirección y una descripción muestra el destino. Al hacer clic en ella se abre el mapa en el destino.
- El mapa también muestra una etiqueta. Cuando compartes el marcador del mapa en el chat, la descripción se envía con él.
- El punto de ruta desaparece en cuanto hablas con el PNJ.

**En el juego**
- Las descripciones de objetos (bolsas, banco, casa de subastas, botín) muestran cuánto te falta todavía con tu filtro actual.
- Los filones de mineral y las hierbas del mundo muestran lo que aún necesitas de ellos.

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

## Licencia

GPLv3, ver `LICENSE.md`.
