% ANGIO2D
%
% Example usage of the full solver:
%
%   p = default_params();
%   [C, P, Inh, F, diag] = angio2d_core(p);
%   plot_angio2d(C, P, Inh, F, diag);
%
% This file implements the numerical core of the 2D angiogenesis model:
% - build uniform Cartesian grid
% - construct the TAF field and its gradients
% - build discrete 1D and 2D operators
% - initialize model fields
% - time integration via Strang splitting
% - diffusion solved with ADI scheme
% - reaction/advection treated explicitly
% - collect numerical diagnostics

function [C, P, Inh, F, diagnostics] = angio2d_core(p)
    % Main solver function.
    %
    % Input:
    %   p = struct with all model parameters
    %
    % Output:
    %   C, P, Inh, F = final fields at time Tf
    %   diagnostics  = struct with times, masses, energy and grid

    if nargin < 1, p = default_params(); end
    % If no parameter struct is provided, load defaults.

    %% GRID
    hx = p.Lx/(p.Mx-1);
    % Grid spacing in x.

    hy = p.Ly/(p.My-1);
    % Grid spacing in y.

    x  = linspace(0, p.Lx, p.Mx)';
    % Column vector of x-nodes.

    y  = linspace(0, p.Ly, p.My)';
    % Column vector of y-nodes.

    [X, Y] = meshgrid(x, y);
    % Build 2D coordinate arrays.

    X = X'; 
    Y = Y';   % Mx × My
    % Transpose to have arrays shaped Mx x My to match internal indexing.

    M = p.Mx * p.My;  % DOF per variable
    % Total degrees of freedom per scalar field (Mx*My).

    %% TAF FIELD (analytic, precomputed)
    T  = exp(-p.epsilon^(-1) * ((X-p.Lx).^2 + (Y-p.Ly/2).^2));
    % Stationary TAF field T(x,y): Gaussian centered near (Lx, Ly/2).

    Tx = -2*p.epsilon^(-1) * (X-p.Lx) .* T;
    % Partial derivative of TAF w.r.t. x.

    Ty = -2*p.epsilon^(-1) * (Y-p.Ly/2) .* T;
    % Partial derivative of TAF w.r.t. y.

    % Auxiliary potential components
    phi_x = Tx ./ (1 + p.alpha4*T);
    % x-component of auxiliary potential gradient used for chemotaxis.

    phi_y = Ty ./ (1 + p.alpha4*T);
    % y-component of auxiliary potential gradient.

    %% 2D SPATIAL OPERATORS (Kronecker)
    [Lx1d, Gx1d] = build_1d_ops(p.Mx, hx);
    % 1D operators along x: Lx1d = 1D Laplacian, Gx1d = 1D gradient

    [Ly1d, Gy1d] = build_1d_ops(p.My, hy);
    % 1D operators along y

    Ix = speye(p.Mx);
    Iy = speye(p.My);
    % 2 Sparse identity matrices of size Mx × Mx and My × My respectively.

    Lap2D = kron(Iy, sparse(Lx1d)) + kron(sparse(Ly1d), Ix);
    % 2D Laplacian via Kronecker product: I_y ⊗ L_x + L_y ⊗ I_x

    Gx2D = kron(Iy, sparse(Gx1d));
    % 2D gradient in x-direction

    Gy2D = kron(sparse(Gy1d), Ix);
    % 2D gradient in y-direction

    %% INITIAL CONDITIONS

    C = p.C0 * 0.5 * (1 - tanh((X - p.a)/p.sigma_IC));
    % Initial endothelial cell density: smooth sigmoidal front near left.

    % Proteases, inhibitor, ECM: deterministic cosine perturbations
    P   = 0.1  + 0.01  * cos(2*pi*X) .* cos(2*pi*Y);
    % Protease IC: mean 0.1 + small harmonic perturbation.

    Inh = 0.1  + 0.005 * cos(4*pi*X) .* cos(4*pi*Y);
    % Inhibitor IC: mean + smooth perturbation.

    F   = 1.0  + 0.01  * cos(pi*X)   .* cos(pi*Y);
    % ECM IC: mean 1.0 with small cosine modulation.

    %% VECTORIZATION
    C = C(:); 
    P = P(:); 
    Inh = Inh(:); 
    F = F(:);
    % Convert fields from Mx x My matrices to column vectors of length M
    % for use with 2D matrix operators.

    T_v = T(:); 
    phi_x_v = phi_x(:); 
    phi_y_v = phi_y(:);
    % Vectorize TAF and auxiliary gradients as well.

    tau    = p.tau;    % time step
    Nsteps = p.Nsteps; % total number of time steps

    %% DIAGNOSTICS (masses, energy)
    diagnostics.t  = zeros(1, Nsteps+1);    % time vector
    diagnostics.mC = zeros(1, Nsteps+1);    % mass of C over time
    diagnostics.mF = zeros(1, Nsteps+1);    % mass of F over time
    diagnostics.En = zeros(1, Nsteps+1);    % discrete energy

    diagnostics.t(1)  = 0;                  % Start time.
    diagnostics.mC(1) = trap2d(C);          % Initial mass of C using trapezoidal quadrature.
    diagnostics.mF(1) = trap2d(F);          % Initial mass of F.

    Cx = Gx2D*C; 
    Cy = Gy2D*C;
    % Initial gradients of C in the two directions.

    diagnostics.En(1) = 0.5*(p.dC*(Cx'*Cx + Cy'*Cy) + F'*F)*hx*hy;
    % Initial discrete energy: gradient contribution of C plus quadratic F,
    % multiplied by element area hx*hy.

    % TIME LOOP — Strang splitting ]
    for n = 1:Nsteps
        % Main time loop: advance by one time step each iteration.

        % REACTION HALF-STEP
        [C, P, Inh, F] = reaction_step(C, P, Inh, F, tau/2);
        % First half-step for non-diffusive part: reaction + transport/rates.

        C = max(C,0); 
        P = max(P,0); 
        Inh = max(Inh,0); 
        F = max(F,0);
        % Enforce non-negativity to avoid non-physical negative values.

        % ADI diffusion step
        C   = adi_step(C,   p.Mx, p.My, hx, hy, p.dC, tau);
        % Diffusion of C solved via ADI.

        P   = adi_step(P,   p.Mx, p.My, hx, hy, p.dP, tau);
        % Diffusion of P solved via ADI.

        Inh = adi_step(Inh, p.Mx, p.My, hx, hy, p.dI, tau);
        % Diffusion of Inh solved via ADI.

        % F does not diffuse in the model and remains unchanged here.

        % REACTION HALF-STEP
        [C, P, Inh, F] = reaction_step(C, P, Inh, F, tau/2);
        % Second half-step of reaction/transport to complete Strang splitting.

        C = max(C,0); 
        P = max(P,0); 
        Inh = max(Inh,0); 
        F = max(F,0);
        % Enforce non-negativity after the second half-step.

        % Save diagnostics
        diagnostics.t(n+1)  = n*tau;          % Current time.
        diagnostics.mC(n+1) = trap2d(C);      % Total mass of C at the current time.
        diagnostics.mF(n+1) = trap2d(F);      % Total mass of F at the current time.

        Cx = Gx2D*C; 
        Cy = Gy2D*C;
        % Re-evaluate gradients of C for energy estimation.

        diagnostics.En(n+1) = 0.5*(p.dC*(Cx'*Cx + Cy'*Cy) + F'*F)*hx*hy;
        % Update discrete energy.
    end

    % Reshape for output as 2D fields
    C   = reshape(C,   p.Mx, p.My);     
    P   = reshape(P,   p.Mx, p.My);     
    Inh = reshape(Inh, p.Mx, p.My);     
    F   = reshape(F,   p.Mx, p.My);     

    diagnostics.grid.x = x; 
    diagnostics.grid.y = y;
    % Save 1D grid vectors in the diagnostics structure.

    diagnostics.grid.X = X; 
    diagnostics.grid.Y = Y;
    % Save also the 2D coordinate matrices.

    diagnostics.params = p;
    % Save grid and parameters in diagnostics.

    function [Cn, Pn, In, Fn] = reaction_step(Cv, Pv, Iv, Fv, dt)
        % Nested function performing an explicit reaction + transport step.
        %
        % Input:
        %   Cv, Pv, Iv, Fv = current state (vectorized)
        %   dt             = local time step
        %
        % Output:
        %   Cn, Pn, In, Fn = updated state after explicit step

        % Differential operators applied to the current state
        Lap_I = Lap2D * Iv;    % discrete Laplacian of inhibitor I
        Lap_F = Lap2D * Fv;    % discrete Laplacian of ECM F

        GxI = Gx2D * Iv; GyI = Gy2D * Iv;  % gradients of I
        GxF = Gx2D * Fv; GyF = Gy2D * Fv;  % gradients of F
        GxC = Gx2D * Cv; GyC = Gy2D * Cv;  % gradients of C

        vx = p.alpha2*GxI - p.alpha1*GxF - p.alpha3*phi_x_v;
        % x-component of the advective velocity field combining:
        % - chemotaxis to I
        % - haptotaxis to F
        % - chemotaxis to TAF via phi_x

        vy = p.alpha2*GyI - p.alpha1*GyF - p.alpha3*phi_y_v;
        % y-component of advective velocity

        div_v = p.alpha2*Lap_I - p.alpha1*Lap_F;
        % Simplified divergence of velocity using contributions from I and F.

        RC = vx.*GxC + vy.*GyC + div_v.*Cv + p.k1*Cv.*(1-Cv);
        % Source term for C: advective transport v·grad(C), compressible term
        % (div v) C and logistic growth k1*C*(1-C).

        RP = -p.k3*Pv.*Iv + p.k4*T_v.*Cv + p.k5*T_v - p.k6*Pv;
        % Reaction term for P: consumption by I, production by C and TAF,
        % and natural decay.

        RI = -p.k3*Pv.*Iv;
        % Reaction term for inhibitor I: consumption by proteases.

        RF = -p.k2*Pv.*Fv;
        % Reaction term for ECM F: degradation by proteases.

        % Forward Euler explicit update
        Cn = Cv + dt*RC;
        Pn = Pv + dt*RP;
        In = Iv + dt*RI;
        Fn = Fv + dt*RF;
    end

    % TRAPEZOIDAL 2D QUADRATURE
    function val = trap2d(u)
        % Nested function that approximates the integral of a 2D field
        % using the composite trapezoidal rule on the rectangular grid.

        U = reshape(u, p.Mx, p.My);
        W = ones(p.Mx, p.My);
        W(1,:) = 0.5; W(end,:) = 0.5; W(:,1) = 0.5; W(:,end) = 0.5;
        % Corner nodes effectively have weight 1/4.

        val = hx * hy * sum(sum(W .* U));
        % Weighted sum times element area.
    end

end



function u_new = adi_step(u, Mx, My, hx, hy, d, tau)
    % Perform a diffusion step using ADI (Alternating Direction Implicit).
    %
    % Input:
    %   u   = vectorized field to diffuse
    %   Mx, My = number of nodes in x and y
    %   hx, hy = grid spacings
    %   d   = diffusion coefficient
    %   tau = full time step
    %
    % Output:
    %   u_new = state after the diffusion step

    U = reshape(u, Mx, My);
    % Reshape field into 2D matrix.

    tau2 = tau / 2;
    % Half time step used in ADI coefficients.

    rx = d * tau2 / hx^2;   % r_x = dτ/(2h_x²)
    % Dimensionless diffusion ratio in x-direction.

    ry = d * tau2 / hy^2;   % r_y = dτ/(2h_y²)
    % Dimensionless diffusion ratio in y-direction.

    % FIRST HALF-STEP

    RHS = zeros(Mx, My);
    % Right-hand side for first half-step (explicit in y, implicit in x).

    for j = 1:My
        % Build RHS column-by-column.

        if j == 1
            % Lower boundary with homogeneous Neumann BC (ghost node u_{i,0}=u_{i,2}).

            RHS(:,j) = (1 - 2*ry)*U(:,j) + 2*ry*U(:,j+1);
            % Modified formula at the boundary.

        elseif j == My
            % Upper boundary with homogeneous Neumann BC.

            RHS(:,j) = 2*ry*U(:,j-1) + (1 - 2*ry)*U(:,j);
            % Modified formula at the boundary.

        else
            RHS(:,j) = ry*U(:,j-1) + (1 - 2*ry)*U(:,j) + ry*U(:,j+1);
            % Standard formula for internal nodes along y.
        end
    end

    % Tridiagonal system for implicit x-step
    ax = -rx * ones(Mx, 1);  
    ax(1)   = 0;
    % Subdiagonal of implicit x-system.

    bx = (1 + 2*rx) * ones(Mx, 1);
    % Main diagonal of implicit x-system.

    cx = -rx * ones(Mx, 1);  
    cx(end) = 0;
    % Superdiagonal of implicit x-system.

    cx(1)   = -2*rx;  
    % Left-boundary correction for Neumann BC.

    ax(end) = -2*rx;  
    % Right-boundary correction for Neumann BC.

    U_star = zeros(Mx, My);
    % Intermediate solution after first ADI half-step.

    for j = 1:My
        U_star(:,j) = thomas(ax, bx, cx, RHS(:,j));
        % Per ogni colonna si risolve un sistema tridiagonale indipendente
        % usando l'algoritmo di Thomas.
    end

    % SECOND HALF-STEP: implicit in y, explicit in x
    RHS2 = zeros(Mx, My);
    % Right-hand side for the second half-step.

    for i = 1:Mx
        % Build RHS row-by-row.

        if i == 1
            RHS2(i,:) = (1 - 2*rx)*U_star(i,:) + 2*rx*U_star(i+1,:);
            % Left boundary with homogeneous Neumann BC.

        elseif i == Mx
            RHS2(i,:) = 2*rx*U_star(i-1,:) + (1 - 2*rx)*U_star(i,:);
            % Right boundary with homogeneous Neumann BC.

        else
            RHS2(i,:) = rx*U_star(i-1,:) + (1 - 2*rx)*U_star(i,:) + rx*U_star(i+1,:);
            % Internal formula along x.
        end
    end

    % Tridiagonal system for implicit y-step
    ay = -ry * ones(My, 1);  
    ay(1)   = 0;
    % Subdiagonal of implicit y-system.

    by = (1 + 2*ry) * ones(My, 1);
    % Main diagonal of implicit y-system.

    cy = -ry * ones(My, 1);  
    cy(end) = 0;
    % Superdiagonal of implicit y-system.

    cy(1)   = -2*ry;
    % Lower-boundary correction.

    ay(end) = -2*ry;
    % Upper-boundary correction.

    U_new = zeros(Mx, My);
    % Final field after ADI step.

    for i = 1:Mx
        U_new(i,:) = thomas(ay, by, cy, RHS2(i,:)')';
        % Solve a tridiagonal system in y for each row.
        % Transpose because thomas expects column vectors.
    end

    u_new = U_new(:);
    % Return as vectorized field.
end



% THOMAS ALGORITHM
function x = thomas(a, b, c, d)
    % Solve tridiagonal system Ax = d with Thomas algorithm (O(n)).
    % a = subdiagonal, b = main diagonal, c = superdiagonal, d = RHS

    n = length(b);
    c_star = zeros(n, 1); 
    d_star = zeros(n, 1);
    
    % Forward sweep
    c_star(1) = c(1) / b(1);
    d_star(1) = d(1) / b(1);

    for i = 2:n
        denom = b(i) - a(i)*c_star(i-1);            %Pivot element after elimination of the subdiagonal term.

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
    % Build 1D discrete operators:
    % - L = Laplacian with homogeneous Neumann BCs
    % - G = central difference gradient

    % Laplacian
    L = gallery('tridiag', M, 1, -2, 1) / h^2;  % Standard second-order central difference for the Laplacian.
    L = full(L);                                % Convert to full matrix for easier manipulation.
    L(1, 2)       = 2/h^2;                      % left boundary correction (ghost node)
    L(end, end-1) = 2/h^2;                      % right boundary correction

    % Central gradient
    G = zeros(M);
    for i = 2:M-1
        G(i, i+1) =  1/(2*h);
        G(i, i-1) = -1/(2*h);
    end
    % Boundary rows remain zero consistent with zero Neumann gradient.
end