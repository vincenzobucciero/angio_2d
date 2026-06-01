function p = default_params()
    % Define a function with no input arguments.
    % Returns a struct 'p' containing physical, numerical,
    % and discretization parameters for the Angio2D model.

    p.Lx = 1; p.Ly = 1;
    % Spatial domain size [0,Lx] x [0,Ly] (default [0,1] x [0,1]).

    p.Mx = 64; p.My = 64;
    % Number of grid points in x and y directions:
    % - Mx points along x
    % - My points along y
    % A 64x64 grid is a reasonable default for moderate cost.

    p.Tf = 0.5;
    % Final simulation time. Solver advances from t = 0 to t = Tf.

    p.dC = 0.001; p.dP = 0.001; p.dI = 0.001;
    % Diffusion coefficients for the three diffusing variables:
    % - dC: diffusion for endothelial cells C
    % - dP: diffusion for proteases P
    % - dI: diffusion for inhibitor I
    % Small values correspond to slow diffusion.

    p.alpha1 = 0.4; p.alpha2 = 0.3; p.alpha3 = 0.5; p.alpha4 = 0.1;
    % Tactic sensitivity parameters:
    % - alpha1: haptotaxis (response to ECM F)
    % - alpha2: chemotaxis to inhibitor I
    % - alpha3: chemotaxis to TAF
    % - alpha4: saturation parameter for TAF contribution
    % These coefficients tune how strongly cells respond to gradients.

    p.k1 = 0.1; p.k2 = 0.3; p.k3 = 0.2;
    % Core kinetic constants:
    % - k1: logistic growth rate of endothelial cells
    % - k2: ECM degradation rate due to proteases
    % - k3: interaction rate between proteases and inhibitor

    p.k4 = 0.4; p.k5 = 0.1; p.k6 = 0.2;
    % Additional kinetic constants:
    % - k4: protease production induced by endothelial cells
    % - k5: protease production induced by TAF
    % - k6: natural protease decay

    p.epsilon = 1.0;
    % Parameter controlling the spatial width of the TAF profile.
    % T is typically a Gaussian centered near the right boundary;
    % epsilon sets its spread.

    p.C0 = 1.0; p.a = 0.1; p.sigma_IC = 0.02;
    % Initial condition parameters for cells:
    % - C0: initial peak cell density
    % - a: initial front location
    % - sigma_IC: front transition width
    % These are used to build a smooth tanh profile for the initial front.

    hx = p.Lx/(p.Mx-1);
    % Grid spacing in x: Lx/(Mx-1).

    v_max = max([p.alpha1,p.alpha2,p.alpha3])*2/hx;
    % Estimate of the maximum characteristic advective velocity.
    % Use the maximum of alpha1, alpha2, alpha3 and scale by 2/hx
    % as a discrete steep-gradient estimate. Used for time-step safety.

    tau_adv = hx/v_max;
    % Time-step limit associated with advective CFL constraint.
    % For stability, dt should scale with space/hx and inverse velocity.

    p.tau = 0.8*tau_adv;
    % Choose actual time step as 80% of the estimated limit for safety.

    p.Nsteps = ceil(p.Tf/p.tau);
    % Total number of time steps to cover [0, Tf]. 'ceil' ensures coverage.

    p.tau = p.Tf/p.Nsteps;
    % Final recalibration of tau so that Nsteps * tau == Tf exactly.
end