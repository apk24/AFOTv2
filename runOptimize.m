%% Generate Optimal Wings
% Based on pretty basic design parameters, decide on an airfoil, chord, and
% span that generate enough lift at a "reasonable" aoa. Overall, the method
% is to test a discrete set of points and rank each combination of airfoil,
% chord, and span. Present the best result of each airfoil to the user and
% return the best airfoil. 

function [results, figs] = runOptimize(afNames, crange, brange, cruiseVel, weight, airDensity, airDynVis, a, aoaSelector, wingSelector, varargin)

%% Input Validation
% Ensure all required inputs are provided and not too many are given.
narginchk(10, 12);

%% Set up Error Handling
% Declare a global variable |errors| that can keep track of all errors
% encountered. It is entirely possible that an error can be thrown during a
% run of one of the airfoils that is caused by the nature of that specific
% airfoil and simply indicates that the airfoil is unfit for use. In this
% case, it is tedious to exit the program completely. The error can be
% collected into |errors| and the loop can move on to the next airfoil.
% This is preferable to discarding the error as all the errors in |errors|
% can be presented at the end of execution allowing the user to determine
% whether a re-run or modification of inputs is required. If, for whatever
% reason, the error isn't displayed, the variable is global for better
% access from the command line.

global errors;
errors = [];

%%%
% A cleanup function is also needed to ensure that all the errors in
% |errors| are still displayed in the event of a failure outside of the
% try/catch block. The cleanup function also ensures that the parallel pool
% is shut down properly and any threads it started do not remain running.

cleanupObj = onCleanup(@()cleaner(errors));

%% Set up Calculation Variables
% Set up variables related to the processing and display of the data.

%%%
% Headings for the table of results
headings=["Chord"; "Span"; "AR"; "AoA"; "Lift"; "Drag"; "E"; "Moment"];

%%%
% Variable to store results of optimizations on individual airfoils
data = zeros(length(AF), length(headings));
figs = gobjects(length(AF));

%%%
% Variable for the parallel pool in use.
pool = gcp();

%% Run Optimizations
% Go through each airfoil in |afNames| and run |optimizeWing| on it.
for i = 1:length(afNames)
    
    %%%
    % Select airfoil. This isn't necessary in this manner, |afNames(i)| can be
    % used instead of |currAF| but this is negligibly slower and easier to
    % read.
    
    currAF = afNames(i);
    fprintf("Running %s\n", currAF);
    
    %%%
    % Run |optimizeWing| and store output into |data|. Encase actual run
    % in try block so problematic airfoils can be skipped.
    
    try
        [copt, bopt, ARopt, aoaOpt, Lopt, Dopt, Eopt, Mopt, fig] = optimizeWing(currAF, crange, brange, cruiseVel, weight, airDensity, airDynVis, a, aoaSelector, wingSelector, varargin{:});
        data(i, :) = [copt, bopt, ARopt, aoaOpt, Lopt, Dopt, Eopt, Mopt];
        figs(i) = fig;
    catch ME
        
        %%%
        % In the event of an exception, close the paralell pool so that any
        % locked or hung workers get killed. Log the error in |errors| and
        % start up the parpool again.
        
        poolsize = pool.NumWorkers;
        cluster = pool.Cluster;
        delete(pool);
        errors = [errors, ME]; %#ok<AGROW>
        pool = parpool(cluster, poolsize);
    end
        
    %%%
    % Present progress, as each run can take a significant amount of time
    % and users are impatient. Print the main plot from the output of
    % |biplaneOptimize| to an appropriately titled .png file in |./plots/|.
    % Close the figure to limit the number of open windows.
    
    fprintf("Data so far:\n");
    
    disp(array2table(round(data, 3, 'significant'), ...
        'RowNames', cellstr(afNames), 'VariableNames', cellstr(headings)))
end

%%%
% *Output*
snapnow; % Captures output when running as live script

%% Present Data
% Join airfoil names to the data and sort by airfoil name. Return the
% results table.

results = sortrows(array2table(round(data, 3, 'significant'),...
    'RowNames', cellstr(afNames), 'VariableNames', cellstr(headings)), 'RowNames');

end

%%% Cleanup Function
% In the event of any termination (expected or unexpected) certain clean up
% actions must happen, this function contains these requirements. Firstly
% it shuts down the parpool. In an expected termination, this cleans up the
% workspace. In an unexpected termination it ensures that locked/hung
% workers aren't consuming system resources. It then checks for any errors,
% and if they exist, adds them as causes to a generic |MException|. By
% throwing that exception, the user is presented with all the errors
% encoutnered during the optimization.

function cleaner(errors)
delete(gcp('nocreate'))
if(~isempty(errors))
    ME = MException('runOptimize:GenericError',...
        'Collection of errors at end of runOptimize');
    for subME = errors
        ME = addCause(ME, subME);
    end
    throw(ME)
end
end
    
