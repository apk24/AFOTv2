%% Simultaneous Wing and Horizontal Stabilizer Design
% This example will cover how to use AFOT to get good initital designs for
% a horizontal stabilizer and main wing. In this case, the craft is being
% designed for cruise conditions and is optimized for efficiency.
% Additionally, since the goal for this craft is to have a smaller tail,
% the moment from the main wing is going to be considered by the wing
% selector as well. 

%% Set up the environmental conditions
% 

[T, a, P, airDensity] = atmosisa(convlength(3000, 'ft', 'm'));

airDynVis = 1.778e-5; % Pa s

%% Set up the Design Parameters
% In this case, the main wing will either be NACA 4412 or CH 10. It will
% have a chord between 5 and 9 inches and aspan between 40 and 47 inches.
% It is important to note that this simulation will not account for a
% fuselage, nacelles, or any other similar bodies that might disrupt
% perfect flow over the wing. The target cruise velocity is 40 mph and the
% weight is 6 lbf. Note that all of these are converted to metric. AFOT is
% unit agnostic. However, it might be beneficial to use metric as the
% resultant units are much easier to understand. 
afNames = ["naca4412-il"];
crange = convlength(5:.1:9, 'in', 'm');
brange = convlength(40:.1:48, 'in', 'm');
cruiseVel = convvel(40, 'mph', 'm/s');
weight = convforce(7, 'lbf', 'N');


[results, figs] = runOptimize(afNames, crange, brange, cruiseVel, weight, airDensity, airDynVis, a, @aoaSelector, @wingSelector);

genPlots(figs, fullfile(".", "plots"));
disp(results)

function selIdx = aoaSelector(aoa, L, ~, ~, ~, weight, ~, ~)
    liftMask = (L >= 1.1* weight);
    [~, maxLidx] = max(L);
    aoaMask = (aoa < aoa(maxLidx)-5);
    
    netMask = aoaMask & liftMask;
    if(any(liftMask))
        selIdx = find(netMask, 1);
        return
    end
    selIdx = NaN;
end

function optIdx = wingSelector(C, B, AR, aoaGrid, Lgrid, Dgrid, Egrid, Mgrid)
deltaB = abs(B - convlength(48, 'in', 'm'));
deltaC = abs(C - convlength(8, 'in', 'm'));
deltaM = abs(Mgrid - 0);

rankB = (deltaB - min(deltaB(:)))/(max(deltaB(:))-min(deltaB(:)));
rankC = (deltaC - min(deltaC(:)))/(max(deltaC(:))-min(deltaC(:)));
rankAR = (AR - min(AR(:)))/(max(AR(:))-min(AR(:)));
rankE = (Egrid - min(Egrid(:)))/(max(Egrid(:))-min(Egrid(:)));
rankM = (deltaM - min(deltaM(:)))/(max(deltaM(:))-min(deltaM(:)));

ranks = rankB*0 + rankC*0 + rankAR*0 + rankM*-3 + rankE*10;

[~, optIdx] = max(ranks(:));

end


