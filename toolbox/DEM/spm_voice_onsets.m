function [I] = spm_voice_onsets(Y,FS,T,U,C)
% identifies intervals containing acoustic energy and post onset minima
% FORMAT [I] = spm_voice_onsets(Y,FS,T,U,C)
%
% Y    - timeseries
% FS   - sampling frequency
% T    - onset    threshold [Default: 1/16 sec]
% U    - crossing threshold [Default: 1/16 a.u]
% C    - spectral smoothing [Default: 1/32 sec]
%
% I{i} - cell array of intervals (time bins) containing spectral energy
%
% This routine identifies epochs constaining spectral energy of the power
% envelope, defined as the root mean square (RMS) power. The onset and
% offset of words is evaluated in terms of threshold crossings before and
% after the midpoint of a one second epoch. These are supplemented with
% internal minima (after the spectral peak).
%__________________________________________________________________________
% Copyright (C) 2008 Wellcome Trust Centre for Neuroimaging

% Karl Friston
% $Id: spm_voice_onsets.m 7567 2019-04-04 10:41:15Z karl $

% find the interval that contains spectral energy
%==========================================================================
global VOX

if nargin < 3, T = 1/16; end                          % onset  threshold
if nargin < 4, U = 1/16; end                          % height threshold
if nargin < 5, C = 1/16; end                          % smoothing

% identify threshold crossings in power
%--------------------------------------------------------------------------
G   = spm_voice_check(Y,FS,C);                        % smooth RMS
n   = length(G);                                      % number of time bins
j   = fix(FS*T:FS/2);                                 % pre-peak
y0  = G - min(G(j(logical(G(j)))));                   % minimum
j   = fix(FS/2:n);                                    % post-peak
yT  = G - min(G(j(logical(G(j)))));                   % minimum
y0  = y0/max(y0);                                     % normalise
yT  = yT/max(yT);                                     % normalise

% find zero crossings (of U) or offset minima if in audio mode
%--------------------------------------------------------------------------
j0 = find(y0(1:end - 1) < U & y0(2:end) > U);
jT = find(yT(1:end - 1) > U & yT(2:end) < U);

% boundary conditions
%--------------------------------------------------------------------------
if numel(j0) < 1,  j0 = FS*T; end
if j0(1)   > FS/2, j0 = FS*T; end
if jT(end) < FS/2, jT = n;    end

% and supplement offsets with (internal) minima
%--------------------------------------------------------------------------
i  = find(diff(yT(1:end - 1)) < 0 & diff(yT(2:end)) > 0);
i  = i(yT(i) < 1/2 & yT(i) > U & i < jT(end));
jT = sort(unique([jT; i]));

% boundary conditions
%--------------------------------------------------------------------------
if numel(j0) > 1
    j0 = j0(j0 < FS/2 & j0 > FS*T);
end
if numel(jT) > 1
    jT = jT(jT > FS/2);
end

% indices of interval containing spectral energy
%--------------------------------------------------------------------------
I     = {};
for i = 1:numel(j0)
    for j = 1:numel(jT)
        
        % k-th interval
        %------------------------------------------------------------------
        k  = j0(i):jT(j);
        ni = numel(k);
        
        % retain intervals of plausible length
        %------------------------------------------------------------------
        if ni > FS/32
            I{end + 1} = k;
        end
    end
end

% sort lengths (longest first)
%--------------------------------------------------------------------------
for i = 1:numel(I)
    ni(i) = numel(I{i});
end
[d,j] = sort(ni,'descend');
I     = I(j);

% graphics(if requested)
%==========================================================================
if ~VOX.onsets
    return
else
    spm_figure('GetWin','onsets'); clf;
end

% timeseries
%--------------------------------------------------------------------------
pst   = (1:n)/FS;
Y     = Y/max(Y);
subplot(2,1,1)
plot(pst,Y,'b'),             hold on
plot(pst,G/max(G),':b'),     hold on
plot(pst,Y,'b'),             hold on
plot(pst,G,':b'),             hold on
plot(pst,0*pst + U,'-.'),    hold on
plot([1 1]/2,[-1 1],'b'),    hold on
plot([1 1]*T,[-1 1],'--g'),  hold on
for i = 1:numel(I)
    x = [I{i}(1),I{i}(end),I{i}(end),I{i}(1)]/FS;
    y = [-1,-1,1,1];
    c = spm_softmax(rand(3,1))';
    h = fill(x,y,c);
    set(h,'Facealpha',1/8,'EdgeAlpha',1/8);
end
title('Onsets and offsets','FontSize',16)
xlabel('peristimulus time (seconds)'), spm_axis tight, hold off

% envelope and threshold crossings
%--------------------------------------------------------------------------
subplot(2,1,2)
plot(pst,y0,'g',pst,yT,'r'), hold on
plot(pst,0*pst + U,'-.'),    hold on
plot([1 1]/2,[0 1],'b'),     hold on
plot([1 1]*T,[0 1],'--g'),   hold on
for i = 1:numel(j0), plot(pst(j0(i)),y0(j0(i)),'og'), end
for i = 1:numel(jT), plot(pst(jT(i)),yT(jT(i)),'or'), end
title('Log energy','FontSize',16)
xlabel('peristimulus time (secs)'), spm_axis tight, hold off
drawnow, pause(1/4)

% uncomment to play interval
%--------------------------------------------------------------------------
% sound(Y(i),FS)









