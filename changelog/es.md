# Changelog

## 1.3.0

- Nueva guía propia «Ruta calculada más rápida»: las recetas con el menor tiempo de fabricación, incluidos los tiempos de reutilización de materiales como el paño lunar
- Tiempo de fabricación y coste desde ahora bajo cada profesión, para cada guía
- «Ruta más barata de las guías» se calcula ahora punto a punto como «Ruta calculada más barata»; ninguna de las dos es nunca más cara que una de las otras guías
- Las rutas propias tienen en cuenta la probabilidad de subir en cada punto y usan tus materiales solo mientras alcanzan
- Sin tirones tras fabricar: las rutas propias se calculan en segundo plano al abrir la ventana
- Nuevo filtro predeterminado «Personaje actual»; filtros renombrados a «Todos los personajes (profesiones aprendidas)», «Profesiones aprendidas (mejor personaje)» y «Todas las profesiones (también sin aprender)». La ruta muestra solo las profesiones de la selección, las no aprendidas solo con su primer instructor
- Materiales y Ruta muestran el mismo coste de compra, con instructores, recetas y una estimación para materiales sin precio
- Ventana de profesión del juego: la receta que tu ruta recomienda a continuación aparece resaltada; su descripción muestra los materiales y qué personajes los tienen
- Hierbas y mineral: la descripción indica si recolectar todavía da puntos de habilidad
- Pestaña Personajes: nivel, hermandad, oro, profesiones y materiales de cada personaje; los bancos de hermandad siguen a los personajes de su hermandad
- Cantidades de oro con iconos de monedas
- Ventana: tamaño mínimo, sangría más clara; las profesiones desplegadas se recuerdan por personaje
- Corregido: las bolsas, habilidades y recetas de un personaje podían perderse al desconectarse

## 1.2.0

- Dos guías propias: «Ruta calculada más barata» (a partir de todas las recetas de la profesión en los datos de juego de Forever: para cada punto de habilidad la receta más barata según color y probabilidad) y «Ruta más barata de las guías» (a partir de los pasos de las demás guías)
- Coste desde ahora para cada guía en los menús de guía y junto a «Guía para todas:», con costes de instructores y recetas; los materiales que ya tienes cuentan como gratis
- Los artículos de vendedor con existencias limitadas solo cuentan si están en la casa de subastas; el escaneo de precios también incluye las recetas
- Los productos intermedios (rollos, lingotes …) se compran en la casa de subastas cuando es más barato que fabricarlos
- La ruta sigue al personaje elegido en el filtro; primero las profesiones principales, luego Primeros auxilios y Cocina, Pesca al final
- Se marcan los pasos con un tiempo de reutilización largo o que solo se consiguen con una misión
- La ventana se puede redimensionar
- Las descripciones de los enemigos muestran qué materiales necesarios sueltan, con probabilidad y cantidad (datos: cMaNGOS)
- Desencantar: la descripción del objeto muestra los resultados posibles con probabilidad y cantidad
- Los materiales de artesanía que ninguna ruta necesita muestran «No lo necesita ninguna ruta»

## 1.1.1

- La necesidad en las vetas de mineral y las hierbas ahora se muestra de forma fiable, también al pasar directamente de un nodo al siguiente
- Portugués: botón «Escanear preços» en lugar de «Varrer preços»
- README en todos los idiomas del juego

## 1.1.0

- Todos los idiomas del juego: inglés, alemán, francés, español, portugués, italiano, ruso, coreano y chino (simplificado y tradicional)
- Nombres de objetos, recetas, instructores, vendedores y nodos en el idioma del juego
- Las profesiones, objetos y recetas se reconocen independientemente del idioma del juego

## 1.0.1

- Rango de instructor Aprendiz (1-75) añadido a la ruta
- Todos los rangos muestran su intervalo, p. ej. «Oficial (75-150)»
- Los rangos completados siguen indicando su instructor
- El rango actual sigue coloreado y visible con «Solo pendientes»

## 1.0.0 – primera versión

- Necesidad de materiales de todas las profesiones 1–300, desglosada hasta los materiales básicos, en todos los personajes y bancos
- El filtro «Todas las profesiones» suma cada personaje con sus propias profesiones y su habilidad; además «Profesiones aprendidas», «Cada profesión una vez» (incluidas las no aprendidas) y personajes individuales; las profesiones de recolección se pueden excluir
- La necesidad y las existencias solo cuentan para los personajes de la facción actual
- Rutas de seis guías a elegir, con estado de las recetas y visitas a instructores
- Escaneo de la casa de subastas con indicación de costes
- Fuentes por material: nodos, enemigos, vendedores más cercanos
- Puntos de ruta a instructores y vendedores con flecha de dirección, etiqueta en el mapa y descripción en el enlace del chat
- Necesidad en las descripciones emergentes de objetos y en las vetas de mineral y las hierbas del mundo
- Profesiones, categorías y materiales ordenados alfabéticamente
