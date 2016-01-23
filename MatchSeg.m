function [MatchingSeg,minidx] = MatchSeg(currstat,oldstats,SegList)
% [MatchingSeg,minidx] = MatchSeg(currstat,oldstats,SegList)
% Copyright 2015 by David Sullivan and Nathaniel Kinsky
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This file is part of Tenaspis.
% 
%     Tenaspis is free software: you can redistribute it and/or modify
%     it under the terms of the GNU General Public License as published by
%     the Free Software Foundation, either version 3 of the License, or
%     (at your option) any later version.
% 
%     Tenaspis is distributed in the hope that it will be useful,
%     but WITHOUT ANY WARRANTY; without even the implied warranty of
%     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%     GNU General Public License for more details.
% 
%     You should have received a copy of the GNU General Public License
%     along with Tenaspis.  If not, see <http://www.gnu.org/licenses/>.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
minidx = 0;

if (length(oldstats) == 0)
    % no segs on the preceding frame
    MatchingSeg = 0;
    return;
end

% calculate distance
p1 = currstat.Centroid;

for i = 1:length(oldstats)
    p2 = oldstats(i).Centroid;
    d(i) = pdist([p1;p2],'euclidean');
end

[mindist,minidx] = min(d);

if (mindist < currstat.MinorAxisLength)
    % we'll consider this a match
    MatchingSeg = SegList(minidx);
else
    % no match found
    MatchingSeg = 0;
end

end

