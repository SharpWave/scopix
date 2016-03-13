function [] = MakeTransients(file,todebug,varargin)
% [] = MakeTransients(file,todebug,varargin)
%
% Take all of those blobs found in ExtractBlobs.m and figure out, for each
% one, whether there was one on the previous frame that matched it and if
% so which one, thus deducing calcium transients across frames
%
% varargins:
%   'min_trans_length':minimum number of frames a transient must last in
%   order to be included, enter as MakeTransients(...,'min_trans_length,3)
%
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
%
%% Calcium transient inclusion criteria
min_trans_length = 3; % (default) minimum number of frames a transient must last in order to be included
max_trans_dist = 2; % (default) maximum number of pixels a transient can travel without being discarded

%% Get vargins
for j = 1:length(varargin)
   if strcmpi(varargin{j},'min_trans_length')
       min_trans_length = varargin{j+1};
   end
%    if strcmpi(varargin{j},'max_trans_dist')
%       max_trans_dist = varargin{j+1};
%    end
end

%%

load ('Blobs.mat','cc','PeakPix');

if (nargin < 2)
    todebug = 0;
end

info = h5info(file,'/Object');
NumFrames = info.Dataspace.Size(3);
Xdim = info.Dataspace.Size(1);
Ydim = info.Dataspace.Size(2);

NumSegments = 0;
SegChain = [];
SegList = zeros(NumFrames,100);

for i = 2:NumFrames
    i
     stats = regionprops(cc{i},'MinorAxisLength');
     
%     oldstats = regionprops(cc{i-1},'WeightedCentroid');
    Peaks = PeakPix{i};
    OldPeaks = PeakPix{i-1};
    for j = 1:cc{i}.NumObjects
        if (todebug)
            % plot frame and neuron outline of neuron in question
            f = loadframe(file,i);
            temp = zeros(Xdim,Ydim);
            temp(cc{i}.PixelIdxList{j}) = 1;
            b = bwboundaries(temp);
            y = b{1}(:,1);
            x = b{1}(:,2);
            
            subplot(1,2,1)
            imagesc(f);colormap gray;caxis([-500 500]);hold on;
            plot(x,y,'-r','LineWidth',3);hold off;
            title ('blob that we are trying to match (red)');
            
            % plot all of the neurons on the previous frame
            f = loadframe(file,i-1);
            subplot(1,2,2);
            imagesc(f);colormap gray;caxis([-500 500]);hold on;
            title('previous blobs in green, matched blob in red');
            for k = 1:cc{i-1}.NumObjects
                temp = zeros(Xdim,Ydim);
                temp(cc{i-1}.PixelIdxList{k}) = 1;
                b = bwboundaries(temp);
                y = b{1}(:,1);
                x = b{1}(:,2);
                plot(x,y,'-g');
            end
        end

        % find match
        [MatchingSeg,idx] = MatchSeg(Peaks{j},OldPeaks,SegList(i-1,:),stats(j).MinorAxisLength);
        if (MatchingSeg == 0)
            % no match found, make a new segment
            NumSegments = NumSegments+1;
            SegChain{NumSegments} = {[i,j]};
            SegList(i,j) = NumSegments;
        else
            % a match was found, add to segment
            SegChain{MatchingSeg} = [SegChain{MatchingSeg},{[i,j]}];
            SegList(i,j) = MatchingSeg;
            if (todebug)
                subplot(1,2,2);
                hold on;
                temp = zeros(Xdim,Ydim);
                temp(cc{i-1}.PixelIdxList{idx}) = 1;
                b = bwboundaries(temp);
                y = b{1}(:,1);
                x = b{1}(:,2);
                plot(x,y,'-r');
                hold off;pause;
            end
            
        end
    end
end

for i = 1:length(SegChain)
    TransientLength(i) = length(SegChain{i});
end

DistTrav = TransientStats(SegChain);

gooddist = find(DistTrav < max_trans_dist);

SegChain = SegChain(gooddist);
NumSegments = length(SegChain);
TransientLength = TransientLength(gooddist);


% if min_trans_length == 5
%     save Segments.mat NumSegments SegChain cc NumFrames Xdim Ydim min_trans_length max_trans_dist
% else
%     save_name = ['Segments_minlength_' num2str(min_trans_length) '.mat'];
%     save(save_name, 'NumSegments', 'SegChain', 'cc', 'NumFrames', 'Xdim', 'Ydim', 'min_trans_length', 'max_trans_dist')
% end
save('Transients.mat', 'NumSegments', 'SegChain', 'NumFrames', 'Xdim', 'Ydim', 'min_trans_length', 'max_trans_dist','TransientLength')



end

