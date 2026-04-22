function plot_angio2d(C, P, Inh, F, diagnostics, varargin)
    % Funzione per visualizzare i risultati finali della simulazione 2D.
    %
    % Input:
    %   C, P, Inh, F = campi finali del modello, in forma matriciale Mx x My
    %   diagnostics  = struttura contenente griglia, parametri e diagnostiche
    %   varargin     = argomenti opzionali passati come coppie nome-valore
    %
    % La funzione genera quattro figure principali:
    %   1) campi 2D finali
    %   2) diagnostica temporale
    %   3) sezioni 1D lungo la mezzeria
    %   4) campo TAF con gradiente

    %% OPZIONI per salvataggio figure
    ip = inputParser;
    % Crea un oggetto inputParser, utile per gestire in modo ordinato
    % gli argomenti opzionali passati alla funzione.

    addParameter(ip, 'SaveFigs', false, @islogical);
    % Aggiunge il parametro opzionale 'SaveFigs'.
    % Valore di default: false.
    % Il terzo argomento controlla che il valore passato sia logico.

    addParameter(ip, 'Format',   'png', @ischar);
    % Aggiunge il parametro opzionale 'Format'.
    % Specifica il formato di salvataggio delle figure, ad esempio:
    % 'png', 'pdf', 'eps', 'fig', ecc.

    addParameter(ip, 'DPI',      300,   @isnumeric);
    % Aggiunge il parametro opzionale 'DPI'.
    % Serve a fissare la risoluzione di esportazione per i formati raster.

    addParameter(ip, 'OutDir',   './figures', @ischar);
    % Aggiunge il parametro opzionale 'OutDir'.
    % Indica la cartella in cui salvare le figure.

    parse(ip, varargin{:});
    % Analizza gli argomenti opzionali realmente passati alla funzione.

    opts = ip.Results;
    % Salva tutti i parametri letti in una struttura comoda da usare.

    if opts.SaveFigs && ~exist(opts.OutDir, 'dir')
        mkdir(opts.OutDir);
    end
    % Se il salvataggio è attivo e la cartella di output non esiste,
    % allora la cartella viene creata automaticamente.

    x = diagnostics.grid.x;
    % Estrae il vettore dei nodi lungo x dalla struttura diagnostics.

    y = diagnostics.grid.y;
    % Estrae il vettore dei nodi lungo y.

    X = diagnostics.grid.X;
    % Estrae la matrice 2D delle coordinate x su tutta la griglia.

    Y = diagnostics.grid.Y;
    % Estrae la matrice 2D delle coordinate y su tutta la griglia.

    p = diagnostics.params;
    % Estrae la struttura dei parametri usati nella simulazione.

    t = diagnostics.t;
    % Estrae il vettore dei tempi salvati durante il ciclo temporale.

    % FIGURA 1 — Campi 2D al tempo finale t = T_f
    fig1 = figure('Name', 'Campi 2D — t_f', ...
                  'Units', 'normalized', 'Position', [0.05 0.3 0.6 0.55]);
    % Crea una nuova finestra grafica.
    % - 'Name' assegna un nome alla finestra
    % - 'Units','normalized' usa coordinate relative allo schermo
    % - 'Position' controlla posizione e dimensioni della finestra

    fields  = {C, P, Inh, F};
    % Raccoglie i quattro campi finali in una cell array,
    % così possono essere gestiti in un ciclo.

    labels  = {'C  (densità EC)', 'P  (proteasi)', ...
               'Inh  (inibitore)', 'F  (ECM)'};
    % Etichette descrittive associate ai quattro campi.

    cmaps   = {'parula', 'hot', 'cool', 'summer'};
    % Colormap diverse per distinguere visivamente le variabili.

    for k = 1:4
        % Ciclo sui quattro campi da plottare.

        subplot(2,2,k);
        % Divide la figura in una griglia 2x2
        % e seleziona il riquadro k-esimo.

        pcolor(X, Y, fields{k});
        % Disegna una pseudocolor plot del campo 2D.
        % Ogni valore della matrice è rappresentato con un colore.

        shading interp;
        % Interpola i colori tra celle vicine per ottenere
        % una visualizzazione più liscia e meno "a blocchi".

        axis equal tight;
        % 'equal' impone la stessa scala sugli assi x e y.
        % 'tight' adatta i limiti degli assi ai dati.

        colormap(gca, cmaps{k});
        % Applica la colormap scelta al subplot corrente.

        colorbar;
        % Aggiunge una barra laterale che mostra la scala dei valori.

        xlabel('x');
        % Etichetta asse x.

        ylabel('y');
        % Etichetta asse y.

        title(sprintf('%s,  t = %.3f', labels{k}, t(end)), ...
              'Interpreter', 'none');
        % Titolo del subplot.
        % sprintf costruisce una stringa formattata inserendo:
        % - il nome della variabile
        % - il tempo finale della simulazione

        set(gca, 'FontSize', 10);
        % Imposta la dimensione del font dell'asse corrente.
    end

    sgtitle(sprintf('Angio2D — M_x=%d, M_y=%d, \\tau=%.2e', ...
            p.Mx, p.My, p.tau), 'FontSize', 13, 'FontWeight', 'bold');
    % Titolo generale dell'intera figura.
    % Riporta anche i principali parametri numerici:
    % dimensione della griglia e passo temporale.

    save_figure(fig1, 'campi_2d', opts);
    % Salva la figura se l'opzione SaveFigs è attiva.

    % FIGURA 2 — Diagnostica temporale (masse, energia)
    fig2 = figure('Name', 'Diagnostica temporale', ...
                  'Units', 'normalized', 'Position', [0.35 0.3 0.5 0.5]);
    % Crea la figura dedicata all'andamento temporale delle quantità globali.

    subplot(2,2,1);
    % Primo pannello della diagnostica.

    plot(t, diagnostics.mC, 'b-', 'LineWidth', 1.5);
    % Disegna la massa totale di C nel tempo.
    % 'b-' indica linea blu continua.

    xlabel('t');
    % Etichetta asse temporale.

    ylabel('\int C \, d\Omega');
    % Etichetta asse verticale:
    % rappresenta l'integrale spaziale di C.

    title('Massa cellule endoteliali');
    % Titolo del pannello.

    grid on;
    % Attiva la griglia sul grafico.

    set(gca, 'FontSize', 10);
    % Imposta la dimensione del font.

    subplot(2,2,2);
    % Secondo pannello.

    plot(t, diagnostics.mF, 'r-', 'LineWidth', 1.5);
    % Disegna la massa totale di F nel tempo.
    % 'r-' indica linea rossa continua.

    xlabel('t');
    ylabel('\int F \, d\Omega');
    title('Massa ECM');
    grid on;
    set(gca, 'FontSize', 10);
    % Stesse impostazioni usate per il primo pannello.

    subplot(2,2,3);
    % Terzo pannello.

    plot(t, diagnostics.En, 'k-', 'LineWidth', 1.5);
    % Disegna l'energia discreta nel tempo.
    % 'k-' indica linea nera continua.

    xlabel('t');
    ylabel('E(t)');
    title('Energia discreta');
    grid on;
    set(gca, 'FontSize', 10);

    subplot(2,2,4);
    % Quarto pannello: variazione relativa delle masse.

    % Variazione relativa di massa C rispetto a t=0
    mC_rel = (diagnostics.mC - diagnostics.mC(1)) / max(abs(diagnostics.mC(1)), eps);
    % Calcola la variazione relativa della massa di C
    % rispetto al valore iniziale.
    % eps evita una divisione per zero nel caso patologico
    % di massa iniziale nulla o quasi nulla.

    mF_rel = (diagnostics.mF - diagnostics.mF(1)) / max(abs(diagnostics.mF(1)), eps);
    % Stesso calcolo per la massa di F.

    plot(t, mC_rel, 'b--', t, mF_rel, 'r--', 'LineWidth', 1.2);
    % Disegna nello stesso pannello le due variazioni relative:
    % - blu tratteggiato per C
    % - rosso tratteggiato per F

    xlabel('t');
    ylabel('\Delta m / m_0');
    title('Variazione relativa masse');

    legend('C', 'F', 'Location', 'best');
    % Inserisce la legenda scegliendo automaticamente
    % la posizione migliore.

    grid on;
    set(gca, 'FontSize', 10);

    sgtitle('Diagnostica temporale', 'FontSize', 13, 'FontWeight', 'bold');
    % Titolo generale della seconda figura.

    save_figure(fig2, 'diagnostica', opts);
    % Salva la figura, se richiesto.

    % FIGURA 3 — Sezioni 1D lungo la mezzeria y = Ly/2
    fig3 = figure('Name', 'Sezioni 1D', ...
                  'Units', 'normalized', 'Position', [0.15 0.2 0.45 0.45]);
    % Crea la figura per le sezioni monodimensionali.

    jmid = round(p.My / 2);  % indice della mezzeria
    % Seleziona l'indice corrispondente circa alla mezzeria del dominio
    % lungo la direzione y.

    subplot(2,1,1);
    % Primo pannello della figura delle sezioni.

    plot(x, C(:, jmid), 'b-',  'LineWidth', 1.5, 'DisplayName', 'C'); hold on;
    % Disegna la sezione di C lungo la linea orizzontale y = y(jmid).

    plot(x, F(:, jmid), 'r--', 'LineWidth', 1.5, 'DisplayName', 'F');
    % Disegna sulla stessa figura anche la sezione di F.

    xlabel('x');
    ylabel('ampiezza');
    title(sprintf('C  e  F  lungo y = %.2f', y(jmid)));
    % Titolo che specifica la quota y effettiva della sezione.

    legend('Location', 'best');
    % Aggiunge la legenda.

    grid on;
    set(gca, 'FontSize', 10);

    subplot(2,1,2);
    % Secondo pannello.

    plot(x, P(:, jmid),   'm-',  'LineWidth', 1.5, 'DisplayName', 'P'); hold on;
    % Disegna la sezione di P alla stessa quota y.

    plot(x, Inh(:, jmid), 'c--', 'LineWidth', 1.5, 'DisplayName', 'Inh');
    % Disegna la sezione di Inh.

    xlabel('x');
    ylabel('ampiezza');
    title(sprintf('P  e  Inh  lungo y = %.2f', y(jmid)));
    legend('Location', 'best');
    grid on;
    set(gca, 'FontSize', 10);

    sgtitle('Sezioni 1D — mezzeria', 'FontSize', 13, 'FontWeight', 'bold');
    % Titolo generale della figura delle sezioni.

    save_figure(fig3, 'sezioni_1d', opts);
    % Salva la figura se richiesto.

    % FIGURA 4 — Campo TAF + gradiente (quiver)
    fig4 = figure('Name', 'Campo TAF', ...
                  'Units', 'normalized', 'Position', [0.25 0.15 0.4 0.45]);
    % Crea la figura dedicata al campo TAF e al suo gradiente.

    T_plot = exp(-p.epsilon^(-1) * ((X-p.Lx).^2 + (Y-p.Ly/2).^2));
    % Ricostruisce il campo TAF usando la formula analitica.

    Tx_plot = -2*p.epsilon^(-1) * (X - p.Lx)    .* T_plot;
    % Derivata del TAF rispetto a x.

    Ty_plot = -2*p.epsilon^(-1) * (Y - p.Ly/2)  .* T_plot;
    % Derivata del TAF rispetto a y.

    pcolor(X, Y, T_plot);
    % Disegna la mappa 2D del campo TAF.

    shading interp;
    axis equal tight;
    % Migliora la resa grafica e mantiene la corretta proporzione geometrica.

    colormap(gca, 'jet');
    % Applica la colormap 'jet' al grafico corrente.

    colorbar;
    % Mostra la barra dei colori.

    hold on;
    % Mantiene il grafico corrente attivo per sovrapporre le frecce del gradiente.

    % Quiver su sotto-griglia
    skip = max(1, round(p.Mx / 16));
    % Calcola il passo di campionamento per non disegnare troppe frecce.
    % Più la griglia è fine, più si diradano i vettori.

    idx = 1:skip:p.Mx;
    % Indici selezionati lungo x.

    idy = 1:skip:p.My;
    % Indici selezionati lungo y.

    quiver(X(idx, idy), Y(idx, idy), ...
           Tx_plot(idx, idy), Ty_plot(idx, idy), ...
           0.8, 'w', 'LineWidth', 1.0);
    % Disegna il campo vettoriale del gradiente del TAF
    % sui soli nodi selezionati.
    % - 0.8 è il fattore di scala delle frecce
    % - 'w' imposta il colore bianco
    % - 'LineWidth' controlla lo spessore

    xlabel('x');
    ylabel('y');

    title(sprintf('TAF  T(x,y)  e  \\nablaT,  \\epsilon = %.2f', p.epsilon));
    % Titolo del grafico con indicazione del parametro epsilon.

    set(gca, 'FontSize', 11);
    % Dimensione del font dell'asse.

    save_figure(fig4, 'campo_TAF', opts);
    % Salva la quarta figura se richiesto.

    fprintf('\n  >> plot_angio2d: 4 figure generate.\n');
    % Stampa un messaggio informativo nel Command Window.

    if opts.SaveFigs
        fprintf('     Salvate in: %s  (formato %s, %d dpi)\n', ...
                opts.OutDir, opts.Format, opts.DPI);
    end
    % Se il salvataggio è attivo, stampa anche la cartella,
    % il formato e la risoluzione usati.
