# Changelog

## 1.5.0

- Zone di raccolta: sotto Erbalismo, Estrazione, Scuoiatura e Pesca il percorso mostra le mappe migliori per la tua abilità attuale per densità e vicinanza, con l'intervallo in cui convengono e colorate per difficoltà. Clic apre la mappa, clic destro nasconde tutto
- Mappa del mondo: punti di comparsa e giro per le tue professioni di raccolta su ogni mappa di zona e sulla minimappa; erbe come quadrati, minerali come rombi
- Pannello sulla mappa (pulsante in basso a sinistra): attiva Erbalismo ed Estrazione, giro comune per entrambe, singoli materiali con icona e colori di abilità (dal grigio al rosso)
- Passando su una zona della mappa del mondo compare l'intervallo di abilità delle tue professioni di raccolta
- I punti mancanti nei dati vengono appresi durante la raccolta
- Pesca: intervallo di abilità per zona e consiglio della zona più impegnativa in cui peschi ancora con sicurezza
- Istruttori: aggiunti molti istruttori mancanti (altri titoli, istruttori di WoW Forever); insegnano un grado in più rispetto a Classic, come visto in gioco
- Clic su un istruttore o materiale: waypoint e mappa sul più vicino, ogni clic successivo passa al successivo ("istruttore 1 di 18")
- Scheda BerufeTracker sulla finestra delle professioni (accanto a quella di ATT): aggancia lì accanto il percorso della professione aperta
- Bagliore e suono solo per le professioni di raccolta apprese; riconosciuti i cadaveri scuoiabili con bottino; funziona con la pausa PNG di PÄNIK
- Tooltip dei nemici: "Scuoiatura" nel colore di abilità per quella bestia; le bestie non scuoiabili non mostrano più cuoio
- Il tooltip di erbe e minerali mostra la probabilità attuale di un punto abilità
- La barra del waypoint è ora accanto alla minimappa
- Clic su un passo del percorso o un materiale realizzabile: si apre la finestra della professione con la ricetta selezionata e la quantità inserita (al massimo quanto puoi realizzare ora); ricetta mancante: waypoint al mercante o istruttore
- I tooltip di passi e materiali realizzabili mostrano la probabilità attuale di un punto abilità
- Clic destro sul pulsante della minimappa, della mappa o su una zona di raccolta: mostra o nasconde punti e percorsi; la selezione resta

## 1.4.0

- «Evidenzia raccoglibili» (prima «Evidenzia minerali/erbe») si attiva automaticamente se il personaggio conosce Erbalismo, Estrazione o Scuoiatura, con un effetto scintillante molto più grande: bagliore pulsante, raggio di luce e stelle che girano intorno all'oggetto
- Scuoiatura: anche le bestie scuoiabili brillano (beige chiaro), grigie se la tua abilità non basta
- Nuova opzione «Suono» accanto (o /berufe glitzern ton): un avviso leggero appena c'è qualcosa da raccogliere vicino, una volta per oggetto; con o senza bagliore
- Funziona insieme a PÄNIK Gildentools invece di restare spento; disattiva lì minerali ed erbe, altrimenti brillano entrambi
- Il tooltip di erbe e minerali termina con una riga vuota, per separare le righe di altri addon

## 1.3.2

- Pulsante della minimappa: tooltip con una breve descrizione e cosa fanno clic e trascinamento
- Il pulsante della minimappa usa LibDBIcon se un altro addon fornisce la libreria; i raccoglitori di pulsanti (es. Leatrix Plus) lo mostrano con il proprio tooltip
- L'elenco degli addon mostra il numero di versione invece di "@project-version@"

## 1.3.1

- Nuova opzione "Evidenzia minerali/erbe" (scheda Materiali o /berufe glitzern): erbe e vene vicine brillano, intense se ti serve il materiale o se raccogliere dà ancora punti; resta spenta finché PÄNIK Gildentools o un altro addon lo fa già
- I percorsi calcolati usano prima i materiali che hai già, finché danno punti (es. Antidoto prima di Benda di lana, Dentice prima di Pesce gatto); il percorso più veloce solo se non costa tempo in più
- Le ricette contano come apprese solo per il personaggio del percorso se ha la professione; altrimenti contano quelle degli altri personaggi
- Tooltip di erbe e minerali: quante volte circa raccogliere ancora, fino al grigio e per le tue professioni
- Tooltip: "Manca ancora" è in rosso

## 1.3.0

