function [cc,PeakPix,NumItsTaken] = SegmentFrame(frame,mask,thresh)
% [frame,cc,ccprops] = SegmentFrame(frame,mask,thresh)
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

% Parameters
minpixels = 60; % minimum blob size during initial segmentation
adjminpixels = 40; % minimum blob size during re-segmentation attempts
threshinc = 0.01; % how much to increase threshold by on each re-segmentation iteration
neuronthresh = 150; % maximum blob size to be considered a neuron
minsolid = 0.9; % minimum blob solidity to be considered a neuron


PeakPix = [];
badpix = find(mask == 0);

% threshold and segment the frame
initframe = double(frame);
blankframe = zeros(size(initframe));
minval = min(initframe(:));


threshframe = frame > thresh;
threshframe = bwareaopen(threshframe,minpixels,4); % remove blobs smaller than minpixels

newlist = [];
currnewList = 0;
BlobsInFrame = 1;
NumIts = 0;
tNumItsTaken = [];

while(BlobsInFrame)
    NumIts = NumIts + 1;
    BlobsInFrame = 0;
    % threshold and segment the frame
    
    bb = bwconncomp(threshframe,4);
    rp = regionprops(bb,'Area','Solidity');
    
    if (isempty(bb.PixelIdxList))
        break;
    end
    
    % there were blobs, check if any of them satisfy size and
    % solidity criteria
    bsize = [];
    bSolid = [];
    
    for j = 1:length(bb.PixelIdxList)
        bsize(j) = rp(j).Area;
        bSolid(j) = rp(j).Solidity;
    end
    
    newn = intersect(find(bsize <= neuronthresh),find(bSolid >= minsolid));
    
    for j = 1:length(newn)
        % append new blob pixel lists
        currnewList = currnewList + 1;
        newlist{currnewList} = bb.PixelIdxList{newn(j)};
        tNumItsTaken(currnewList) = NumIts;
    end
        
    if (length(newn) == length(bb.PixelIdxList))
        % nothing left to split
        break;
    end
    
    % still blobs left
    BlobsInFrame = 1;
    oldn = union(find(bsize > neuronthresh), find(bSolid<minsolid));
    
    % make a frame containing the remaining blobs
    temp = blankframe + minval;
    for j = 1:length(oldn)
        temp(bb.PixelIdxList{oldn(j)}) = initframe(bb.PixelIdxList{oldn(j)});
    end
    
    % increase threshold
    thresh = thresh + threshinc;
    threshframe = temp > thresh;
    threshframe = bwareaopen(threshframe,adjminpixels,4);
    
    
end

NumItsTaken = [];

% exit if no blobs found
if (isempty(newlist))
    PeakPix = [];
    cc.NumObjects = 0;
    cc.PixelIdxList = [];
    display('no blobs detected');
    return;
end

numlists = 0;
newcc.PixelIdxList = [];

for i = 1:length(newlist)
    if (isempty(intersect(newlist{i},badpix)))
        numlists = numlists + 1;
        newcc.PixelIdxList{numlists} = single(newlist{i});
        NumItsTaken(numlists) = tNumItsTaken(i);
    end
end

newcc.NumObjects = numlists;
newcc.ImageSize = size(frame);
newcc.Connectivity = 4;
cc = newcc;

% get peak pixel
for i = 1:length(cc.PixelIdxList)
    [~,idx] = max(initframe(cc.PixelIdxList{i}));
    [PeakPix{i}(1),PeakPix{i}(2)] = ind2sub(cc.ImageSize,cc.PixelIdxList{i}(idx));
end

%display([int2str(length(cc.PixelIdxList)),' Blobs Detected'])
end







