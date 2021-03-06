function stopCallback(model)

% This function to run after every simulation, it should get all the logged
% signals and save them to output\data.  Function assumes that
% multidimensional signals are column vectors.  This has not been tested on
% matrix-valued signals.


% Print name of m file
fprintf('\nRunning %s.m\n',mfilename)

% Navigate to output directory
workDir = fullfile(fileparts(which('BasicDotTracking.prj')),'output');

% Set directory to output folder
fprintf('\nSetting working directory to\n%s\n',workDir);
cd(workDir);

fprintf('\nCompiling tsc\n')

% Get the number of the model that is running
modelNum = regexp(model,'\d*','match');
modelNum = str2double(modelNum{1});

% Note that sdi = "simulation data inspector"
runIds = Simulink.sdi.getAllRunIDs(); % Get all run IDs from SDI
run = Simulink.sdi.getRun(runIds(end));

i = 1;
while ~contains(run.Name, model)
    run = Simulink.sdi.getRun(runIds(end - i));
    i = i + 1;
end
    
for signalIndex=1:run.SignalCount
    % Read all signals into a structure
    signalID = run.getSignalIDByIndex(signalIndex);
    signalObjs(signalIndex) = Simulink.sdi.getSignal(signalID);
end

% Create boolean list to track which ones have been processed or not
toDoList = true(size(signalObjs));


for jj = 1:10000 % Use a for loop with break condition instead of while loop
    
    % Get the first element of the to-do list that has not been done
    idx = find(toDoList,1);
    sz = 'scalar';
    if ~isempty(regexp(signalObjs(idx).Name,'\(\d*\)','ONCE'))
        sz = 'vector';
    end
    if ~isempty(regexp(signalObjs(idx).Name,'\(\d*,\d*\)','ONCE'))
        sz = 'matrix';
    end

    switch sz
        case 'scalar'
            name = matlab.lang.makeValidName(signalObjs(idx).Name);
            tsc.(name) = timeseries();
            tsc.(name).Time = signalObjs(jj).Values.Time;
%             tsc.(name).UserData.BlockPath = signalObjs(idx).BlockPath;
%             tsc.(name).UserData.PortIndex = signalObjs(idx).PortIndex;
            % Update the todo list
            toDoList(idx) = false;
        case 'vector'
            % Search for the (number) at the end of the signal name string
            startIndex = regexp(signalObjs(idx).Name,'\(\d*');
            % Signal name is everything before that
            origionalName = signalObjs(idx).Name(1:startIndex-1);
            cleanName = matlab.lang.makeValidName(origionalName);
            tsc.(cleanName) = timeseries();
%             tsc.(cleanName).Time
            % Find all signals with names that match that
            matchMask = regexp({signalObjs(:).Name},[origionalName '\(\d*\)']);
            matchMask = cellfun(@(x)~isempty(x),matchMask);
            matches   = signalObjs(matchMask);
            % Preallocate timeseries with correct dimensions
            tsc.(cleanName) = matches(1).Values;
            % Overwrite data with column vectors of nans
            tsc.(cleanName).Data = nan([matches(1).Dimensions 1 numel(tsc.(cleanName).Time)]);
            for ii = 1:numel(matches) % For each data set with a matching name
                % Get the index associated with it
                index = regexp(matches(ii).Name,'\(\d*\)','match');
                index = str2double(index{1}(2:end-1));
                % Take the data and stuff it into the appropriate plate in tsc
                tsc.(cleanName).Data(index,:,:) = matches(ii).Values.Data;
            end
            % Update the todo list
            tsc.(cleanName).UserData.BlockPath = signalObjs(idx).BlockPath;
            tsc.(cleanName).UserData.PortIndex = signalObjs(idx).PortIndex;
            toDoList(matchMask) = false;
        case 'matrix'
            % Search for the (number) at the end of the signal name string
            startIndex = regexp(signalObjs(idx).Name,'\(\d*,\d*\)');
            % Signal name is everything before that
            name = matlab.lang.makeValidName(signalObjs(idx).Name(1:startIndex-1));

            % Find all signals with names that match that
            matchMask = regexp({signalObjs(:).Name},[name '\(\d*,\d*\)']);
            matchMask = cellfun(@(x)~isempty(x),matchMask);
            matches   = signalObjs(matchMask);
            
            tsc.(name) = timeseries();
            tsc.(name).Time = matches(1).Values.Time;
            for ii = 1:numel(matches) % For each data set with a matching name
                % Get the index associated with it
                idx1 = regexp(matches(ii).Name,'\(\d*','match');
                idx2 = regexp(matches(ii).Name,',\d*\)','match');
                idx1 = regexp(idx1{1},'\d*','match');
                idx2 = regexp(idx2{1},'\d*','match');
                idx1 = str2double(idx1{1});
                idx2 = str2double(idx2{1});
                % Take the data and stuff it into the appropriate plate in tsc
                tsc.(name).Data(idx1,idx2,:) = matches(ii).Values.Data;
            end
            % Update the todo list
            toDoList(matchMask) = false;
           
    end
    
    if all(toDoList==0)
        break
    end
    
end

% Build filename for data set
fileName = ['data_' strrep(datestr(now),' ','_') ];
fileName = matlab.lang.makeValidName(fileName);
fileName = [fileName '.mat'];
filePath = fullfile(fileparts(which('BasicDotTracking.prj')),'output','data');

% Get params structure from base workspace so we can save it too
% params = evalin('base','params');
% Notify the user of what we're doing
fprintf('\nSaving tsc and params to\n%s\n',fullfile(filePath,fileName))
% Save the data to the output\data folder
save(fullfile(filePath,fileName),'tsc')
% Send tsc to the base workspace
assignin('base',sprintf('tsc%d',modelNum),tsc)

end