end


function save_figure(fig, name, opts)
    % Funzione di supporto per il salvataggio delle figure.
    %
    % Input:
    %   fig  = handle della figura da salvare
    %   name = nome base del file
    %   opts = struttura delle opzioni di esportazione

    if ~opts.SaveFigs, return; end
    % Se SaveFigs è false, la funzione termina subito
    % senza fare nulla.

    fname = fullfile(opts.OutDir, [name '.' opts.Format]);
    % Costruisce il percorso completo del file da salvare,
    % unendo cartella, nome base ed estensione.

    switch lower(opts.Format)
        % Seleziona il tipo di esportazione in base al formato richiesto.

        case 'fig'
            savefig(fig, fname);
            % Salva nel formato nativo MATLAB .fig,
            % utile per riaprire e modificare la figura in seguito.

        case 'pdf'
            exportgraphics(fig, fname, 'ContentType', 'vector');
            % Esporta in PDF vettoriale.
            % Ottimo per articoli, relazioni e tesi.

        case 'eps'
            exportgraphics(fig, fname, 'ContentType', 'vector');
            % Esporta in EPS vettoriale.

        otherwise  % png, jpg, tiff ...
            exportgraphics(fig, fname, 'Resolution', opts.DPI);
            % Esporta nei formati raster usando la risoluzione desiderata.
    end
end