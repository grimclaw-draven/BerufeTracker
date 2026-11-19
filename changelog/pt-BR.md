# Changelog

## 1.3.2

- Botão do minimapa: dica com uma breve descrição e o que clicar e arrastar fazem
- O botão do minimapa usa LibDBIcon quando outro addon traz a biblioteca; coletores de botões (ex.: Leatrix Plus) o mostram com sua própria dica
- A lista de addons mostra o número da versão em vez de "@project-version@"

## 1.3.1

- Nova opção "Destacar minério/ervas" (aba Materiais ou /berufe glitzern): ervas e veios próximos brilham, forte se você precisa do material ou se coletar ainda rende pontos; fica desligada enquanto PÄNIK Gildentools ou outro addon já fizer isso
- Os caminhos calculados usam primeiro os materiais que você já tem enquanto ainda rendem pontos (ex.: Antídoto antes de Atadura de lã, Pargo antes de Bagre); o caminho mais rápido só se não custar tempo extra
- Receitas só contam como aprendidas para o personagem da rota se ele tiver a profissão; senão contam as dos seus outros personagens
- Dica de ervas e minério: quantas vezes, aproximadamente, ainda coletar, até cinza e para suas profissões
- Dica: "Falta" aparece em vermelho

## 1.3.0

- Novo guia próprio "Caminho calculado mais rápido": as receitas com o menor tempo de fabricação, incluindo recargas de materiais como o tecido lunar
- Tempo de fabricação e custo a partir de agora sob cada profissão, para cada guia
- "Caminho mais barato dos guias" agora é calculado ponto a ponto como o "Caminho calculado mais barato"; nenhum dos dois é mais caro do que um dos outros guias
- Os caminhos próprios consideram a chance de subir em cada ponto e usam seus materiais só enquanto eles durarem
- Sem travadas depois de fabricar: os caminhos próprios são calculados em segundo plano ao abrir a janela
- Novo filtro padrão "Personagem atual"; filtros renomeados para "Todos os personagens (profissões aprendidas)", "Profissões aprendidas (melhor personagem)" e "Todas as profissões (também não aprendidas)". A rota mostra só as profissões da seleção, as não aprendidas só com o primeiro instrutor
- Materiais e Rota mostram o mesmo custo de compra, incluindo instrutores, receitas e uma estimativa para materiais sem preço
- Janela de profissão do jogo: a receita que sua rota recomenda em seguida tem uma moldura fina e um fundo tingido; ao passar o mouse você vê qual guia a recomenda, os materiais e quais personagens os têm
- Ervas e minério: a dica mostra se coletar ainda rende pontos de perícia
- Aba Personagens: nível, guilda, ouro, profissões e materiais de cada personagem; os bancos de guilda seguem os personagens da guilda
- Valores em ouro com ícones de moedas
- Janela: tamanho mínimo, recuo mais claro; as profissões expandidas são lembradas por personagem
- Corrigido: bolsas, perícias e receitas de um personagem podiam se perder ao sair do jogo

## 1.2.0

- Dois guias próprios: "Caminho calculado mais barato" (a partir de todas as receitas da profissão nos dados de jogo do Forever: para cada ponto de perícia a receita mais barata por cor e chance) e "Caminho mais barato dos guias" (a partir dos passos dos outros guias)
- Custo a partir de agora para cada guia nos menus de guia e ao lado de "Guia para todas:", com custos de instrutores e receitas; materiais que você já tem contam como grátis
- Itens de vendedor com estoque limitado só contam se estiverem na casa de leilões; a varredura de preços agora inclui as receitas
- Produtos intermediários (tecidos, barras …) são comprados na casa de leilões quando isso é mais barato do que fabricar
- A rota segue o personagem escolhido no filtro; primeiro as profissões principais, depois Primeiros Socorros e Culinária, Pesca por último
- Passos com recarga longa ou que só se obtêm por missão são marcados
- A janela pode ser redimensionada
- As dicas dos inimigos mostram quais materiais necessários eles soltam, com chance e quantidade (dados: cMaNGOS)
- Desencantar: a dica do item mostra os resultados possíveis com chance e quantidade
- Materiais de artesanato que nenhuma rota usa mostram "Não é usado em nenhuma rota"

## 1.1.1

- A necessidade em veios de minério e ervas agora aparece de forma confiável, também ao passar diretamente de um nodo para o próximo
- Português: botão “Escanear preços” em vez de “Varrer preços”
- READMEs em todos os idiomas do jogo

## 1.1.0

- Todos os idiomas do jogo: inglês, alemão, francês, espanhol, português, italiano, russo, coreano e chinês (simplificado e tradicional)
- Nomes de itens, receitas, instrutores, vendedores e nodos no idioma do jogo
- Profissões, itens e receitas são reconhecidos independentemente do idioma do jogo

## 1.0.1

- Grau de instrutor Aprendiz (1-75) adicionado à rota
- Todos os graus mostram sua faixa, por exemplo “Artífice (75-150)”
- Graus concluídos continuam indicando seu instrutor
- O grau atual continua colorido e visível com “Só pendentes”

## 1.0.0 – primeiro lançamento

- Necessidade de materiais de todas as profissões 1–300, decomposta até os materiais básicos, em todos os personagens e bancos
- O filtro “Todas as profissões” soma cada personagem com suas próprias profissões e sua perícia; além disso “Profissões aprendidas”, “Cada profissão uma vez” (inclusive as não aprendidas) e personagens individuais; profissões de coleta podem ser excluídas
- Necessidade e estoque contam apenas para personagens da facção atual
- Rotas de seis guias à escolha, com status das receitas e visitas aos instrutores
- Varredura da Casa de Leilões com exibição de custos
- Fontes por material: nodos, inimigos, vendedores mais próximos
- Pontos de referência para instrutores e vendedores com seta de direção, rótulo no mapa e descrição no link do bate-papo
- Necessidade nas dicas de itens e em veios de minério e ervas no mundo
- Profissões, categorias e materiais em ordem alfabética
