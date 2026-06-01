p = default_params();
[C, P, Inh, F, diagnostics] = angio2d_core(p);

% Export temporal diagnostics
T = table( ...
    diagnostics.t(:), ...
    diagnostics.mC(:), ...
    diagnostics.mF(:), ...
    diagnostics.En(:), ...
    'VariableNames', {'t','mC','mF','Energy'} ...
);
writetable(T, 'diagnostics_matlab.csv');

% Export final fields as column vectors (C-compatible)
writematrix(C(:),   'solution_matlab_C.csv');
writematrix(P(:),   'solution_matlab_P.csv');
writematrix(Inh(:), 'solution_matlab_Inh.csv');
writematrix(F(:),   'solution_matlab_F.csv');

disp('MATLAB export completed.');
