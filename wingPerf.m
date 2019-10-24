function [aoa, L, D, E, M] = wingPerf(wing, airfoil, vinf, rho, CLadjuster, aoaAdjuster)

try
    rawCL = airfoil.data(:,2);
    [~, minInd] = min(rawCL);
    [~, maxInd] = max(rawCL); 
    aoa = airfoil.data(minInd:maxInd,1) + aoaAdjuster(wing, airfoil, vinf, rho);
    cl = airfoil.data(minInd:maxInd,2);
    cd0 = airfoil.data(minInd:maxInd,3);
    cm = airfoil.data(minInd:maxInd, 5);
    CL = cl ./ (1 + wing.K*airfoil.a0) * CLadjuster(wing, airfoil, vinf, rho);
    
    q = .5*rho*vinf^2;
    L = q*CL*wing.S;
    CDi = wing.K*CL.^2;
    D = q*(CDi+cd0)*wing.S;
    M = q*wing.c*cm*wing.S;
    E = L./D;
    
catch ME
    ME = addCause(ME, MException('WingPerf:GenericError', 'GenericError for Wing: %s\nairfoil: %s\nvinf:%g\nrho:%g\nCLadjust:%g', matlab.unittest.diagnostics.ConstraintDiagnostic.getDisplayableString(wing), matlab.unittest.diagnostics.ConstraintDiagnostic.getDisplayableString(airfoil),vinf, rho, CLadjust));
    rethrow(ME)
end


end

