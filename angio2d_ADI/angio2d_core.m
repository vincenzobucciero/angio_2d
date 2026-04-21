% ANGIO2D

%   p = default_params();
%   [C, P, Inh, F, diag] = angio2d_core(p);
%   plot_angio2d(C, P, Inh, F, diag);

function [C, P, Inh, F, diagnostics] = angio2d_core(p)
if nargin < 1, p = default_params(); end

%%  GRIGLIA 
hx = p.Lx/(p.Mx-1);
hy = p.Ly/(p.My-1);
x  = linspace(0, p.Lx, p.Mx)';
y  = linspace(0, p.Ly, p.My)';
[X, Y] = meshgrid(x, y);
X = X'; Y = Y';   % Mx × My

M = p.Mx * p.My;  % DOF per variabile

%%  CAMPO TAF (analitico, precalcolato) 
T  = exp(-p.epsilon^(-1) * ((X-p.Lx).^2 + (Y-p.Ly/2).^2));
Tx = -2*p.epsilon^(-1) * (X-p.Lx) .* T;
Ty = -2*p.epsilon^(-1) * (Y-p.Ly/2) .* T;

% Potenziale ausiliario 
phi_x = Tx ./ (1 + p.alpha4*T);
phi_y = Ty ./ (1 + p.alpha4*T);

%%  OPERATORI SPAZIALI 2D (Kronecker) 
[Lx1d, Gx1d] = build_1d_ops(p.Mx, hx);
[Ly1d, Gy1d] = build_1d_ops(p.My, hy);
Ix = speye(p.Mx);
Iy = speye(p.My);

Lap2D = kron(Iy, sparse(Lx1d)) + kron(sparse(Ly1d), Ix);

Gx2D = kron(Iy, sparse(Gx1d));
Gy2D = kron(sparse(Gy1d), Ix);

%% CONDIZIONI INIZIALI 

C = p.C0 * 0.5 * (1 - tanh((X - p.a)/p.sigma_IC));

% Proteasi, Inibitore, ECM: perturbazioni coseno deterministiche [eq. (9)]
P   = 0.1  + 0.01  * cos(2*pi*X) .* cos(2*pi*Y);
Inh = 0.1  + 0.005 * cos(4*pi*X) .* cos(4*pi*Y);
F   = 1.0  + 0.01  * cos(pi*X)   .* cos(pi*Y);

%%  VETTORIZZAZIONE 
C = C(:); P = P(:); Inh = Inh(:); F = F(:);
T_v = T(:); phi_x_v = phi_x(:); phi_y_v = phi_y(:);

tau    = p.tau;
Nsteps = p.Nsteps;

