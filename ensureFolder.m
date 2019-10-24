function [folderpath] = ensureFolder(varargin)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here
folderpath = fullfile(varargin{:});
[status, msg, msgID] = mkdir(folderpath);
assert(status, ['ensureFolder:',msgID], msg );
    

end

