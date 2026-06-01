function plot_angio2d(C, P, Inh, F, diagnostics, varargin)
    % Plotting utility for final results of the 2D simulation.
    %
    % Input:
    %   C, P, Inh, F = final model fields (Mx x My)
    %   diagnostics  = struct with grid, parameters and diagnostics
    %   varargin     = optional name-value arguments
    %
    % Produces four main figures:
    %   1) 2D fields at final time
    %   2) temporal diagnostics
    %   3) 1D centerline sections
    %   4) TAF field with gradient quiver

        %% Options for saving figures
        ip = inputParser;
        % Create an inputParser object for optional name-value args.

    addParameter(ip, 'SaveFigs', false, @islogical);
    % Add optional 'SaveFigs' parameter (default false).
    % Third argument validates the input as logical.

    addParameter(ip, 'Format',   'png', @ischar);
    % Add optional 'Format' parameter.
    % Specifies figure export format, e.g. 'png','pdf','eps','fig'.

    addParameter(ip, 'DPI',      300,   @isnumeric);
    % Add optional 'DPI' parameter.
    % Sets export resolution for raster formats.

    addParameter(ip, 'OutDir',   './figures', @ischar);
    % Add optional 'OutDir' parameter.
    % Output directory for saved figures.

    parse(ip, varargin{:});
    % Parse the input arguments.

    opts = ip.Results;
    % Store the parsed results.

    if opts.SaveFigs && ~exist(opts.OutDir, 'dir')
        mkdir(opts.OutDir);
    end
    % Create output directory if saving is enabled and it does not exist.

    x = diagnostics.grid.x;
    % Extract x node vector from diagnostics.

    y = diagnostics.grid.y;
    % Extract y node vector from diagnostics.
        % Add optional 'SaveFigs' parameter (default false).
        % Third argument checks that the passed value is logical.

    X = diagnostics.grid.X;
    % Extract X node matrix from diagnostics.

    Y = diagnostics.grid.Y;
    % Extract Y node matrix from diagnostics.

    p = diagnostics.params;
    % Extract simulation parameters struct.

    t = diagnostics.t;
    % Extract time vector saved during the run.

    % FIGURE 1 — Final 2D fields
    fig1 = figure('Name', '2D Fields — t_f', ...
                  'Units', 'normalized', 'Position', [0.05 0.3 0.6 0.55]);
    % Create a new figure window.
    % - 'Name' names the figure 
    % - 'Units','normalized' uses normalized coordinates
    % - 'Position' controls size and location of the figure on the screen.

    fields  = {C, P, Inh, F};
    % Collect final fields in a cell array for looping.

    labels  = {'C  (endothelial cells)', 'P  (protease)', ...
               'Inh  (inhibitor)', 'F  (ECM)'};
    %  Labels for the four fields.

    cmaps   = {'parula', 'hot', 'cool', 'summer'};
    % Different colormaps to visually distinguish variables.

    for k = 1:4
        % Loop over the four fields to plot.

        subplot(2,2,k);
        % Divide the figure into a 2x2 grid and select panel k.

        pcolor(X, Y, fields{k});
        % Draw pseudocolor plot of the 2D field.
        % Each matrix value is mapped to a color.

        shading interp;
        % Interpolate colors between cells for smoother display.

        axis equal tight;
        % 'equal' enforces equal axis scaling; 'tight' fits limits to data.

        colormap(gca, cmaps{k});
        % Apply selected colormap to the current subplot.

        colorbar;
        % Add a colorbar showing the data scale.

        xlabel('x');
        % Label x-axis.

        ylabel('y');
        % Label y-axis.

        title(sprintf('%s,  t = %.3f', labels{k}, t(end)), ...
              'Interpreter', 'none');
        % Subplot title with variable name and final time.

        set(gca, 'FontSize', 10);
        % Set axis font size.
    end

    sgtitle(sprintf('Angio2D — M_x=%d, M_y=%d, \\tau=%.2e', ...
            p.Mx, p.My, p.tau), 'FontSize', 13, 'FontWeight', 'bold');
    % Overall figure title showing grid size and time step.

    save_figure(fig1, 'fields_2d', opts);
    % Add optional 'SaveFigs' parameter (default false).
        % Save figure if requested.

    % FIGURE 2 — Temporal diagnostics (masses, energy)
    fig2 = figure('Name', 'Temporal diagnostics', ...
                  'Units', 'normalized', 'Position', [0.35 0.3 0.5 0.5]);
    % Create figure for temporal evolution of global quantities.

    subplot(2,2,1);
    % First diagnostics panel.

    plot(t, diagnostics.mC, 'b-', 'LineWidth', 1.5);
    % Plot total mass of C over time (blue solid line).

    xlabel('t');
    % Label time axis.

    ylabel('\int C \, d\Omega');
    % Label vertical axis: spatial integral of C.

    title('Endothelial cell mass');
    % Panel title.

    grid on;
    % Enable grid on the plot.

    set(gca, 'FontSize', 10);
    % Set font size.

    subplot(2,2,2);
    % Second panel.

    plot(t, diagnostics.mF, 'r-', 'LineWidth', 1.5);
    % Plot total mass of F over time (red solid line).
    xlabel('t');
    ylabel('\int F \, d\Omega');
    title('ECM mass');
    grid on;
    set(gca, 'FontSize', 10);
    % Same settings as first panel.

    subplot(2,2,3);
    % Third panel.

    plot(t, diagnostics.En, 'k-', 'LineWidth', 1.5);
    % Plot discrete energy over time (black solid line).

    % Create a new figure window with normalized units and position.
    xlabel('t');
    ylabel('E(t)');
    title('Discrete energy');
    grid on;
    set(gca, 'FontSize', 10);

    subplot(2,2,4);
    % Fourth panel: relative mass variations.

    % Compute relative mass variations for C and F w.r.t initial values.

    mC_rel = (diagnostics.mC - diagnostics.mC(1)) / max(abs(diagnostics.mC(1)), eps);
    % Compute relative change of C mass w.r.t initial value.
    % Use eps to avoid division by zero if initial mass is (near) zero.

    mF_rel = (diagnostics.mF - diagnostics.mF(1)) / max(abs(diagnostics.mF(1)), eps);
    % Same computation for F mass.

    plot(t, mC_rel, 'b--', t, mF_rel, 'r--', 'LineWidth', 1.2);
    % Plot both relative variations in the same panel:
    % - blue dashed for C
    % - red dashed for F

    xlabel('t');
    ylabel('\Delta m / m_0');
    title('Relative mass variation');

    legend('C', 'F', 'Location', 'best');
    grid on;
    set(gca, 'FontSize', 10);

    sgtitle('Temporal diagnostics', 'FontSize', 13, 'FontWeight', 'bold');
    save_figure(fig2, 'diagnostics', opts);
    % Save figure if requested.

    % FIGURE 3 — 1D sections along centerline y = Ly/2
    fig3 = figure('Name', '1D Sections', ...
                  'Units', 'normalized', 'Position', [0.15 0.2 0.45 0.45]);
    % Create figure for 1D sections.

    jmid = round(p.My / 2);  % index of the centerline

    subplot(2,1,1);
    % First panel of the sections figure.

    plot(x, C(:, jmid), 'b-',  'LineWidth', 1.5, 'DisplayName', 'C'); hold on;
    % Plot C section along horizontal line y = y(jmid).

    plot(x, F(:, jmid), 'r--', 'LineWidth', 1.5, 'DisplayName', 'F');
    % Also plot F section on the same axes.

    xlabel('x');
    ylabel('amplitude');
    title(sprintf('C and F along y = %.2f', y(jmid)));

    legend('Location', 'best');
    % Add legend.

    grid on;
    set(gca, 'FontSize', 10);

    subplot(2,1,2);
    % Second panel.

    plot(x, P(:, jmid),   'm-',  'LineWidth', 1.5, 'DisplayName', 'P'); hold on;
    % Plot P section at the same y.

    plot(x, Inh(:, jmid), 'c--', 'LineWidth', 1.5, 'DisplayName', 'Inh');
    % Plot Inh section.

    xlabel('x');
    ylabel('amplitude');
    title(sprintf('P and Inh along y = %.2f', y(jmid)));
    legend('Location', 'best');
    grid on;
    set(gca, 'FontSize', 10);

    sgtitle('1D Sections — centerline', 'FontSize', 13, 'FontWeight', 'bold');
    save_figure(fig3, 'sections_1d', opts);
    % Save figure if requested.

    % FIGURE 4 — TAF field + gradient (quiver)
    fig4 = figure('Name', 'TAF field', ...
                  'Units', 'normalized', 'Position', [0.25 0.15 0.4 0.45]);
    % Create figure dedicated to the TAF field and its gradient.

    T_plot = exp(-p.epsilon^(-1) * ((X-p.Lx).^2 + (Y-p.Ly/2).^2));
    % Reconstruct the TAF field using the analytic formula.

    Tx_plot = -2*p.epsilon^(-1) * (X - p.Lx)    .* T_plot;
    % TAF derivative w.r.t. x.

    Ty_plot = -2*p.epsilon^(-1) * (Y - p.Ly/2)  .* T_plot;
    % TAF derivative w.r.t. y.

    pcolor(X, Y, T_plot);
    % Draw 2D map of the TAF field.

    shading interp;
    axis equal tight;
    % Improve rendering and keep aspect ratio.

    colormap(gca, 'jet');
    % Apply 'jet' colormap to the plot.

    colorbar;
    % Show the colorbar.

    hold on;
    % Keep plot active to overlay gradient arrows.

    % Quiver on a subsampled grid
    skip = max(1, round(p.Mx / 16));

    idx = 1:skip:p.Mx;
    % Selected indices along x.

    idy = 1:skip:p.My;
    % Selected indices along y.

    quiver(X(idx, idy), Y(idx, idy), ...
           Tx_plot(idx, idy), Ty_plot(idx, idy), ...
           0.8, 'w', 'LineWidth', 1.0);
    % Draw the TAF gradient vector field on selected nodes.
    % - 0.8 scale factor, white arrows, linewidth controls thickness.

    xlabel('x');
    ylabel('y');

    title(sprintf('TAF  T(x,y)  e  \\nablaT,  \\epsilon = %.2f', p.epsilon));
    % Title indicating epsilon parameter.

    set(gca, 'FontSize', 11);
    % Dimensione del font dell'asse.

    save_figure(fig4, 'taf_field', opts);
    % Save fourth figure if requested.

    fprintf('\n  >> plot_angio2d: 4 figures generated.\n');
    % Informational message in Command Window.

    if opts.SaveFigs
        fprintf('     Saved in: %s  (format %s, %d dpi)\n', ...
                opts.OutDir, opts.Format, opts.DPI);
    end
    % If saving is active, print destination, format and DPI.
end


function save_figure(fig, name, opts)
    % Helper to save figures according to provided options.
    %
    % Input:
    %   fig  = figure handle to save
    %   name = base filename
    %   opts = export options struct

    if ~opts.SaveFigs, return; end
    % Return immediately if saving is disabled.

    fname = fullfile(opts.OutDir, [name '.' opts.Format]);
    % Build full path: output dir + base name + extension.

    switch lower(opts.Format)
        % Choose export method based on requested format.

        case 'fig'
            savefig(fig, fname);
            % Save native MATLAB .fig for later editing.

        case 'pdf'
            exportgraphics(fig, fname, 'ContentType', 'vector');
            % Export vector PDF (good for publications).

        case 'eps'
            exportgraphics(fig, fname, 'ContentType', 'vector');
            % Export vector EPS.

        otherwise  % png, jpg, tiff ...
            exportgraphics(fig, fname, 'Resolution', opts.DPI);
            % Export raster formats at requested resolution.
    end
end