function airfoil = createAirfoil(airfoilName, Reynolds, machNumber, alphaStep, debug)
pause(rand(1));
fprintf("Creating %s at Re%d, M%d\n", airfoilName, Reynolds, machNumber);
try
airfoil = AirfoilDataT(airfoilName, Reynolds, machNumber, alphaStep, debug);
catch ME1
    try
    delete(char(AirfoilDataT.datFileDir + strrep(sprintf("%s_Re%0.4g_M%0.4g_AOA%g", upper(airfoilName), Reynolds, machNumber, alphaStep), ".", "d") + '.afdata'))
    pause(rand(1));
    airfoil = AirfoilDataT(airfoilName, Reynolds + 1, machNumber + .00001, alphaStep, debug);
    catch ME2
        addCause(ME2, ME1);
        rethrow(ME2);
    end
end
pause(rand(1));
end