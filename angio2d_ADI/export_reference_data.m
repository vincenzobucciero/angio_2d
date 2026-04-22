p = default_params();
[C, P, Inh, F, diagnostics] = angio2d_core(p);

% Export diagnostica temporale
T = table( ...
    diagnostics.t(:), ...
    diagnostics.mC(:), ...
    diagnostics.mF(:), ...
    diagnostics.En(:), ...
    'VariableNames', {'t','mC','mF','Energy'} ...
);
writetable(T, 'diagnostics_matlab.csv');

% Export campi finali in formato vettoriale compatibile col C
writematrix(C(:),   'solution_matlab_C.csv');
writematrix(P(:),   'solution_matlab_P.csv');
writematrix(Inh(:), 'solution_matlab_Inh.csv');
writematrix(F(:),   'solution_matlab_F.csv');

disp('Export MATLAB completato.');
