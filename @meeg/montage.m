function [res] = montage(this,action,varargin)

% Method for specifying an online montage, or setting one to use
% FORMAT
%   res = montage(this, 'add', montage)
%           Adding a montage to the meeg object, see format here under
%
%   res = montage(this, 'action', idx)
%           Setting, checking, getting or removing a montage in the object,
%           depending on the action string and index idx of montage.
% Actions:
% - add        -> adding a montage to the object
% - switch     -> switch between montage, 0 being no applied montage 
%                 (switch to 0 by default if no index passed)
% - remove     -> removing montage, one at a time or any list.
% - getnumber  -> returning the number of montage(s) available
% - getindex   -> return current montage index
% - getname    -> returning a list of montage name (by default the current
%                 one if no list is passed)
% - getmontage -> returning the current or any other montage structure, 
%                 depending on list provided (current one by default if 
%                 no list passed).
% _______________________________________________________________________
% Copyright (C) 2011 Wellcome Trust Centre for Neuroimaging

% Remy Lehembre & Christophe Phillips
% Cyclotron Research Centre, University of Li�ge, Belgium
% $Id: $

% Montage definition in the object structure by simply adding a 'montage'
% field in the object structure:
% D.montage.M(1:k)
%          .Mind   - 0       => no montage applied
%                  \ 1...N   => use any of the N specified montage
% where M is a structure with
%  - name      [optional]
%  - tra       M*N montage matrix
%  - labelnew  M*1 cell array of labels
%  - labelorg  N*1 cell array of labels
%  - channels  [optional] same format as the main 'channels' field in the
%                           meeg object
%      * label
%      * bad
%      * type
%      * x_plot2D
%      * y_plot2D
%      * units

switch lower(action)
    
    case 'add'
        % adding a montage to the object
        % structure is passed, add montage
        mont = varargin{1};
        %check that all info are consistent
        if size(mont.tra,1)~=length(mont.labelnew) || ...
                size(mont.tra,2)~=length(mont.labelorg)
            error('Montage Matrix inconsistent with original or new number of electrodes')
        end
        if size(mont.labelorg,1)~=size(mont.tra,2)
            mont.labelorg = mont.labelorg';
        end
        if size(mont.labelnew,1)~=size(mont.tra,1)
            mont.labelnew = mont.labelnew';
        end
        
        % Check if there are already some montages, if not initialize
        % => set "ind" as the i^th montage
        this = struct(this);
        if ~isfield(this,'montage')
            this.montage = [];
            this.montage.M = [];
            ind = 1;
        else
            if isfield(this.montage,'M')
                ind = length(this.montage.M)+1;
            else
                this.montage = [];
                this.montage.M = [];
                ind = 1;
            end
        end
        
        % write montage info to fields M and Mind of montage
        if isfield(mont,'name') & ~isempty(mont.name)
            this.montage.M(ind).name = mont.name;
        else
            this.montage.M(ind).name = ['montage #',num2str(ind)];
        end
        this.montage.M(ind).tra = mont.tra;
        this.montage.M(ind).labelnew = mont.labelnew;
        this.montage.M(ind).labelorg = mont.labelorg;
        this.montage.Mind = ind;
        
        % fill channel information
        if isfield(mont,'channels')
            % use channel information provided
            % NO check performed here !!!
            this.montage.M(ind).channels = mont.channels;
        else
            % try to derive it from object channel info
            display('No new channels information : setting channels info automatically.')
            this = set_channels(this,mont);
        end
        res = meeg(this);
        
    case 'switch'
        % switching between different montages
        if nargin==2
            idx = 0; % by default, no montage applied.
        else
            idx = varargin{1};
        end
        if idx>numel(this.montage.M) || idx<0
            error('Specified montage index is erroneous.')
        else
            this.montage.Mind = idx;
        end
        res = meeg(this);
        
    case 'remove'
        % removing one or more montages
        if nargin==2
            idx = this.montage.Mind; % by default, removing current montage.
        else
            idx = varargin{1};
        end
        
        if idx>numel(this.montage.M) | idx<0
            error('Specified montage index is erroneous.')
        else
            this.montage.M(abs(idx)) = [];
            if any(idx==this.montage.Mind)
                % removing current montage -> no montage applied
                this.montage.Mind = 0;
            elseif any(idx < this.montage.Mind)
                % removing another montage, keep current (adjusted) index
                this.montage.Mind = this.montage.Mind - ...
                                            sum(idx < this.montage.Mind) ;
            end
        end
        res = meeg(this);
        
    case 'getnumber'
        % getting the total numbr of available montages
        res = numel(this.montage.M);
        
    case 'getindex'
        % getting the index of the current montage selected
        res = this.montage.Mind;
        
    case 'getname'
        % getting the name of current or any other montage(s)
        if nargin==2
            idx = this.montage.Mind; % by default, current montage.
        else
            idx = varargin{1};
        end
        if any(idx>numel(this.montage.M)) || any(idx<0)
            error('Specified montage index is erroneous.')
        elseif idx==0
            res = 'none';
        else
            res = char(this.montage.M(idx).name);
        end
        
    case 'getmontage'
        % getting the current montage structure or any other one
        if nargin==2
            idx = this.montage.Mind; % by default, current montage.
        else
            idx = varargin{1};
        end
        if idx>numel(this.montage.M) || idx<0
            error('Specified montage index is erroneous.')
        elseif idx==0
            res = [];
        else
            res = this.montage.M(idx);
        end
        
    otherwise
        % nothing planned for this case...
        error('Wrong use of the ''montage'' method.')
