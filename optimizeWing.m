%% Find the Ideal Wing
% Find the optimal wing given a range of chords and spans, cruise velocity,
% weight, air conditions, and appropriate optimization/selection functions.
% Optionally can include adjuster functions for angle of attack (additive)
% or CL (multiplicative). This function tests a discrete but large number
% of span and chord combinations. At each combination, it presents the
% performance data at the optimum angle of attack, as determined by the
% angle of attack selector function. Finally, it returns the best overall
% wing based on the wing selector function. It also generates contour maps
% of all the span chord combinations. These graphs, along with running this
% function for multiple selectors can be used to design for different
% phases of flight, such as cruise, climb, and landing. 

function [copt, bopt, ARopt, aoaOpt, Lopt, Dopt, Eopt, Mopt, fig] = optimizeWing(afName, crange, brange, cruiseVel, weight, airDensity, airDynVis, a, aoaSelector, wingSelector, varargin)
%OPTIMIZEWING Find the optimal wing given a range of chords and spans,
% cruise velocity, weight, air conditions, and appropriate optimization/selection functions.
% Optionally can include adjuster functions for angle of attack (additive)
% or CL (multiplicative).
% 
%   [copt, bopt, ARopt, alphaOpt, Tmin, Lopt, Dopt, Eopt, figs] =
%   OPTIMIZEWING(afName, crange, brange, cruiseVel, weight, airDensity,
%   airDynVis, a, aoaSelector, wingSelector) Find the optimal wing given
%   basic inputs.
% 
%   [copt, bopt, ARopt, alphaOpt, Tmin, Lopt, Dopt, Eopt, figs] =
%   OPTIMIZEWING(afName, crange, brange, cruiseVel, weight, airDensity,
%   airDynVis, a, aoaSelector, wingSelector, aoaAdjuster) Find the optimal wing given
%   basic inputs and an angle of attack adjuster.
% 
%   [copt, bopt, ARopt, alphaOpt, Tmin, Lopt, Dopt, Eopt, figs] =
%   OPTIMIZEWING(afName, crange, brange, cruiseVel, weight, airDensity,
%   airDynVis, a, aoaSelector, wingSelector, aoaAdjuster, CLadjuster) Find the optimal wing given
%   basic inputs, an angle of attack adjuster, and a C_L adjuster.
% 
% (c) Apoorva Kharche, 2019
% See also RUNOPTIMIZE, WINGPERF, CREATEAIRFOIL.

%% Input Validation
% Ensure all required inputs are provided. Parse optional inputs.
narginchk(10, 12);

%%%
% If not provided, the output of |alphaAdjuster| should always be 0 and
% |CLadjuster| should be always be 1.
aoaAdjuster = @(varargin)0;
CLadjuster = @(varargin)1;

%%%
% If they are provided, set |alphaAdjuster| and |CLadjuster|.
switch nargin
    case 11
        aoaAdjuster = varargin{1};
    case 12
        aoaAdjuster = varargin{1};
        CLadjuster = varargin{2};
end

%% Variable Initialization
% Create grids for each aspect of wing specification and performance. 

[C, B] = meshgrid(crange, brange);

AR = B ./ C;

Lgrid = nan(size(C));
Dgrid = Lgrid;
aoaGrid = Lgrid;
Egrid = Lgrid;
Mgrid = Lgrid;

%%%
% Variable for the parallel pool in use.
pool = gcp();

%%%
% Include a mask to disqualify unneccessary calculations
masterMask = isnan(C);

%% Set up Airfoils
% Find what the required Reynolds numbers are for the analysis and create
% AirfoilDataT objects that have all the relevant information for each
% Reynolds number. 

%%%
% Reynolds numbers are rounded to three significant figures to prevent too
% many XFOIL runs. It also makes naming of the resulting data files easier.
% Then, only the unique Reynolds numbers are kept. 
RE = Reynolds(cruiseVel, C, airDensity, airDynVis, 3);
uniqRe = unique(RE(~isnan(RE)));


%%%
% Preallocate for the Airfoil objects and the references for the parallel
% threads.
airfoils(length(uniqRe)) = AirfoilDataT();
futures(length(uniqRe)) = parallel.FevalFuture();

%%%
% Queue up the AirfoilDataT to be created for each Reynolds number on the
% parallel pool. Currently using .1 degree increments for the airfoil data.
for idx = 1:length(uniqRe)
    fprintf("Queueing %s at Re%g, M%g\n", afName, uniqRe(idx), cruiseVel/a);
    futures(idx) = parfeval(pool, @createAirfoil, afName, uniqRe(idx), cruiseVel/a, .1);
end

%%%
% Collect the results as they come in.
for idx = 1:length(futures)
    [completedIdx, value] = fetchNext(futures);
    airfoils(completedIdx) = value;
    fprintf("Completed %s at Re%g, M%g\t%d of %d\n", value.name, value.Re, value.mach, idx, length(futures));
end

%%%
% Then, each point in the C grid is mapped to the appropriate airfoil in
% |airfoils|. This step will help with slicing the array for parallel
% processing. Since |AirfoilDataT| is a handle object, there will be very
% little extra memory spent due to this action.

