% ANGIO2D
%
% Esempio d'uso del solver completo:
%
%   p = default_params();
%   [C, P, Inh, F, diag] = angio2d_core(p);
%   plot_angio2d(C, P, Inh, F, diag);
%
% Questo file implementa il nucleo numerico del modello 2D di angiogenesi:
% - costruzione della griglia cartesiana uniforme
% - costruzione del campo TAF e dei suoi gradienti
% - costruzione degli operatori discreti 1D e 2D
% - inizializzazione delle variabili del modello
% - integrazione temporale con Strang splitting
% - diffusione trattata con schema ADI
% - reazione/advezione trattate esplicitamente
% - raccolta di diagnostiche numeriche

function [C, P, Inh, F, diagnostics] = angio2d_core(p)
    % Definisce la funzione principale del solver.
    %
    % Input:
    %   p = struct contenente tutti i parametri del modello
    %
    % Output:
    %   C, P, Inh, F = campi finali al tempo finale Tf
    %   diagnostics  = struttura con tempi, masse, energia e griglia

    if nargin < 1, p = default_params(); end
    % Se l'utente non passa alcun parametro in ingresso,
    % vengono caricati i parametri di default tramite default_params().

    %% GRIGLIA
    hx = p.Lx/(p.Mx-1);
    % Passo spaziale in direzione x.

    hy = p.Ly/(p.My-1);
    % Passo spaziale in direzione y.

    x  = linspace(0, p.Lx, p.Mx)';
    % Vettore colonna dei nodi lungo x, equispaziati in [0, Lx].

    y  = linspace(0, p.Ly, p.My)';
    % Vettore colonna dei nodi lungo y, equispaziati in [0, Ly].

    [X, Y] = meshgrid(x, y);
    % Costruisce la griglia bidimensionale.
    % meshgrid produce matrici di coordinate X e Y.

    X = X'; 
    Y = Y';   % Mx × My
    % Trasposizione per avere matrici orientate come Mx x My,
    % cioè coerenti con l'indicizzazione interna usata nel codice.

    M = p.Mx * p.My;  % DOF per variabile
    % Numero totale di gradi di libertà per ciascun campo scalare.
    % Ogni variabile vive su tutta la griglia 2D, quindi ha Mx*My nodi.

    %% CAMPO TAF (analitico, precalcolato)
    T  = exp(-p.epsilon^(-1) * ((X-p.Lx).^2 + (Y-p.Ly/2).^2));
    % Costruisce il campo TAF stazionario T(x,y).
    % È una gaussiana centrata in prossimità del bordo destro del dominio
    % nel punto (Lx, Ly/2), come nel paper.

    Tx = -2*p.epsilon^(-1) * (X-p.Lx) .* T;
    % Derivata parziale del TAF rispetto a x.
    % Si ottiene derivando analiticamente la gaussiana.

    Ty = -2*p.epsilon^(-1) * (Y-p.Ly/2) .* T;
    % Derivata parziale del TAF rispetto a y.

    % Potenziale ausiliario
    phi_x = Tx ./ (1 + p.alpha4*T);
    % Componente x del gradiente del potenziale ausiliario phi.
    % Serve per riscrivere il termine chemotattico relativo al TAF
    % in forma più comoda dal punto di vista numerico.

    phi_y = Ty ./ (1 + p.alpha4*T);
    % Componente y del gradiente del potenziale ausiliario phi.

    %% OPERATORI SPAZIALI 2D (Kronecker)
    [Lx1d, Gx1d] = build_1d_ops(p.Mx, hx);
    % Costruisce gli operatori 1D lungo x:
    % - Lx1d = Laplaciano discreto 1D
    % - Gx1d = gradiente discreto 1D

    [Ly1d, Gy1d] = build_1d_ops(p.My, hy);
    % Costruisce gli operatori 1D lungo y.

    Ix = speye(p.Mx);
    % Matrice identità sparsa di dimensione Mx x Mx.

    Iy = speye(p.My);
    % Matrice identità sparsa di dimensione My x My.

    Lap2D = kron(Iy, sparse(Lx1d)) + kron(sparse(Ly1d), Ix);
    % Costruisce il Laplaciano discreto 2D tramite prodotti di Kronecker.
    % Questa è la discretizzazione standard su griglia cartesiana:
    %   Δ_h = I_y ⊗ L_x + L_y ⊗ I_x
    % come descritto nel paper.

    Gx2D = kron(Iy, sparse(Gx1d));
    % Gradiente discreto 2D in direzione x.

    Gy2D = kron(sparse(Gy1d), Ix);
    % Gradiente discreto 2D in direzione y.

    %% CONDIZIONI INIZIALI

    C = p.C0 * 0.5 * (1 - tanh((X - p.a)/p.sigma_IC));
    % Condizione iniziale della densità di cellule endoteliali.
    % È un profilo sigmoide regolare, localizzato vicino al bordo sinistro,
    % coerente con la formulazione data nel paper.

    % Proteasi, Inibitore, ECM: perturbazioni coseno deterministiche [eq. (9)]
    P   = 0.1  + 0.01  * cos(2*pi*X) .* cos(2*pi*Y);
    % Condizione iniziale delle proteasi:
    % valore medio 0.1 + piccola perturbazione armonica.

    Inh = 0.1  + 0.005 * cos(4*pi*X) .* cos(4*pi*Y);
    % Condizione iniziale dell'inibitore:
    % anche qui valore medio costante + perturbazione liscia.

    F   = 1.0  + 0.01  * cos(pi*X)   .* cos(pi*Y);
    % Condizione iniziale della matrice extracellulare (ECM).
    % Il valore medio è 1.0 con piccola modulazione coseno.

    %% VETTORIZZAZIONE
    C = C(:); 
    P = P(:); 
    Inh = Inh(:); 
    F = F(:);
    % Tutti i campi vengono convertiti da matrici Mx x My
    % a vettori colonna di lunghezza M.
    % Questo è necessario per applicare gli operatori matriciali 2D.

    T_v = T(:); 
    phi_x_v = phi_x(:); 
    phi_y_v = phi_y(:);
    % Anche il TAF e i gradienti del potenziale ausiliario
    % vengono vettorizzati per essere usati nelle operazioni algebriche.

    tau    = p.tau;
    % Passo temporale.

    Nsteps = p.Nsteps;
    % Numero totale di passi temporali.

    %% DIAGNOSTICA (masse, energia)
    diagnostics.t  = zeros(1, Nsteps+1);
    % Vettore dei tempi della simulazione.

    diagnostics.mC = zeros(1, Nsteps+1);
    % Massa totale della variabile C a ogni tempo.

    diagnostics.mF = zeros(1, Nsteps+1);
    % Massa totale della variabile F a ogni tempo.

    diagnostics.En = zeros(1, Nsteps+1);
    % Energia discreta monitorata nel tempo.

    diagnostics.t(1)  = 0;
    % Tempo iniziale.

    diagnostics.mC(1) = trap2d(C);
    % Massa iniziale di C calcolata con quadratura trapezoidale 2D.

    diagnostics.mF(1) = trap2d(F);
    % Massa iniziale di F.

    Cx = Gx2D*C; 
    Cy = Gy2D*C;
    % Gradienti discreti iniziali di C nelle due direzioni.

    diagnostics.En(1) = 0.5*(p.dC*(Cx'*Cx + Cy'*Cy) + F'*F)*hx*hy;
    % Energia discreta iniziale.
    % Qui si usa:
    % - contributo del gradiente di C pesato da dC
    % - contributo quadratico di F
    % moltiplicati per l'elemento di area hx*hy.

    % TIME LOOP — Strang Splitting [eq. (33)]
    for n = 1:Nsteps
        % Ciclo temporale principale.
        % A ogni iterazione si avanza di un passo tau.

        % SEMI-PASSO REAZIONE
        [C, P, Inh, F] = reaction_step(C, P, Inh, F, tau/2);
        % Primo mezzo passo della parte non diffusiva:
        % reazione + trasporto/tassi.

        C = max(C,0); 
        P = max(P,0); 
        Inh = max(Inh,0); 
        F = max(F,0);
        % Proiezione sui valori non negativi.
        % Serve a evitare piccole oscillazioni numeriche non fisiche
        % che produrrebbero concentrazioni negative.

        % PASSO DIFFUSIONE ADI
        C   = adi_step(C,   p.Mx, p.My, hx, hy, p.dC, tau);
        % Diffusione di C risolta con ADI.

        P   = adi_step(P,   p.Mx, p.My, hx, hy, p.dP, tau);
        % Diffusione di P risolta con ADI.

        Inh = adi_step(Inh, p.Mx, p.My, hx, hy, p.dI, tau);
        % Diffusione di Inh risolta con ADI.

        % F non diffonde:
        % La variabile F non ha termine diffusivo nel modello,
        % quindi durante questo sottopasso resta invariata.

        % SEMI-PASSO REAZIONE
        [C, P, Inh, F] = reaction_step(C, P, Inh, F, tau/2);
        % Secondo mezzo passo di reazione/trasporto.
        % Insieme al primo mezzo passo realizza lo Strang splitting simmetrico.

        C = max(C,0); 
        P = max(P,0); 
        Inh = max(Inh,0); 
        F = max(F,0);
        % Si impone nuovamente la non negatività dopo il secondo mezzo passo.

        % Salva diagnostica
        diagnostics.t(n+1)  = n*tau;
        % Salva il tempo attuale.

        diagnostics.mC(n+1) = trap2d(C);
        % Massa di C al tempo corrente.

        diagnostics.mF(n+1) = trap2d(F);
        % Massa di F al tempo corrente.

        Cx = Gx2D*C; 
        Cy = Gy2D*C;
        % Ricalcola i gradienti di C per la stima energetica.

        diagnostics.En(n+1) = 0.5*(p.dC*(Cx'*Cx + Cy'*Cy) + F'*F)*hx*hy;
        % Aggiorna l'energia discreta.
    end

    % Reshape per output
    C   = reshape(C,   p.Mx, p.My);
    % Riporta C dalla forma vettoriale alla forma matriciale 2D.

    P   = reshape(P,   p.Mx, p.My);
    % Riporta P in forma Mx x My.

    Inh = reshape(Inh, p.Mx, p.My);
    % Riporta Inh in forma Mx x My.

    F   = reshape(F,   p.Mx, p.My);
    % Riporta F in forma Mx x My.

    diagnostics.grid.x = x; 
    diagnostics.grid.y = y;
    % Salva i vettori di griglia 1D nella struttura diagnostics.

    diagnostics.grid.X = X; 
    diagnostics.grid.Y = Y;
    % Salva anche le matrici 2D di coordinate.

    diagnostics.params = p;
    % Memorizza una copia dei parametri usati nella simulazione.

    function [Cn, Pn, In, Fn] = reaction_step(Cv, Pv, Iv, Fv, dt)
        % Funzione annidata che esegue un passo esplicito di
        % reazione + termini di trasporto/tassi.
        %
        % Input:
        %   Cv, Pv, Iv, Fv = stato corrente in forma vettoriale
        %   dt             = passo di tempo locale
        %
        % Output:
        %   Cn, Pn, In, Fn = nuovo stato dopo il passo esplicito

        % Operatori differenziali sullo stato corrente
        Lap_I = Lap2D * Iv;
        % Laplaciano discreto dell'inibitore I.

        Lap_F = Lap2D * Fv;
        % Laplaciano discreto della matrice extracellulare F.

        GxI = Gx2D * Iv;  
        GyI = Gy2D * Iv;
        % Gradienti di I nelle due direzioni.

        GxF = Gx2D * Fv;  
        GyF = Gy2D * Fv;
        % Gradienti di F nelle due direzioni.

        GxC = Gx2D * Cv;  
        GyC = Gy2D * Cv;
        % Gradienti di C nelle due direzioni.

        vx = p.alpha2*GxI - p.alpha1*GxF - p.alpha3*phi_x_v;
        % Componente x del campo di velocità advettivo.
        % Combina:
        % - chemotassi rispetto a I
        % - haptotassi rispetto a F
        % - chemotassi rispetto al TAF tramite phi_x

        vy = p.alpha2*GyI - p.alpha1*GyF - p.alpha3*phi_y_v;
        % Componente y del campo di velocità advettivo.

        div_v = p.alpha2*Lap_I - p.alpha1*Lap_F;
        % Divergenza del campo di velocità semplificata.
        % In questa implementazione si usano i contributi di I e F.
        % Il contributo associato a Delta(phi) non è incluso esplicitamente.

        RC = vx.*GxC + vy.*GyC + div_v.*Cv + p.k1*Cv.*(1-Cv);
        % Termine sorgente della variabile C.
        % Contiene:
        % - trasporto advettivo v · grad(C)
        % - termine compressibile (div v) C
        % - crescita logistica k1 C (1-C)

        RP = -p.k3*Pv.*Iv + p.k4*T_v.*Cv + p.k5*T_v - p.k6*Pv;
        % Termine di reazione della variabile P:
        % - consumo per interazione con I
        % - produzione indotta da C e dal TAF
        % - decadimento naturale

        RI = -p.k3*Pv.*Iv;
        % Termine di reazione dell'inibitore I:
        % consumo per interazione con le proteasi.

        RF = -p.k2*Pv.*Fv;
        % Termine di reazione dell'ECM F:
        % degradazione dovuta alla presenza di proteasi.

        % Forward Euler
        Cn = Cv + dt*RC;
        % Aggiornamento esplicito di C con Euler in avanti.

        Pn = Pv + dt*RP;
        % Aggiornamento esplicito di P.

        In = Iv + dt*RI;
        % Aggiornamento esplicito di I.

        Fn = Fv + dt*RF;
        % Aggiornamento esplicito di F.
    end

    % QUADRATURA TRAPEZOIDALE 2D [eq. (46)]
    function val = trap2d(u)
        % Funzione annidata che approssima l'integrale di un campo 2D
        % tramite la regola del trapezio composta su griglia rettangolare.

        U = reshape(u, p.Mx, p.My);
        % Ricostruisce la matrice 2D a partire dal vettore.

        W = ones(p.Mx, p.My);
        % Inizializza i pesi a 1 in tutti i nodi interni.

        W(1,:) = 0.5; 
        W(end,:) = 0.5;
        % Peso 1/2 sui bordi sinistro e destro.

        W(:,1) = 0.5; 
        W(:,end) = 0.5;
        % Peso 1/2 sui bordi inferiore e superiore.
        % Agli angoli il peso diventa automaticamente 1/4
        % perché il nodo appartiene a due bordi.

        val = hx * hy * sum(sum(W .* U));
        % Approssimazione dell'integrale:
        % somma pesata dei valori nodali moltiplicata per l'area elementare.
    end

end



function u_new = adi_step(u, Mx, My, hx, hy, d, tau)
    % Esegue un passo diffusivo con metodo ADI (Alternating Direction Implicit).
    %
    % Input:
    %   u   = campo vettorializzato da diffondere
    %   Mx, My = numero di nodi in x e y
    %   hx, hy = passi di griglia
    %   d   = coefficiente di diffusione della variabile
    %   tau = passo temporale completo
    %
    % Output:
    %   u_new = stato dopo il passo diffusivo

    U = reshape(u, Mx, My);
    % Ricostruisce il campo in forma matriciale 2D.

    tau2 = tau / 2;
    % Mezzo passo temporale, usato nei coefficienti ADI.

    rx = d * tau2 / hx^2;   % r_x = dτ/(2h_x²)
    % Rapporto adimensionale di diffusione nella direzione x.

    ry = d * tau2 / hy^2;   % r_y = dτ/(2h_y²)
    % Rapporto adimensionale di diffusione nella direzione y.

    % SEMI-PASSO 1 (38)

    RHS = zeros(Mx, My);
    % Termine noto del primo semi-passo:
    % esplicito in y, implicito in x.

    for j = 1:My
        % Si costruisce una colonna alla volta del termine noto.

        if j == 1
            % Bordo inferiore con Neumann omogenea:
            % il ghost node soddisfa u_{i,0} = u_{i,2}

            RHS(:,j) = (1 - 2*ry)*U(:,j) + 2*ry*U(:,j+1);
            % Formula modificata al bordo.

        elseif j == My
            % Bordo superiore con Neumann omogenea.

            RHS(:,j) = 2*ry*U(:,j-1) + (1 - 2*ry)*U(:,j);
            % Formula modificata al bordo.

        else
            RHS(:,j) = ry*U(:,j-1) + (1 - 2*ry)*U(:,j) + ry*U(:,j+1);
            % Formula standard ai nodi interni nella direzione y.
        end
    end

    % Sistema tridiagonale eq. (41)
    ax = -rx * ones(Mx, 1);  
    ax(1)   = 0;
    % Sottodiagonale del sistema implicito in x.

    bx = (1 + 2*rx) * ones(Mx, 1);
    % Diagonale principale del sistema implicito in x.

    cx = -rx * ones(Mx, 1);  
    cx(end) = 0;
    % Sovradiagonale del sistema implicito in x.

    cx(1)   = -2*rx;  
    % Correzione al bordo sinistro per condizione di Neumann.

    ax(end) = -2*rx;  
    % Correzione al bordo destro per condizione di Neumann.

    U_star = zeros(Mx, My);
    % Soluzione intermedia del primo semi-passo ADI.

    for j = 1:My
        U_star(:,j) = thomas(ax, bx, cx, RHS(:,j));
        % Per ogni colonna si risolve un sistema tridiagonale indipendente
        % usando l'algoritmo di Thomas.
    end

    % SEMI-PASSO 2: implicito y, esplicito x
    RHS2 = zeros(Mx, My);
    % Termine noto del secondo semi-passo.

    for i = 1:Mx
        % Si costruisce il termine noto riga per riga.

        if i == 1
            RHS2(i,:) = (1 - 2*rx)*U_star(i,:) + 2*rx*U_star(i+1,:);
            % Bordo sinistro con Neumann omogenea.

        elseif i == Mx
            RHS2(i,:) = 2*rx*U_star(i-1,:) + (1 - 2*rx)*U_star(i,:);
            % Bordo destro con Neumann omogenea.

        else
            RHS2(i,:) = rx*U_star(i-1,:) + (1 - 2*rx)*U_star(i,:) + rx*U_star(i+1,:);
            % Formula interna lungo x.
        end
    end

    % Sistema tridiagonale T_y
    ay = -ry * ones(My, 1);  
    ay(1)   = 0;
    % Sottodiagonale del sistema implicito in y.

    by = (1 + 2*ry) * ones(My, 1);
    % Diagonale principale del sistema implicito in y.

    cy = -ry * ones(My, 1);  
    cy(end) = 0;
    % Sovradiagonale del sistema implicito in y.

    cy(1)   = -2*ry;
    % Correzione al bordo inferiore.

    ay(end) = -2*ry;
    % Correzione al bordo superiore.

    U_new = zeros(Mx, My);
    % Campo finale dopo il passo ADI.

    for i = 1:Mx
        U_new(i,:) = thomas(ay, by, cy, RHS2(i,:)')';
        % Per ogni riga si risolve un sistema tridiagonale in y.
        % La trasposizione serve perché thomas lavora con vettori colonna.
    end

    u_new = U_new(:);
    % Ritorna il risultato in forma vettoriale.
end



% THOMAS ALGORITHM
function x = thomas(a, b, c, d)
    % Risolve un sistema tridiagonale Ax = d con l'algoritmo di Thomas.
    %
    % a = sottodiagonale
    % b = diagonale principale
    % c = sovradiagonale
    % d = termine noto
    %
    % Il metodo è efficiente e costa O(n).

    n = length(b);
    % Dimensione del sistema.

    c_star = zeros(n, 1);
    % Sovradiagonale modificata dopo eliminazione in avanti.

    d_star = zeros(n, 1);
    % Termine noto modificato.

    % Forward sweep
    c_star(1) = c(1) / b(1);
    % Primo coefficiente normalizzato della sovradiagonale.

    d_star(1) = d(1) / b(1);
    % Primo coefficiente normalizzato del termine noto.

    for i = 2:n
        denom = b(i) - a(i)*c_star(i-1);
        % Pivot effettivo dopo eliminazione del termine sottodiagonale.

        if i < n
            c_star(i) = c(i) / denom;
            % Aggiorna la sovradiagonale modificata.
        end

        d_star(i) = (d(i) - a(i)*d_star(i-1)) / denom;
        % Aggiorna il termine noto modificato.
    end

    % Back substitution
    x = zeros(n, 1);
    % Inizializza il vettore soluzione.

    x(n) = d_star(n);
    % Ultima componente della soluzione.

    for i = n-1:-1:1
        x(i) = d_star(i) - c_star(i)*x(i+1);
        % Ricostruzione all'indietro delle altre componenti.
    end
end



function [L, G] = build_1d_ops(M, h)
    % Costruisce gli operatori discreti 1D:
    % - L = Laplaciano con condizioni di Neumann omogenee
    % - G = gradiente centrale discreto

    % Laplaciano
    L = gallery('tridiag', M, 1, -2, 1) / h^2;
    % Crea la matrice tridiagonale standard del Laplaciano 1D.

    L = full(L);
    % Converte la matrice in formato pieno per poter modificare gli estremi.

    L(1, 2)       = 2/h^2;   
    % Correzione al bordo sinistro usando ghost node:
    % u_0 = u_2, coerente con Neumann omogenea.

    L(end, end-1) = 2/h^2;
    % Correzione analoga al bordo destro:
    % u_{M+1} = u_{M-1}.

    % Gradiente centrale
    G = zeros(M);
    % Inizializza la matrice gradiente.

    for i = 2:M-1
        G(i, i+1) =  1/(2*h);
        % Coefficiente del nodo successivo.

        G(i, i-1) = -1/(2*h);
        % Coefficiente del nodo precedente.
    end
    % Le righe di bordo restano nulle, coerentemente con
    % il gradiente nullo imposto ai bordi da Neumann.
end