end

return

%% Subfunction(s)

function S = set_channels(S,mont)
% set channels "default" value, try to guess values from main channels
% definition in the object.

% Use new channel labels and set bad=0
idx = S.montage.Mind;
for ii=1:length(mont.labelnew)
    S.montage.M(idx).channels(ii).label = mont.labelnew{ii};
    S.montage.M(idx).channels(ii).bad = 0;
end

% Set new electrodes as bad if they include a bad channel
res = [S.channels.bad];
res = find(res);

newbads = find(any(mont.tra(:,res),2));
for ii=1:length(newbads)
    S.montage.M(idx).channels(ii).bad = 1;
end

% set channel info: type, units
l_EEG = [];
for ii=1:length(S.montage.M(idx).channels)
    l_chan_org = find(mont.tra(ii,:));
    % 'type'
    type_ii = unique({S.channels(l_chan_org).type});
    if numel(type_ii)==1
        S.montage.M(idx).channels(ii).type = type_ii{1};
    else
        % mixing different types of channels
        S.montage.M(idx).channels(ii).type = 'Other';
    end
    l_EEG = [l_EEG ii]; % list EEG channels
    
    % 'units'
    units_ii = unique({S.channels(l_chan_org).units});
    if numel(units_ii)==1
        S.montage.M(idx).channels(ii).units = units_ii{1};
    else
        % mixing different units of channels
        S.montage.M(idx).channels(ii).units = 'unknown';
    end
end

% Deal with "new" channel positions:
% For EEG channels: either channel selection, re-referencing or bipolar montages
%   - when channel selection -> keep original channel location
%   - when re-reference -> keep original channel location
%   - when bipolar montage -> use average channel location
% For MEG/MEGPLANAR/LFP, assume only subsample of channels -> keep original location
% For ECG/EOG/EMG, assume bipolar montage -> use loc of (+) electrode

if l_EEG
    tra_EEG = mont.tra(l_EEG,:);
    Nch_or = sum(~~tra_EEG,2); % #orig channels used for each new channel
    l_2ch = find(Nch_or==2); % lines with 2 channels involved
    [kk,ref_2ch] = find(tra_EEG(l_2ch,:)<1);
    if length(unique(ref_2ch))>1
        bipolarM = 1;
    else
        bipolarM = 0;
    end
end

for ii=1:length(S.montage.M(idx).channels)
    l_chan_org = find(mont.tra(ii,:));
    
    if intersect(ii,l_EEG)
        if bipolarM
            % bipolar -> use mean of electrode location
            if length(l_chan_org)>2, error('This shouldn''t happen.'), end
            S.montage.M(idx).channels(ii).X_plot2D = ...
                mean([S.channels(l_chan_org).X_plot2D]);
            S.montage.M(idx).channels(ii).Y_plot2D = ...
                mean([S.channels(l_chan_org).Y_plot2D]);
        else
            % re-ref -> keep coord from (+) channel
            S.montage.M(idx).channels(ii).X_plot2D = ...
                S.channels(mont.tra(ii,:)>0).X_plot2D;
            S.montage.M(idx).channels(ii).Y_plot2D = ...
                S.channels(mont.tra(ii,:)>0).Y_plot2D;
        end
    elseif sum(mont.tra(ii,:)>0)==1
        % 1 channel extracted or re-ref -> keep coord from (+) channel
        S.montage.M(idx).channels(ii).X_plot2D = ...
            S.channels(mont.tra(ii,:)>0).X_plot2D;
        S.montage.M(idx).channels(ii).Y_plot2D = ...
            S.channels(mont.tra(ii,:)>0).Y_plot2D;
    else % Don't know what to do...
        S.montage.M(idx).channels(ii).X_plot2D = Nan;
        S.montage.M(idx).channels(ii).Y_plot2D = Nan;
    end
end