%% DIAGNOSTICA (masse, energia) 
diagnostics.t  = zeros(1, Nsteps+1);
diagnostics.mC = zeros(1, Nsteps+1);
diagnostics.mF = zeros(1, Nsteps+1);
diagnostics.En = zeros(1, Nsteps+1);
diagnostics.t(1)  = 0;
diagnostics.mC(1) = trap2d(C);
diagnostics.mF(1) = trap2d(F);
Cx = Gx2D*C; Cy = Gy2D*C;
diagnostics.En(1) = 0.5*(p.dC*(Cx'*Cx + Cy'*Cy) + F'*F)*hx*hy;

%  TIME LOOP — Strang Splitting [eq. (33)]
for n = 1:Nsteps

    %  SEMI-PASSO REAZIONE
    [C, P, Inh, F] = reaction_step(C, P, Inh, F, tau/2);
    C = max(C,0); P = max(P,0); Inh = max(Inh,0); F = max(F,0);

    % PASSO DIFFUSIONE ADI  
    C   = adi_step(C,   p.Mx, p.My, hx, hy, p.dC, tau);
    P   = adi_step(P,   p.Mx, p.My, hx, hy, p.dP, tau);
    Inh = adi_step(Inh, p.Mx, p.My, hx, hy, p.dI, tau);
    % F non diffonde: 

    % SEMI-PASSO REAZIONE
    [C, P, Inh, F] = reaction_step(C, P, Inh, F, tau/2);
    C = max(C,0); P = max(P,0); Inh = max(Inh,0); F = max(F,0);

    % Salva diagnostica
    diagnostics.t(n+1)  = n*tau;
    diagnostics.mC(n+1) = trap2d(C);
    diagnostics.mF(n+1) = trap2d(F);
    Cx = Gx2D*C; Cy = Gy2D*C;
    diagnostics.En(n+1) = 0.5*(p.dC*(Cx'*Cx + Cy'*Cy) + F'*F)*hx*hy;
end

% Reshape per output
C   = reshape(C,   p.Mx, p.My);
P   = reshape(P,   p.Mx, p.My);
Inh = reshape(Inh, p.Mx, p.My);
F   = reshape(F,   p.Mx, p.My);

diagnostics.grid.x = x; diagnostics.grid.y = y;
diagnostics.grid.X = X; diagnostics.grid.Y = Y;
diagnostics.params = p;


    function [Cn, Pn, In, Fn] = reaction_step(Cv, Pv, Iv, Fv, dt)
        % Operatori differenziali sullo stato corrente
        Lap_I = Lap2D * Iv;
        Lap_F = Lap2D * Fv;
        GxI = Gx2D * Iv;  GyI = Gy2D * Iv;
        GxF = Gx2D * Fv;  GyF = Gy2D * Fv;
        GxC = Gx2D * Cv;  GyC = Gy2D * Cv;

        vx = p.alpha2*GxI - p.alpha1*GxF - p.alpha3*phi_x_v;
        vy = p.alpha2*GyI - p.alpha1*GyF - p.alpha3*phi_y_v;

        div_v = p.alpha2*Lap_I - p.alpha1*Lap_F;

        RC = vx.*GxC + vy.*GyC + div_v.*Cv + p.k1*Cv.*(1-Cv);

        RP = -p.k3*Pv.*Iv + p.k4*T_v.*Cv + p.k5*T_v - p.k6*Pv;
        RI = -p.k3*Pv.*Iv;
        RF = -p.k2*Pv.*Fv;

        % Forward Euler
        Cn = Cv + dt*RC;
        Pn = Pv + dt*RP;
        In = Iv + dt*RI;
        Fn = Fv + dt*RF;
    end

    %  QUADRATURA TRAPEZOIDALE 2D  [eq. (46)]
    
    function val = trap2d(u)
        U = reshape(u, p.Mx, p.My);
        W = ones(p.Mx, p.My);
        W(1,:) = 0.5; W(end,:) = 0.5;
        W(:,1) = 0.5; W(:,end) = 0.5;
        val = hx * hy * sum(sum(W .* U));
    end

end  %



function u_new = adi_step(u, Mx, My, hx, hy, d, tau)

    U = reshape(u, Mx, My);
    tau2 = tau / 2;
    rx = d * tau2 / hx^2;   % r_x = dτ/(2h_x²)
    ry = d * tau2 / hy^2;   % r_y = dτ/(2h_y²)

    %  SEMI-PASSO 1 (38)
    
    RHS = zeros(Mx, My);
    for j = 1:My
        if j == 1
            % Bordo: u_{i,0} = u_{i,2} 
            RHS(:,j) = (1 - 2*ry)*U(:,j) + 2*ry*U(:,j+1);
        elseif j == My
            RHS(:,j) = 2*ry*U(:,j-1) + (1 - 2*ry)*U(:,j);
        else
            RHS(:,j) = ry*U(:,j-1) + (1 - 2*ry)*U(:,j) + ry*U(:,j+1);
        end
    end

    % Sistema tridiagonale eq. (41)
    ax = -rx * ones(Mx, 1);  ax(1)   = 0;
    bx = (1 + 2*rx) * ones(Mx, 1);
    cx = -rx * ones(Mx, 1);  cx(end) = 0;
    cx(1)   = -2*rx;  % Neumann bordo sinistro
    ax(end) = -2*rx;  % Neumann bordo destro

    U_star = zeros(Mx, My);
    for j = 1:My
        U_star(:,j) = thomas(ax, bx, cx, RHS(:,j));
    end

    % SEMI-PASSO 2: implicito y, esplicito x 
    RHS2 = zeros(Mx, My);
    for i = 1:Mx
        if i == 1
            RHS2(i,:) = (1 - 2*rx)*U_star(i,:) + 2*rx*U_star(i+1,:);
        elseif i == Mx
            RHS2(i,:) = 2*rx*U_star(i-1,:) + (1 - 2*rx)*U_star(i,:);
        else
            RHS2(i,:) = rx*U_star(i-1,:) + (1 - 2*rx)*U_star(i,:) + rx*U_star(i+1,:);
        end
    end

    % Sistema tridiagonale T_y
    ay = -ry * ones(My, 1);  ay(1)   = 0;
    by = (1 + 2*ry) * ones(My, 1);
    cy = -ry * ones(My, 1);  cy(end) = 0;
    cy(1)   = -2*ry;
    ay(end) = -2*ry;

    U_new = zeros(Mx, My);
    for i = 1:Mx
        U_new(i,:) = thomas(ay, by, cy, RHS2(i,:)')';
    end

    u_new = U_new(:);
end



% THOMAS ALGORITHM  
function x = thomas(a, b, c, d)
    n = length(b);
    c_star = zeros(n, 1);
    d_star = zeros(n, 1);

    % Forward sweep
    c_star(1) = c(1) / b(1);
    d_star(1) = d(1) / b(1);
    for i = 2:n
        denom = b(i) - a(i)*c_star(i-1);
        if i < n
            c_star(i) = c(i) / denom;
        end
        d_star(i) = (d(i) - a(i)*d_star(i-1)) / denom;
    end

    % Back substitution
    x = zeros(n, 1);
    x(n) = d_star(n);
    for i = n-1:-1:1
        x(i) = d_star(i) - c_star(i)*x(i+1);
    end
end



function [L, G] = build_1d_ops(M, h)

    % Laplaciano
    L = gallery('tridiag', M, 1, -2, 1) / h^2;
    L = full(L);
    L(1, 2)     = 2/h^2;   % Ghost node: u_0 = u_2
    L(end, end-1) = 2/h^2; % Ghost node: u_{M+1} = u_{M-1}

    % Gradiente centrale
    G = zeros(M);
    for i = 2:M-1
        G(i, i+1) =  1/(2*h);
        G(i, i-1) = -1/(2*h);
    end
end


% PARAMETRI DEL MODELLO

function p = default_params()
    % Dominio
    p.Lx = 1;  p.Ly = 1;
    p.Mx = 64; p.My = 64;
    p.Tf = 0.5;

    % Coefficienti di diffusione
    p.dC = 0.001; p.dP = 0.001; p.dI = 0.001;

    % Sensibilità chemotattiche/aptotattiche
    p.alpha1 = 0.4;  % haptotaxis (ECM)
    p.alpha2 = 0.3;  % chemotaxis (inibitore)
    p.alpha3 = 0.5;  % chemotaxis (TAF)
    p.alpha4 = 0.1;  % saturazione TAF

    % Costanti cinetiche
    p.k1 = 0.1;  % proliferazione EC
    p.k2 = 0.3;  % degradazione ECM
    p.k3 = 0.2;  % interazione proteasi-inibitore
    p.k4 = 0.4;  % produzione proteasi da EC
    p.k5 = 0.1;  % produzione proteasi da TAF
    p.k6 = 0.2;  % decadimento proteasi

    % TAF
    p.epsilon = 1.0;

    % Condizioni iniziali
    p.C0 = 1.0;       % densità massima EC
    p.a = 0.1;        % posizione fronte
    p.sigma_IC = 0.02; % larghezza transizione

    % Passo temporale (CFL advettivo)
    hx = p.Lx / (p.Mx - 1);
    v_max = max([p.alpha1, p.alpha2, p.alpha3]) * 2/hx;
    tau_adv = hx / v_max;
    p.tau = 0.8 * tau_adv;
    p.Nsteps = ceil(p.Tf / p.tau);
    p.tau = p.Tf / p.Nsteps;  % Aggiustamento per raggiungere Tf esattamente
end