afGrid = nan(size(RE));

for idx = 1:length(afGrid(:))
    afGrid(idx) = airfoils(find(uniqRe == RE(idx), 1));
end

%% Calculate Performance on each Wing
% Calculate the performance data of each wing possible. Since it is not
% practical to store performance for all angles of attack for each wing,
% |aoaSelector| is applied to select the optimum performance for that wing
% configuration.

parfor idx = 1:length(C(:))
    if(~masterMask(idx)) % Don't calculate points hidden by masterMask
        wing = WingT(C(idx), B(idx));
        currAf = afGrid(idx);
        [aoa, L, D, E, M] = wingPerf(wing, currAf, cruiseVel, airDensity, CLadjuster, aoaAdjuster);
        selIdx = feval(aoaSelector, aoa, L, D, E, M, weight, wing, currAf);
        Lgrid(idx) = L(selIdx);
        Dgrid(idx) = D(selIdx);
        Egrid(idx) = E(selIdx);
        Mgrid(idx) = M(selIdx);
        aoaGrid(idx) = aoa(selIdx);
    end
end

%%%
% Filter out all the invalid results. If any one aspect of a point is non-finite, then
% that point should be removed from all grids.

resultsMask = ~( isfinite(C) & isfinite(B) & isfinite(AR) & isfinite(aoaGrid) & isfinite(Lgrid) & isfinite(Dgrid) & isfinite(Egrid) & isfinite(Mgrid) );

C(resultsMask) = NaN;
B(resultsMask) = NaN;
AR(resultsMask) = NaN;
aoaGrid(resultsMask) = NaN;
Lgrid(resultsMask) = NaN;
Dgrid(resultsMask) = NaN;
Egrid(resultsMask) = NaN;
Mgrid(resultsMask) = NaN;

%% Select the Best Wing
% Apply |wingSelector| and find the best wing. 

optIdx = wingSelector(C, B, AR, aoaGrid, Lgrid, Dgrid, Egrid, Mgrid);

copt = C(optIdx);
bopt = B(optIdx);
ARopt = AR(optIdx);
aoaOpt = aoaGrid(optIdx);
Lopt = Lgrid(optIdx);
Dopt = Dgrid(optIdx);
Eopt = Egrid(optIdx);
Mopt = Mgrid(optIdx);

%% Generate Graphs
%

%%%
% Set up for figures. Include the |suplabel| package for full figure titles
% and labels. Set shading mode to interpolated to improve look of contour
% graphs. Find x and y limits. Create figure, then add a name and set the size.

shading interp
addpath(fullfile(".", "suplabel"))
xl = [min(C(:)), max(C(:))];
yl = [min(B(:)), max(B(:))];
fig = figure;
fig.Name = ['Contour plots for ', char(afName)];
fig.Units = 'inches';
fig.Position = [0, 0, 10, 10];

%%%
% 
ax(1) = subplot(2,2,1);
[~, c] = contourf(crange, brange, Lgrid, 1000);
c.LineColor = 'none';
title('Lift');
xlim(xl);
ylim(yl);
colorbar
hold on
plot(copt, bopt, 'bx');
contour(crange, brange, Lgrid, 'LineColor', 'black', 'LineStyle', '-.', 'LevelStep', 1);
hold off

ax(2) = subplot(4,4,3);
[~, c] = contourf(crange, brange, Dgrid, 1000);
c.LineColor = 'none';
title('Drag');
xlim(xl);
ylim(yl);
colorbar
hold on
plot(copt, bopt, 'bx');
contour(crange, brange, Dgrid, 'LineColor', 'black', 'LineStyle', '-.', 'LevelStep', 1);
hold off

ax(3) = subplot(4,4,8);
[~, c] = contourf(crange, brange, Egrid, 1000);
c.LineColor = 'none';
title('L/D');
xlim(xl);
ylim(yl);
colorbar
hold on
plot(copt, bopt, 'bx');
contour(crange, brange, Egrid, 'LineColor', 'black', 'LineStyle', '-.', 'LevelStep', 1);
hold off

ax(4) = subplot(2,2,3);
[~, c] = contourf(crange, brange, Mgrid, 1000);
c.LineColor = 'none';
title('Moment');
xlim(xl);
ylim(yl);
colorbar
hold on
plot(copt, bopt, 'bx');
contour(crange, brange, Mgrid, 'LineColor', 'black', 'LineStyle', '-.', 'LevelStep', 1);
hold off

ax(5) = subplot(2,2,4);
[~, c] = contourf(crange, brange, aoaGrid, 1000);
c.LineColor = 'none';
title('\alpha');
xlim(xl);
ylim(yl);
colorbar
hold on
plot(copt, bopt, 'bx');
contour(crange, brange, aoaGrid, 'LineColor', 'black', 'LineStyle', '-.', 'LevelStep', 1);
hold off

suplabel(char(sprintf("Airfoil: '%s'", afName)), 't');
suplabel('Chord', 'x');
suplabel('Span', 'y');

end