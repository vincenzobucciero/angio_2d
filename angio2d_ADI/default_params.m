function p = default_params()
    p.Lx = 1; p.Ly = 1;
    p.Mx = 64; p.My = 64;
    p.Tf = 0.5;
    p.dC = 0.001; p.dP = 0.001; p.dI = 0.001;
    p.alpha1 = 0.4; p.alpha2 = 0.3; p.alpha3 = 0.5; p.alpha4 = 0.1;
    p.k1 = 0.1; p.k2 = 0.3; p.k3 = 0.2;
    p.k4 = 0.4; p.k5 = 0.1; p.k6 = 0.2;
    p.epsilon = 1.0;
    p.C0 = 1.0; p.a = 0.1; p.sigma_IC = 0.02;

    hx = p.Lx/(p.Mx-1);
    v_max = max([p.alpha1,p.alpha2,p.alpha3])*2/hx;
    tau_adv = hx/v_max;
    p.tau = 0.8*tau_adv;
    p.Nsteps = ceil(p.Tf/p.tau);
    p.tau = p.Tf/p.Nsteps;
end