classdef AirfoilDataT < handle
    %AirfoilDataT Holds Airfoil data for a particular mach and Re
    %   Constructor takes in name of airfoil .dat file (in ./airfoils/) and
    %   relevant performance data, passes it off to python script xfoil.py
    %   which calls up xfoil.exe and the cl,cd,etc. filter back into the
    %   data property in this object.
    
    properties (SetAccess = private, GetAccess = public)
        name
        data
        Re
        mach
        aMin
        aMax
        aStep
        alpha0
        a0
        linearLim
        rsq
        datFileName
    end
    properties (Constant)
        datFileDir = fullfile(".","afdata",filesep);
        afDir = fullfile(".","airfoils",filesep);
    end
    methods (Access=private, Hidden)
        function generateData(~, afFileName, Reynolds, machNumber, alphaStart, alphaEnd, alphaStep, datFileName)
            global debug
            if(isempty(debug) || ~debug)
                debug = 0;
            end
            cmdStr = sprintf("python xfoil.py %s %0.0f %f %f %f %f %s %d", afFileName, Reynolds, machNumber, alphaStart, alphaEnd, alphaStep, datFileName, debug);
            fprintf("start '%s'\n", cmdStr);
            command = char(cmdStr);
            if(debug)
                [status,results] = system(command, '-echo');
            else
                [status,results] = system(command);
            end
            fprintf("Generation Complete: %s\n", datFileName);
        end
        function data = readData(~,datFileName, alphaStart, alphaEnd, alphaStep)
            datFile = fopen(datFileName);
            data = sortrows(cell2mat(textscan(datFile, "%f %f %f %f %f %f %f", (alphaEnd - alphaStart)/alphaStep, 'HeaderLines', 12)));
            fclose(datFile);
        end
    end
    methods
        function obj = AirfoilDataT(airfoilName, Reynolds, machNumber, alphaStep)
            if(nargin < 1)
                return
            end
            assert(machNumber < 1, 'AirfoilData:Supersonic', 'You''re going supersonic');
            alphaStart = -20;
            alphaEnd = 20;
            Reynolds = round(Reynolds, 3, 'significant');
            obj.Re = Reynolds;
            obj.name = airfoilName;
            machNumber = round(machNumber, 3, 'significant');
            obj.mach = machNumber;
            obj.aStep = alphaStep;
            ensureFolder(obj.afDir);
            afFileName = obj.afDir + airfoilName + ".dat";
            ensureFolder(obj.datFileDir);
            obj.datFileName = obj.datFileDir + strrep(sprintf("%s_Re%0.4g_M%0.4g_AOA%g", upper(airfoilName), Reynolds, machNumber, alphaStep), ".", "d") + ".afdata";
            
            if(exist(obj.datFileName, 'File') ~= 2)
                
                if (exist(afFileName, 'File') ~= 2)
                    websave(afFileName, "http://airfoiltools.com/airfoil/seligdatfile", "airfoil", airfoilName);
                end
                assert(exist(afFileName, 'File') == 2, 'AirfoilData:AirfoilNotFound', 'Couldn''t find or open  airfoil named %s. Filename: %s', char(airfoilName), char(afFileName));
                
                obj.generateData(afFileName, Reynolds, machNumber, alphaStart, alphaEnd, alphaStep, obj.datFileName);
            end
            assert(exist(obj.datFileName, 'File') == 2, 'AirfoilData:DataFileNotFound', 'Couldn''t find or open  data file named: %s', char(obj.datFileName));
            tmpdata = obj.readData(obj.datFileName, alphaStart, alphaEnd, alphaStep);
            nudge = 1;
            while(size(tmpdata, 1) < (alphaEnd - alphaStart)/(alphaStep * 4) && nudge < 1.0005)
                fprintf("Nudging: %d, %s\n", nudge, obj.datFileName);
                obj.generateData(afFileName, Reynolds * nudge, machNumber * nudge, alphaStart, alphaEnd, alphaStep, obj.datFileName);
                assert(exist(obj.datFileName, 'File') == 2, 'AirfoilData:DataFileNotFound', 'Couldn''t find or open  data file named: %s', char(obj.datFileName));
                tmpdata = obj.readData(obj.datFileName, alphaStart, alphaEnd, alphaStep);
                nudge = nudge + .0001;
            end
            
            assert(~isempty(tmpdata), 'AirfoilData:DataFileEmpty', 'No data was found in data file: %s', obj.datFileName);
            assert(size(tmpdata, 1) > (alphaEnd - alphaStart)/(alphaStep * 4), 'AirfoilData:DataFileSmall', 'Not even a quarter of the expected data was found: %s', obj.datFileName);
            
            
            
            [~,uniqIndx] = unique(tmpdata(:,1));
            tmpdata = tmpdata(uniqIndx,:);
            obj.aMax = round(max(tmpdata(:,1))-alphaStep, ceil(-log10(alphaStep)));
            obj.aMin = round(min(tmpdata(:,1))+alphaStep, ceil(-log10(alphaStep)));
            
            obj.data(:,1) = [flip(0:-alphaStep:obj.aMin), alphaStep:alphaStep:obj.aMax];%linspace(obj.aMin, obj.aMax, ceil((obj.aMax - obj.aMin)/alphaStep));
            obj.data(:,2) = interp1(tmpdata(:,1),smooth(tmpdata(:,1), tmpdata(:,2), .05, 'rlowess'),obj.data(:,1));
            obj.data(:,3) = interp1(tmpdata(:,1),smooth(tmpdata(:,1), tmpdata(:,3), .05, 'rlowess'),obj.data(:,1));
            obj.data(:,5) = interp1(tmpdata(:,1),smooth(tmpdata(:,1), tmpdata(:,5), .05, 'rlowess'),obj.data(:,1));
            
            ind = find(obj.data(:,2)<=0,1, 'last') + 1;
            if(ind > 2)
                xpos = obj.data(ind, 1);
                ypos = obj.data(ind, 2);
                xneg = obj.data(ind-1, 1);
                yneg = obj.data(ind-1, 2);
                
                obj.alpha0 = -yneg/((ypos-yneg)/(xpos-xneg))+xneg;
            else
                obj.alpha0 = NaN;
            end
            [~, maxInd] = max(obj.data(:,2));
            [~, minInd] = min(obj.data(:,2));
            
            obj.rsq = 0;
            rsqTarget = .9999;
            while(obj.rsq < rsqTarget)
                maxInd = maxInd - 1;
                minInd = minInd + 1;
                if(obj.data(maxInd, 1) - obj.data(minInd,1) < 10)
                    [~, maxInd] = max(obj.data(:,2));
                    [~, minInd] = min(obj.data(:,2));
                    rsqTarget = 2*rsqTarget - 1;
                end
                x = [obj.data(minInd:maxInd, 1)];
                y = [obj.data(minInd:maxInd, 2)];
                if(~isnan(obj.alpha0))
                    x = [x; ones(ceil((maxInd-minInd)*.25),1)*obj.alpha0];
                    y = [y; zeros(ceil((maxInd-minInd)*.25),1)];
                end
                p = polyfit(x, y, 1);
                yfit = polyval(p, x);
                yresid = y - yfit;
                SSR = sum(yresid.^2);
                SST = (length(y)-1) * var(y);
                obj.rsq = 1-SSR/SST;
            end
            
            obj.a0 = p(1);
            obj.linearLim = [minInd, maxInd];
            if(isnan(obj.alpha0))
                %obj.alpha0 = -obj.data(minInd,2)/obj.a0+obj.data(minInd, 1);
                obj.alpha0 = -p(2)/p(1);
                
            end
        end
    end
    
    methods(Static)
        function obj = createApproximateFlatPlate()
            obj = AirfoilDataT();
            obj.name = 'Plate';
            obj.data(:,1) = -5:.01:5;
            obj.data(:,2) = convang(obj.data(:,1),'deg','rad')*2*pi;
            obj.data(:,3) = obj.data(:,2).*convang(obj.data(:,1),'deg','rad');
            obj.Re = 1;
            obj.mach = 0.001;
            obj.aMin = -5;
            obj.aMax = 5;
            obj.aStep = .1;
            obj.alpha0 = 0;
            obj.a0 = 2*pi^2/180;
            obj.linearLim = [-5,5];
            obj.rsq = 1;
            obj.datFileName = 'plate.dat';
        end
        function afName = createFlatePlate(thickness)
            t = thickness/2;
            afName = strrep(sprintf("plate%g", thickness), ".", "d");
            afFileName = AirfoilDataT.afDir + afName + ".dat";
            if(exist(afFileName, 'File') == 2)
                return;
            end
            afFile = fopen(afFileName, 'w');
            
            fprintf(afFile, "%s\n", afName);
            fprintf(afFile, "1 0\n");
            
            for i = linspace(.999,0.001, 25)
                fprintf(afFile, "%0.5f %0.5f\n", i, t);
            end
            fprintf(afFile, "0 0\n");
            for i = linspace(.001,0.999, 25)
                fprintf(afFile, "%0.5f %0.5f\n", i, -t);
            end
            fclose(afFile);
        end
    end
    
   methods
       function delete(obj)
           
       end
   end
end

