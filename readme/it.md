# BerufeTracker

[English](../README.md) · [Deutsch](de.md) · [Français](fr.md) · [Español](es.md) · [Português](pt-BR.md) · [Italiano](it.md) · [Русский](ru.md) · [한국어](ko.md) · [简体中文](zh-CN.md) · [繁體中文](zh-TW.md)

Quanto Minerale di Rame, Stoffa di Lino e Fiorpace ti servono ancora per portare le tue professioni a 300? BerufeTracker fa il calcolo: per ogni professione, fino ai materiali di base e su tutti i tuoi personaggi e le tue banche.

Per **WoW Forever**, nella lingua del tuo client di gioco: inglese, tedesco, francese, spagnolo, portoghese, italiano, russo, coreano e cinese (semplificato e tradizionale).

## Funzionalità

**Materiali**
- Fabbisogno totale di tutte le professioni, scomposto fino ai materiali di base. Una Barra di Bronzo, per esempio, conta come Barre di Rame e di Stagno, e queste a loro volta come minerale.
- Quello che hai nelle borse, in banca e nella cassetta della posta di tutti i tuoi personaggi della fazione attuale viene sottratto. Se è installato [BagBrother/Bagnon](https://www.curseforge.com/wow/addons/bagnon), vengono inclusi anche i personaggi che BerufeTracker non conosce ancora.
- Filtri: "Personaggio attuale" (predefinito) mostra solo le professioni del personaggio collegato. "Tutti i personaggi (professioni apprese)" somma tutti i personaggi della tua fazione con le loro professioni e abilità. "Professioni apprese (miglior personaggio)" conta ogni professione appresa una volta, "Tutte le professioni (anche non apprese)" ogni professione una volta, quelle non apprese da 1, oppure scegli un singolo personaggio. Il percorso mostra solo le professioni della selezione; per un personaggio, le professioni non ancora apprese mostrano solo il primo istruttore. Le professioni di raccolta possono essere escluse.
- Passando il mouse vedi il fabbisogno per professione, il prezzo e il costo d'acquisto, come è distribuita la scorta tra i tuoi personaggi e dove trovare il materiale: punti di raccolta con zone, mostri con livelli e i mercanti più vicini della tua fazione.
- La scansione della casa d'aste mostra quanto costerebbe comprare tutto invece di raccoglierlo da te. Materiali e Percorso mostrano lo stesso costo d'acquisto, istruttori e ricette inclusi.

**Percorso**
- Il percorso passo per passo di ogni professione, con quanto ne resta da fare.
- Scegli la tua guida: Metabot, RankedBoost, Wowhead, wowtbc.gg, GoldGoblin o wow-professions, per singola professione o per tutte insieme.
- **Percorso calcolato più economico:** una guida propria, indipendente dalle altre guide. Per ogni punto abilità sceglie la più economica di tutte le ricette della professione (dati di gioco di Forever), in base al colore della ricetta e alla probabilità di salire, con i prezzi della casa d'aste, dei mercanti, degli istruttori e delle ricette. Le ricette conosciute e i materiali già posseduti contano come gratuiti; gli oggetti dei mercanti con scorte limitate contano solo se sono nella casa d'aste; le ricette con tempo di recupero sono escluse. **Percorso più economico delle guide** fa lo stesso con i passi delle altre guide. **Percorso calcolato più veloce** sceglie le ricette con il tempo di creazione più breve e tiene conto anche dei tempi di recupero di materiali come la stoffa lunare. I tuoi percorsi non costano mai più di una delle altre guide e vengono ricalcolati all'apertura della finestra.
- Ogni guida mostra il tempo di creazione e il costo dalla tua abilità attuale; i menu delle guide confrontano il costo di tutte le guide.
- Le ricette mancanti sono segnalate insieme a dove trovarle.
- Le visite all'istruttore compaiono nel punto giusto del percorso, con l'istruttore più vicino che ti insegna il grado successivo.

**Punti di riferimento**
- Ctrl+clic sinistro su un istruttore o un materiale imposta un punto di riferimento verso l'istruttore o il mercante più vicino.
- Una barra con una freccia di direzione e una descrizione mostra la destinazione. Cliccandola si apre la mappa sulla destinazione.
- Anche la mappa mostra un'etichetta. Quando condividi il segnalino della mappa in chat, la descrizione viene inviata insieme.
- Il punto di riferimento scompare non appena parli con il PNG.

**Nel gioco**
- I tooltip degli oggetti (borse, banca, casa d'aste, bottino) mostrano quanto ti serve ancora con il filtro attuale.
- Le vene di minerale e le erbe nel mondo mostrano quanto ti serve ancora da esse e se raccoglierle ti dà ancora punti abilità.
- I nemici mostrano quali materiali che ti servono lasciano cadere, oltre alla stoffa degli umanoidi e al cuoio delle bestie (scuoiatura) del loro livello.
- Armi e armature mostrano quali materiali di incantamento si ottengono circa disincantandole, se ti servono.
- La finestra della professione del gioco evidenzia la ricetta che il tuo percorso consiglia come prossima; il suo tooltip mostra i materiali necessari e quali personaggi li hanno.

**Finestra**
- Scheda Personaggi: livello, gilda, oro, professioni e materiali di ogni personaggio; le banche di gilda seguono i personaggi della loro gilda. Scegli di chi conta la scorta.
- La finestra si può ridimensionare; le professioni aperte vengono ricordate per personaggio.

## Utilizzo

- `/berufe` o il pulsante della minimappa apre la finestra.
- Per i prezzi, apri la casa d'aste e clicca su "Scansiona prezzi" (o `/berufe scan`).
- `/berufe skill <professione> <valore>` imposta un'abilità a mano se non viene rilevata. Senza valore torna a valere il rilevamento automatico.
- Ogni personaggio deve accedere una volta con l'addon perché le sue professioni siano note. La sua banca viene registrata non appena la apri una volta.

## Limitazioni

- I nomi di oggetti, istruttori, mercanti e punti di raccolta provengono dal gioco e da QuestieDB. In italiano, e per le poche ricette senza oggetto creato (come gli incantamenti), i nomi vengono mostrati in inglese. I luoghi delle ricette sono disponibili solo in tedesco e in inglese.
- Le distanze sono in linea d'aria e valgono solo sullo stesso continente.
- Non tutte le ricette hanno un luogo noto.
- I dati su mercanti e luoghi provengono da QuestieDB e possono contenere singoli errori.

## Fonti e ringraziamenti

- **Percorsi:** [Metabot](https://metabot.gg/en/wow-forever/professions), [RankedBoost](https://rankedboost.com/world-of-warcraft/forever/), [Wowhead](https://www.wowhead.com/forever/profession-leveling-guides), [wowtbc.gg](https://wowtbc.gg/warcraftforever/), [GoldGoblin](https://classic.goldgoblin.net/berufe/) e [wow-professions](https://www.wow-professions.com/forever/). I percorsi sono stati condensati per l'addon. Trovi le guide complete con tutte le spiegazioni sui rispettivi siti; il link è mostrato nella selezione della guida dell'addon.
- **Istruttori, mercanti e luoghi** sono stati generati da QuestieDB (GPLv3). Grazie al team di Questie e a tutti i collaboratori. BerufeTracker non è un progetto del team di Questie.
- Le **probabilità e quantità di bottino** dei nemici provengono dal [database cMaNGOS Classic](https://github.com/cmangos/classic-db) (GPLv3). Sono valori di Classic 1.12 e in WoW Forever possono essere diversi.
- **Ricette, colori di abilità e reagenti** del «Percorso calcolato più economico» provengono dai dati di gioco di WoW Forever tramite [wago.tools](https://wago.tools); costi degli istruttori e scorte dei mercanti dal database cMaNGOS Classic.

## Licenza

GPLv3, vedi `LICENSE.md`.