- Nuova guida propria "Percorso calcolato più veloce": le ricette con il tempo di creazione più breve, inclusi i tempi di recupero di materiali come la stoffa lunare
- Tempo di creazione e costo da adesso sotto ogni professione, per ogni guida
- "Percorso più economico delle guide" ora viene calcolato punto per punto come il "Percorso calcolato più economico"; nessuno dei due costa mai più di una delle altre guide
- I percorsi propri tengono conto della probabilità di salire a ogni punto e usano i tuoi materiali solo finché bastano
- Niente più scatti dopo la creazione: i percorsi propri vengono calcolati in background all'apertura della finestra
- Nuovo filtro predefinito "Personaggio attuale"; filtri rinominati in "Tutti i personaggi (professioni apprese)", "Professioni apprese (miglior personaggio)" e "Tutte le professioni (anche non apprese)". Il percorso mostra solo le professioni della selezione, quelle non apprese solo con il primo istruttore
- Materiali e Percorso mostrano lo stesso costo d'acquisto, inclusi istruttori, ricette e una stima per i materiali senza prezzo
- Finestra della professione del gioco: la ricetta che il percorso consiglia come prossima ha una cornice sottile e uno sfondo colorato; passandoci sopra vedi quale guida la consiglia, i materiali e quali personaggi li hanno
- Erbe e minerale: il tooltip mostra se la raccolta dà ancora punti abilità
- Scheda Personaggi: livello, gilda, oro, professioni e materiali di ogni personaggio; le banche di gilda seguono i personaggi della loro gilda
- Importi in oro con icone delle monete
- Finestra: dimensione minima, rientri più chiari; le professioni aperte vengono ricordate per personaggio
- Corretto: borse, abilità e ricette di un personaggio potevano andare perse all'uscita

## 1.2.0

- Due guide proprie: «Percorso calcolato più economico» (da tutte le ricette della professione nei dati di gioco di Forever: per ogni punto abilità la ricetta più economica per colore e probabilità) e «Percorso più economico delle guide» (dai passi delle altre guide)
- Costo da ora per ogni guida nei menu delle guide e accanto a «Guida per tutte:», con i costi di istruttori e ricette; i materiali già posseduti contano come gratuiti
- Gli oggetti dei mercanti con scorte limitate contano solo se sono nella casa d'aste; la scansione dei prezzi include ora anche le ricette
- I prodotti intermedi (rotoli, lingotti …) vengono comprati nella casa d'aste quando costa meno che crearli
- Il percorso segue il personaggio scelto nel filtro; prima le professioni principali, poi Primo Soccorso e Cucina, Pesca per ultima
- I passi con un lungo tempo di recupero o ottenibili solo tramite missione sono segnalati
- La finestra si può ridimensionare
- I tooltip dei nemici mostrano quali materiali necessari rilasciano, con probabilità e quantità (dati: cMaNGOS)
- Disincantare: il tooltip dell'oggetto mostra i risultati possibili con probabilità e quantità
- I materiali di artigianato che non servono a nessun percorso mostrano «Non serve a nessun percorso»

## 1.1.1

- Il fabbisogno su vene di minerale ed erbe ora appare in modo affidabile, anche passando direttamente da un nodo al successivo
- Portoghese: pulsante «Escanear preços» invece di «Varrer preços»
- README in tutte le lingue del gioco

## 1.1.0

- Tutte le lingue del gioco: inglese, tedesco, francese, spagnolo, portoghese, italiano, russo, coreano e cinese (semplificato e tradizionale)
- Nomi di oggetti, ricette, istruttori, mercanti e nodi nella lingua del gioco
- Professioni, oggetti e ricette vengono riconosciuti indipendentemente dalla lingua del gioco

## 1.0.1

- Grado di istruttore Apprendista (1-75) aggiunto al percorso
- Tutti i gradi mostrano il loro intervallo, ad es. «Esperto (75-150)»
- I gradi completati indicano ancora il loro istruttore
- Il grado attuale resta colorato e visibile con «Solo mancanti»

## 1.0.0 – prima versione

- Fabbisogno di materiali di tutte le professioni 1–300, scomposto fino ai materiali di base, su tutti i personaggi e le banche
- Il filtro «Tutte le professioni» somma ogni personaggio con le sue professioni e il suo livello di abilità; inoltre «Professioni apprese», «Ogni professione una volta» (anche quelle non apprese) e singoli personaggi; le professioni di raccolta si possono escludere
- Fabbisogno e scorte contano solo per i personaggi della fazione attuale
- Percorsi da sei guide a scelta, con stato delle ricette e visite agli istruttori
- Scansione della Casa d’Aste con indicazione dei costi
- Fonti per materiale: nodi, nemici, mercanti più vicini
- Waypoint verso istruttori e mercanti con freccia di direzione, etichetta sulla mappa e descrizione nel link della chat
- Fabbisogno nei tooltip degli oggetti e su vene di minerale ed erbe nel mondo
- Professioni, categorie e materiali in ordine alfabetico
