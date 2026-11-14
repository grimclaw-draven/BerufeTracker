# BerufeTracker

[English](README.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português](README.pt-BR.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [한국어](README.ko.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md)

Quanto Minério de Cobre, Tecido de Linho e Botão-da-paz você ainda precisa para levar suas profissões a 300? O BerufeTracker faz a conta: para cada profissão, até os materiais básicos e somando todos os seus personagens e bancos.

Para **WoW Forever**, no idioma do seu cliente de jogo: inglês, alemão, francês, espanhol, português, italiano, russo, coreano e chinês (simplificado e tradicional).

## Recursos

**Materiais**
- Necessidade total de todas as profissões, decomposta até os materiais básicos. Uma Barra de Bronze, por exemplo, conta como Barras de Cobre e de Estanho, e estas por sua vez como minério.
- O que você tem nas bolsas, no banco e na caixa de correio de todos os seus personagens da sua facção atual é descontado. Se o [BagBrother/Bagnon](https://www.curseforge.com/wow/addons/bagnon) estiver instalado, os personagens que o BerufeTracker ainda não conhece também são incluídos.
- Filtros: "Todas as profissões" soma todos os personagens da sua facção com suas próprias profissões e perícia. "Profissões aprendidas" conta cada profissão aprendida uma vez, "Cada profissão uma vez" cada profissão uma vez, inclusive as não aprendidas, ou escolha um único personagem. As profissões de coleta podem ser deixadas de fora.
- Ao passar o mouse, aparecem a necessidade por profissão, o preço e o custo de compra, como o estoque está distribuído entre seus personagens e onde conseguir o material: pontos de coleta com zonas, monstros com níveis e os vendedores mais próximos da sua facção.
- A varredura da Casa de Leilões mostra quanto custaria comprar tudo em vez de coletar você mesmo.

**Rota**
- A rota passo a passo de cada profissão, com quanto ainda falta.
- Escolha seu guia: Metabot, RankedBoost, Wowhead, wowtbc.gg, GoldGoblin ou wow-professions, por profissão ou para todas de uma vez.
- As receitas que faltam são marcadas junto com onde encontrá-las.
- As visitas ao instrutor aparecem no ponto certo da rota, com o instrutor mais próximo que ensina o próximo nível.

**Pontos de referência**
- Ctrl+clique esquerdo em um instrutor ou material define um ponto de referência até o instrutor ou vendedor mais próximo.
- Uma barra com uma seta de direção e uma descrição mostra o destino. Clicar nela abre o mapa no destino.
- O mapa também mostra um rótulo. Quando você compartilha o marcador do mapa no bate-papo, a descrição é enviada junto.
- O ponto de referência desaparece assim que você fala com o PNJ.

**No jogo**
- As dicas de itens (bolsas, banco, Casa de Leilões, saque) mostram quanto você ainda precisa com o filtro atual.
- Os veios de minério e as ervas no mundo mostram o que você ainda precisa deles.

## Uso

- `/berufe` ou o botão do minimapa abre a janela.
- Para os preços, abra a Casa de Leilões e clique em "Escanear preços" (ou `/berufe scan`).
- `/berufe skill <profissão> <valor>` define uma perícia manualmente se ela não for detectada. Sem valor, a detecção automática volta a valer.
- Cada personagem precisa entrar no jogo uma vez com o addon para que suas profissões sejam conhecidas. O banco é registrado assim que você o abre uma vez.

## Limitações

- Os nomes de itens, instrutores, vendedores e pontos de coleta vêm do jogo e do QuestieDB. Para italiano, e para as poucas receitas sem item fabricado (como encantamentos), os nomes aparecem em inglês. Os locais das receitas só estão disponíveis em alemão e inglês.
- As distâncias são em linha reta e só valem no mesmo continente.
- Nem toda receita tem um local conhecido.
- Os dados de vendedores e locais vêm do QuestieDB e podem conter erros pontuais.

## Fontes e agradecimentos

- **Rotas:** [Metabot](https://metabot.gg/en/wow-forever/professions), [RankedBoost](https://rankedboost.com/world-of-warcraft/forever/), [Wowhead](https://www.wowhead.com/forever/profession-leveling-guides), [wowtbc.gg](https://wowtbc.gg/warcraftforever/), [GoldGoblin](https://classic.goldgoblin.net/berufe/) e [wow-professions](https://www.wow-professions.com/forever/). As rotas foram condensadas para o addon. Você encontra os guias completos com todas as explicações nos respectivos sites; o link aparece na seleção de guia do addon.
- **Instrutores, vendedores e locais** foram gerados a partir do QuestieDB (GPLv3). Obrigado à equipe do Questie e a todos os colaboradores. O BerufeTracker não é um projeto da equipe do Questie.

## Licença

GPLv3, veja `LICENSE.md`.
