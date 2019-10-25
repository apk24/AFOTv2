
afNames = ["naca4412-il"; "ch10sm-il"];
crange = convlength(5:.1:9, 'in', 'm');
brange = convlength(40:.1:47, 'in', 'm');
cruiseVel = convvel(40, 'mph', 'm/s');
weight = convforce(6, 'lbf', 'N');

[T, a, P, airDensity] = atmosisa(convlength(3000, 'ft', 'm'));

airDynVis = 1.778e-5; % Pa s

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

function optIdx = wingSelector(C, B, ~, aoaGrid, Lgrid, ~, Egrid, Mgrid)
sortedB = sort(unique(B(~isnan(B))), 'descend');
sortedC = sort(unique(C(~isnan(C))), 'descend');
sortedE = sort(unique(Egrid(~isnan(Egrid))), 'ascend');
sortedM = sort(unique(abs(Mgrid(~isnan(Mgrid)))), 'descend');
% [~, maxLidx] = max(Lgrid(:));
% [~, minLidx] = min(Lgrid(:));
% aoaDiff = min([(aoaGrid(maxLidx) - aoaGrid), (aoaGrid - aoaGrid(minLidx))]);
% sortedAOA = sort(unique(aoaDiff(~isnan(aoaDiff))), 'ascend');
ranks = nan(size(B));
for idx = 1:length(B(:))
    if(~isnan(B(idx)))
        rankB = find(B(idx) == sortedB, 1)/(length(sortedB));
        rankC = find(C(idx) == sortedC, 1)/(length(sortedC));
        rankE = find(Egrid(idx) == sortedE, 1)/(length(sortedE));
        rankM = find(abs(Mgrid(idx)) == sortedM, 1)/(length(sortedM));
%         rankAOA = find(aoaDiff(idx) == sortedAOA, 1)/(length(sortedAOA));
        ranks(idx) = rankM+rankE;
    end
end
[~, optIdx] = max(ranks(:));
end

