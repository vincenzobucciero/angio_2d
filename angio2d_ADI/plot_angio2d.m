function plot_angio2d(C, P, Inh, F, diagnostics, varargin)

    %%  OPZIONI per salbattaggio figure
    ip = inputParser;
    addParameter(ip, 'SaveFigs', false, @islogical);
    addParameter(ip, 'Format',   'png', @ischar);
    addParameter(ip, 'DPI',      300,   @isnumeric);
    addParameter(ip, 'OutDir',   './figures', @ischar);
    parse(ip, varargin{:});
    opts = ip.Results;

    if opts.SaveFigs && ~exist(opts.OutDir, 'dir')
        mkdir(opts.OutDir);
    end

    x = diagnostics.grid.x;
    y = diagnostics.grid.y;
    X = diagnostics.grid.X;
    Y = diagnostics.grid.Y;
    p = diagnostics.params;
    t = diagnostics.t;

    %  FIGURA 1 — Campi 2D al tempo finale  t = T_f
    fig1 = figure('Name', 'Campi 2D — t_f', ...
                  'Units', 'normalized', 'Position', [0.05 0.3 0.6 0.55]);

    fields  = {C, P, Inh, F};
    labels  = {'C  (densità EC)', 'P  (proteasi)', ...
               'Inh  (inibitore)', 'F  (ECM)'};
    cmaps   = {'parula', 'hot', 'cool', 'summer'};

    for k = 1:4
        subplot(2,2,k);
        pcolor(X, Y, fields{k});
        shading interp; axis equal tight;
        colormap(gca, cmaps{k}); colorbar;
        xlabel('x'); ylabel('y');
        title(sprintf('%s,  t = %.3f', labels{k}, t(end)), ...
              'Interpreter', 'none');
        set(gca, 'FontSize', 10);
    end

    sgtitle(sprintf('Angio2D — M_x=%d, M_y=%d, \\tau=%.2e', ...
            p.Mx, p.My, p.tau), 'FontSize', 13, 'FontWeight', 'bold');

    save_figure(fig1, 'campi_2d', opts);

    %  FIGURA 2 — Diagnostica temporale (masse, energia)
    fig2 = figure('Name', 'Diagnostica temporale', ...
                  'Units', 'normalized', 'Position', [0.35 0.3 0.5 0.5]);

    subplot(2,2,1);
    plot(t, diagnostics.mC, 'b-', 'LineWidth', 1.5);
    xlabel('t'); ylabel('\int C \, d\Omega');
    title('Massa cellule endoteliali');
    grid on; set(gca, 'FontSize', 10);

    subplot(2,2,2);
    plot(t, diagnostics.mF, 'r-', 'LineWidth', 1.5);
    xlabel('t'); ylabel('\int F \, d\Omega');
    title('Massa ECM');
    grid on; set(gca, 'FontSize', 10);

    subplot(2,2,3);
    plot(t, diagnostics.En, 'k-', 'LineWidth', 1.5);
    xlabel('t'); ylabel('E(t)');
    title('Energia discreta');
    grid on; set(gca, 'FontSize', 10);

    subplot(2,2,4);
    % Variazione relativa di massa C rispetto a t=0
    mC_rel = (diagnostics.mC - diagnostics.mC(1)) / max(abs(diagnostics.mC(1)), eps);
    mF_rel = (diagnostics.mF - diagnostics.mF(1)) / max(abs(diagnostics.mF(1)), eps);
    plot(t, mC_rel, 'b--', t, mF_rel, 'r--', 'LineWidth', 1.2);
    xlabel('t'); ylabel('\Delta m / m_0');
    title('Variazione relativa masse');
    legend('C', 'F', 'Location', 'best');
    grid on; set(gca, 'FontSize', 10);

    sgtitle('Diagnostica temporale', 'FontSize', 13, 'FontWeight', 'bold');

    save_figure(fig2, 'diagnostica', opts);

    %  FIGURA 3 — Sezioni 1D lungo la mezzeria y = Ly/2
    fig3 = figure('Name', 'Sezioni 1D', ...
                  'Units', 'normalized', 'Position', [0.15 0.2 0.45 0.45]);

    jmid = round(p.My / 2);  % indice della mezzeria

    subplot(2,1,1);
    plot(x, C(:, jmid), 'b-',  'LineWidth', 1.5, 'DisplayName', 'C'); hold on;
    plot(x, F(:, jmid), 'r--', 'LineWidth', 1.5, 'DisplayName', 'F');
    xlabel('x'); ylabel('ampiezza');
    title(sprintf('C  e  F  lungo y = %.2f', y(jmid)));
    legend('Location', 'best'); grid on;
    set(gca, 'FontSize', 10);

    subplot(2,1,2);
    plot(x, P(:, jmid),   'm-',  'LineWidth', 1.5, 'DisplayName', 'P'); hold on;
    plot(x, Inh(:, jmid), 'c--', 'LineWidth', 1.5, 'DisplayName', 'Inh');
    xlabel('x'); ylabel('ampiezza');
    title(sprintf('P  e  Inh  lungo y = %.2f', y(jmid)));
    legend('Location', 'best'); grid on;
    set(gca, 'FontSize', 10);

    sgtitle('Sezioni 1D — mezzeria', 'FontSize', 13, 'FontWeight', 'bold');

    save_figure(fig3, 'sezioni_1d', opts);

    %  FIGURA 4 — Campo TAF + gradiente (quiver)
    fig4 = figure('Name', 'Campo TAF', ...
                  'Units', 'normalized', 'Position', [0.25 0.15 0.4 0.45]);

    T_plot = exp(-p.epsilon^(-1) * ((X-p.Lx).^2 + (Y-p.Ly/2).^2));
    Tx_plot = -2*p.epsilon^(-1) * (X - p.Lx)    .* T_plot;
    Ty_plot = -2*p.epsilon^(-1) * (Y - p.Ly/2)  .* T_plot;

    pcolor(X, Y, T_plot); shading interp; axis equal tight;
    colormap(gca, 'jet'); colorbar; hold on;

    % Quiver su sotto-griglia 
    skip = max(1, round(p.Mx / 16));
    idx = 1:skip:p.Mx;
    idy = 1:skip:p.My;
    quiver(X(idx, idy), Y(idx, idy), ...
           Tx_plot(idx, idy), Ty_plot(idx, idy), ...
           0.8, 'w', 'LineWidth', 1.0);
    xlabel('x'); ylabel('y');
    title(sprintf('TAF  T(x,y)  e  \\nablaT,  \\epsilon = %.2f', p.epsilon));
    set(gca, 'FontSize', 11);

    save_figure(fig4, 'campo_TAF', opts);

    fprintf('\n  >> plot_angio2d: 4 figure generate.\n');
    if opts.SaveFigs
        fprintf('     Salvate in: %s  (formato %s, %d dpi)\n', ...
                opts.OutDir, opts.Format, opts.DPI);
    end
end


function save_figure(fig, name, opts)
    if ~opts.SaveFigs, return; end
    fname = fullfile(opts.OutDir, [name '.' opts.Format]);
    switch lower(opts.Format)
        case 'fig'
            savefig(fig, fname);
        case 'pdf'
            exportgraphics(fig, fname, 'ContentType', 'vector');
        case 'eps'
            exportgraphics(fig, fname, 'ContentType', 'vector');
        otherwise  % png, jpg, tiff ...
            exportgraphics(fig, fname, 'Resolution', opts.DPI);
    end
end