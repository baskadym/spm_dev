function varargout = unparcellate(data, parcellation, parameter, parcelparam, varargin)

% UNPARCELLATE performs the reverse of a parcellation, by assigigning each
% parcel's activation to the vertices that contributed to that parcel.
%
% Use as
%
%   fun = unparcellate(data, parcellation, parameter, parcelparam, varargin)
%
% Required inputs:
%
%   data          = structure (or matrix) containing the parcellated functional data
%   parcellation  = structure describing the parcellation, i.e. the parcel
%                   membership for each of the vertices
%   parameter     = string (or cell-array with labels) that specifies the
%                   parameter to be used (if data is a structure) or how to
%                   interpret the rows in the data matrix (if data is a matrix)
%
% Additional inputs are key-value pairs and pertain to bivariate data with
% a 'labelcmb' specified in the input argument 'parameter'.
%
%   avgoverref     = 'yes' (or 'no')
%   directionality = 'both' (or 'inflow'/'outflow')
%
% Outputs:
%   fun = matrix Nvertices x size(data.(parameter),2) (or Nvertices x
%           size(data,2), containing the unparcellated data
%
%   If the input was bivariate data with a labelcmb, an optional second
%   output argument gives a list of the reference parcels.

% Undocumented input key-value pair:
%   output = 'data' (default), or 'projection matrix', only works without 'labelcmb' in input 

output = ft_getopt(varargin, 'output', 'data');

if isstruct(data)
  data_parcellated = getsubfield(data, parameter);
elseif size(parameter,2)==1
  data_parcellated = data;
  clear data;
  data.label = parameter;
  data = setsubfield(data, parameter, data_parcellated);
elseif size(parameter,2)==2
  % this contains labelcmb e.g. pairwise granger
  data_parcellated = data;
  clear data;
  data.labelcmb = parameter;
  data          = setsubfield(data, parameter, data_parcellated);
end

if ft_datatype(parcellation, 'volume')
  nelements  = prod(parcellation.dim(1:3));
elseif ft_datatype(parcellation, 'source')
  nelements  = size(parcellation.pos,1);
end

if isfield(data, 'label')
  % the data is chan_xxx or chan_chan_xxx
  
  switch output
    case 'data'
      dimord = getdimord(data, parameter);
      dimtok = tokenize(dimord, '_');
      dimsiz = getdimsiz(data, parameter);
      % replace the number of parcels by the number of vertices in a parcel
      dimsiz(strcmp(dimtok, 'chan')) = nelements;
      
      fun = nan(dimsiz);
      
      parcel.label  = parcellation.([parcelparam,'label']);
      parcel.lation = parcellation.(parcelparam);

      [parcelindx, chanindx] = match_str(parcel.label, data.label);
        
      if numel(dimtok)>1 && strcmp(dimtok{1}, 'chan') && strcmp(dimtok{2}, 'chan')
        % chan_chan_xxx
        for i=1:numel(parcelindx)
          for j=1:numel(parcelindx)
            p1 = parcel.lation==parcelindx(i);
            p2 = parcel.lation==parcelindx(j);
            c1 = chanindx(i);
            c2 = chanindx(j);
            fun(p1,p2,:) = repmat(data_parcellated(c1,c2,:), [sum(p1) sum(p2) 1]);
          end
        end
      elseif strcmp(dimtok{1}, 'chan')
        % FIXME the below should ideally also be done for the bivariate
        % case above, but needs to be thought through
        if ~isequal(parcelindx(:), (1:numel(parcelindx))')
          % for some parcels there is no corresponding data
          ft_warning('for some parcels there is no corresponding data, these will be filled with NaNs');
        end
        if ~isequal(sort(chanindx(:)), (1:numel(chanindx))')
          ft_warning('for some of the data labels there is no corresponding parcel, these will be skipped');
        end
      
        tmp = data_parcellated;
        siz = size(tmp);
        data_parcellated = nan([numel(parcel.label), siz(2:end)]);
        
        % reorder the parcellated data according to the order in the parcellation
        data_parcellated(parcelindx, :) = tmp(chanindx, :); 
        
        fun(parcel.lation>0,:) = data_parcellated(parcel.lation(parcel.lation>0),:);
        
      end
      varargout{1} = fun;
      
    case 'projection matrix'

      parcel.label  = parcellation.([parcelparam,'label']);
      parcel.lation = parcellation.(parcelparam);

      [parcelindx, chanindx] = match_str(parcel.label, data.label);
      ix = zeros(0,1);
      iy = zeros(0,1);
      for i=1:numel(parcelindx)
        ix = cat(1,ix,find(parcel.lation==parcelindx(i)));
        iy = cat(1,iy,ones(sum(parcel.lation==parcelindx(i)),1).*chanindx(i));
      end
      fun = sparse(ix,iy,ones(numel(ix),1));
      
      varargout{1} = fun;
      varargout{2} = data.label(chanindx);
      
    otherwise
  end
  
elseif isfield(data, 'labelcmb')
  % bivariate data
  
  avgoverref     = istrue(ft_getopt(varargin, 'avgoverref', 1));
  directionality = ft_getopt(varargin, 'directionality', 'both');
  
  labelcmb = data.labelcmb;
  
  % remove the square brackets, if present
  for k = 1:numel(labelcmb)
    tok = tokenize(labelcmb{k}, '[');
    labelcmb{k} = tok{1};
  end
  
  % identify which parcel(s) was/were used as seed parcel
  uniq_label = unique(labelcmb(:));
  uniq_count = zeros(size(uniq_label));
  for k = 1:numel(uniq_label)
    uniq_count(k) = sum(strcmp(labelcmb(:), uniq_label{k}));
  end
  
  % assume the labelcmb to be well behaved (i.e. have a full parcellation per seed
  % either or not excluding the seed regions themselves), and to contain quadruplets
  % per combination (2 auto combinations and 2 directional interaction
  % terms)
  nref = sum(uniq_count==max(uniq_count));
  ref  = uniq_label(uniq_count==max(uniq_count));
  
  if strcmp(directionality, 'both')
    % recurse and combine
    fun1 = unparcellate(data_parcellated,parcellation,data.labelcmb,parcelparam,'avgoverref',avgoverref,'directionality','inflow');
    fun2 = unparcellate(data_parcellated,parcellation,data.labelcmb,parcelparam,'avgoverref',avgoverref,'directionality','outflow');
    fun  = [fun1;fun2]; clear fun1 fun2;
    
  else
    
    for k = 1:nref
      if strcmp(directionality, 'outflow')
        sel = strcmp(labelcmb(:,1),ref{k})&~strcmp(labelcmb(:,2),ref{k});
        sel2 = 2;
      elseif strcmp(directionality, 'inflow')
        sel = strcmp(labelcmb(:,2),ref{k})&~strcmp(labelcmb(:,1),ref{k});
        sel2 = 1;
      end
      
      tmpdat   = data_parcellated(sel,:);
      tmplabel = labelcmb(sel,sel2);
      
      % recurse into unparcellate
      tmpfun   = unparcellate(tmpdat, parcellation, tmplabel, parcelparam);
      
      if avgoverref
        if k==1
          fun = tmpfun;
        else
          fun = fun+tmpfun;
        end
      else
        if k==1
          fun = tmpfun;
        else
          fun = cat(1,fun, tmpfun);
        end
      end
      
    end
    
    if avgoverref
      fun = fun./nref;
    end
  end
  
  varargout{1} = fun;
  varargout{2} = ref;
  
end
