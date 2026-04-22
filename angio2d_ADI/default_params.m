function p = default_params()
    % Definisce una funzione senza argomenti in ingresso.
    % La funzione restituisce una struct chiamata 'p'
    % che contiene tutti i parametri fisici, numerici
    % e di discretizzazione del modello Angio2D.

    p.Lx = 1; p.Ly = 1;
    % Dimensioni del dominio spaziale rettangolare.
    % Qui il dominio è [0, Lx] x [0, Ly] = [0,1] x [0,1].

    p.Mx = 64; p.My = 64;
    % Numero di punti della griglia nelle due direzioni spaziali:
    % - Mx punti lungo x
    % - My punti lungo y
    % Una griglia 64x64 dà una discretizzazione abbastanza fine
    % senza essere troppo costosa dal punto di vista computazionale.

    p.Tf = 0.5;
    % Tempo finale della simulazione.
    % Il solver evolverà il sistema da t = 0 fino a t = Tf.

    p.dC = 0.001; p.dP = 0.001; p.dI = 0.001;
    % Coefficienti di diffusione delle tre variabili che diffondono:
    % - dC: diffusione delle cellule endoteliali C
    % - dP: diffusione delle proteasi P
    % - dI: diffusione dell'inibitore Inh
    % Valori piccoli indicano diffusione lenta.

    p.alpha1 = 0.4; p.alpha2 = 0.3; p.alpha3 = 0.5; p.alpha4 = 0.1;
    % Parametri di sensibilità tattica:
    % - alpha1: intensità dell'aptotassi/haptotassi rispetto a F (ECM)
    % - alpha2: intensità della chemotassi rispetto a Inh
    % - alpha3: intensità della chemotassi rispetto al TAF
    % - alpha4: parametro di saturazione del contributo del TAF
    %
    % In pratica questi coefficienti controllano quanto fortemente
    % le cellule rispondono ai gradienti chimici o della matrice.

    p.k1 = 0.1; p.k2 = 0.3; p.k3 = 0.2;
    % Prime tre costanti cinetiche del modello:
    % - k1: crescita/proliferazione logistica delle cellule endoteliali
    % - k2: degradazione della matrice extracellulare F dovuta alle proteasi
    % - k3: interazione/reazione tra proteasi e inibitore

    p.k4 = 0.4; p.k5 = 0.1; p.k6 = 0.2;
    % Altre costanti cinetiche:
    % - k4: produzione di proteasi indotta dalle cellule endoteliali
    % - k5: produzione di proteasi indotta dal TAF
    % - k6: decadimento naturale delle proteasi

    p.epsilon = 1.0;
    % Parametro che controlla la larghezza del profilo spaziale del TAF.
    % In molti modelli il TAF è costruito come una gaussiana centrata
    % vicino al bordo destro del dominio; epsilon regola quanto essa
    % è diffusa o concentrata.

    p.C0 = 1.0; p.a = 0.1; p.sigma_IC = 0.02;
    % Parametri della condizione iniziale delle cellule endoteliali:
    % - C0: valore massimo iniziale di densità cellulare
    % - a: posizione iniziale del fronte cellulare
    % - sigma_IC: larghezza della transizione del fronte
    %
    % Questi parametri vengono usati per costruire un profilo tipo tanh,
    % cioè un fronte iniziale regolare e non discontinuo.

    hx = p.Lx/(p.Mx-1);
    % Passo di griglia lungo x.
    % Se il dominio [0,Lx] è suddiviso in Mx punti,
    % la distanza tra due nodi consecutivi è Lx/(Mx-1).

    v_max = max([p.alpha1,p.alpha2,p.alpha3])*2/hx;
    % Stima della velocità massima caratteristica del trasporto/avvezione.
    % Si prende il massimo tra i coefficienti tattici alpha1, alpha2, alpha3
    % e lo si combina con un fattore 2/hx, che deriva da una stima discreta
    % del gradiente massimo su griglia.
    %
    % Questa quantità serve a imporre una condizione di stabilità
    % sul passo temporale.

    tau_adv = hx/v_max;
    % Passo temporale limite associato al vincolo advettivo/CFL.
    % In sostanza, per stabilità numerica il passo di tempo deve essere
    % proporzionato allo spazio e inversamente proporzionato alla velocità.

    p.tau = 0.8*tau_adv;
    % Si sceglie il passo temporale effettivo come l'80% del limite stimato.
    % Il fattore 0.8 introduce un margine di sicurezza per la stabilità.

    p.Nsteps = ceil(p.Tf/p.tau);
    % Numero totale di passi temporali necessari per arrivare almeno a Tf.
    % 'ceil' arrotonda per eccesso, così siamo sicuri di coprire tutto
    % l'intervallo temporale [0, Tf].

    p.tau = p.Tf/p.Nsteps;
    % Ricalibrazione finale del passo temporale.
    % Dopo aver fissato il numero intero di passi, si ridefinisce tau
    % in modo che Nsteps * tau = Tf esattamente.
    %
    % Questo evita di fermarsi leggermente prima o leggermente dopo Tf.
end