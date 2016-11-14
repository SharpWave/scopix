function InterpretTraces(Todebug)

%
% Copyright 2016 by David Sullivan, Nathaniel Kinsky, and William Mau
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


if (~exist('Todebug','var'))
    Todebug = 0;
end

load('SegmentationROIs.mat','NeuronActivity','NumNeurons','NeuronTraces','NeuronPixelIdxList','NeuronAvg');
[Xdim,Ydim,NumFrames,AmplitudeThresholdCoeff,CorrPthresh,MaxGapFillLen,SlopeThresh] = Get_T_Params('Xdim','Ydim','NumFrames','AmplitudeThresholdCoeff','CorrPthresh','MaxGapFillLen','SlopeThresh');

blankframe = zeros(Xdim,Ydim,'single');
PSAbool = false(NumNeurons,NumFrames);
old = 0.001;

%% determine overlapping ROIs
disp('calculating overlapping ROIs');

ROIoverlap = false(NumNeurons,NumNeurons);
for i = 1:NumNeurons
    for j = i+1:NumNeurons
        if(~isempty(intersect(NeuronPixelIdxList{i},NeuronPixelIdxList{j})));
            ROIoverlap(i,j) = true;
            ROIoverlap(j,i) = true;
        end
    end
end
%% For each neuron, find samples where there were either segmentation-identified transients or potential transients
disp('analyzing traces for potential transients');
for i = 1:NumNeurons
    % calculate the amplitude threshold based on the
    % segmentation-identified frames
    %i = ceil(rand*NumNeurons);
    Threshold = min(NeuronTraces.LPtrace(i,NeuronActivity(i,:)));
    Threshold = Threshold - abs(Threshold)/3;
    
    % find epochs where the trace was above amplitude threshold
    PosEpochs = NP_FindSupraThresholdEpochs(NeuronTraces.LPtrace(i,:),Threshold);
    PosBool = logical(NeuronTraces.LPtrace(i,:) > Threshold);
    
    % find epochs where the correlation was significant
    CorrSig = NeuronTraces.CorrR(i,:).*(NeuronTraces.CorrP(i,:)< CorrPthresh);
    % find epochs where the significant correlation is nonzero and overlaps
    % with segmentation-identified activity
    GoodCS = logical(NeuronActivity(i,:).*(CorrSig > 0));
    
    if (sum(GoodCS) == 0)
        continue;
    end
    
    % set the correlation threshold as the minimum r during these epochs
    CorrThresh = min(CorrSig(GoodCS));
    
    % find epochs above the correlation threshold
    
    CorrEpochs = NP_FindSupraThresholdEpochs(CorrSig,CorrThresh);
    
    CorrBool = CorrSig > CorrThresh;
    
    GoodTrBool = false(1,NumFrames);
    
    % identify good correlation epochs that are also above the amplitude
    % threshold for at least 1 frame
    for j = 1:size(CorrEpochs,1)
        % check and see if the amplitude threshold is breached during this
        % epochs, if so, keep it
        if(sum(PosBool(CorrEpochs(j,1):CorrEpochs(j,2))) > 0)
            GoodTrBool(CorrEpochs(j,1):CorrEpochs(j,2)) = true;
        end
    end
    
    % identify small gaps that we can fill in
    ZeroEpochs = NP_FindSupraThresholdEpochs(~GoodTrBool,eps);
    EpLen = ZeroEpochs(:,2)-ZeroEpochs(:,1);
    GoodFill = EpLen <= MaxGapFillLen;
    ZeroEpochs = ZeroEpochs(GoodFill,:);
    
    % fill gaps
    for j = 1:size(ZeroEpochs,1)
        GoodTrBool(ZeroEpochs(j,1):ZeroEpochs(j,2)) = true;
    end
    
    InSlope = false;
    
    SlopeTr = NeuronTraces.DFDTtrace(i,:);
    
    for j = 1:NumFrames
        if (InSlope)
            % check if fluoresence slope is still postive
            if ((SlopeTr(j) > 0) && (GoodTrBool(j)))
                PSAbool(i,j) = true;
            else
                InSlope = false;
            end
        else
            % not currently in a slope
            if (GoodTrBool(j))
                if (SlopeTr(j) >= SlopeThresh)
                    % new slope
                    InSlope = true;
                    PSAbool(i,j) = true;
                    % check if we can go backward
                    BackCheck = j-1;
                    while((SlopeTr(BackCheck) > SlopeThresh) && (BackCheck >= 2))
                        PSAbool(i,BackCheck) = true;
                        BackCheck = BackCheck - 1;
                    end
                end
            end
        end
    end
    
    %% plotting (optional)
    if (Todebug)
        a(1) = subplot(2,6,1:4);
        hold off;
        plot(NeuronTraces.LPtrace(i,:),'-b');hold on;
        plot(NeuronTraces.LPtrace(i,:).*NeuronActivity(i,:),'-k','LineWidth',2);
        plot(NeuronTraces.LPtrace(i,:).*GoodTrBool,'-r','LineWidth',1);
        plot(NeuronTraces.LPtrace(i,:).*PSAbool(i,:),'-g','LineWidth',1);
        axis tight;
        a(2) = subplot(2,6,7:10);
        hold off;
        plot(CorrSig,'-m');
        hold on;plot(CorrSig.*(CorrSig > CorrThresh));axis tight;hold off;
        
        linkaxes(a,'x');
        
        subplot(2,6,11);histogram(NeuronTraces.CorrR(i,NeuronActivity(i,:)),(-1:0.05:1));title(num2str(CorrThresh));
        subplot(2,6,5);histogram(NeuronTraces.LPtrace(i,NeuronActivity(i,:)),(0:0.005:0.2));
        pause;
        ToGo = 'y';
        while(strcmpi(ToGo,'y'))
            display('pick a time to see the frame')
            [mx,my] = ginput(1)
            f = LoadFrames('BPDFF.h5',ceil(mx));
            b(1) = subplot(2,6,6);imagesc(f);axis image;
            try caxis([0 max(f(NeuronPixelIdxList{i}))]); end
            tempf = blankframe;
            tempf(NeuronPixelIdxList{i}) = NeuronAvg{i};
            b(2) = subplot(2,6,12);imagesc(tempf);axis image;
            linkaxes(b);
            ToGo = input('do another frame? [y/n] -->','s');
        end
    end
end


%% eliminate spatiotemporal overlaps
disp('eliminating spatiotemporal overlaps');

for i = 1:NumNeurons
    actlist{i} = NP_FindSupraThresholdEpochs(PSAbool(i,:),eps);
end
p = ProgressBar(NumNeurons);

for i = 1:NumNeurons
    Neighbors = find(ROIoverlap(i,:));
   for j = 1:size(actlist{i},1)
       % do any neighbors have an epoch that starts or ends during this
       % one?
       actframes = (actlist{i}(j,1):actlist{i}(j,2));
       nList = [];
       epList = [];
       meanDffList = [];
       for k = 1:length(Neighbors)
           nIdx = Neighbors(k);
           for m = 1:size(actlist{nIdx})
               if (ismember(actlist{nIdx}(m,1),actframes) || ismember(actlist{nIdx}(m,2),actframes))
                   % neuron nIdx epoch m overlaps with neuron i epoch j
                   nList = [nList,nIdx];
                   epList = [epList,m];
                   meanDffList = [meanDffList,mean(NeuronTraces.LPtrace(nIdx,actlist{nIdx}(m,1):actlist{nIdx}(m,2)))];
               end
           end
       end
       
       if (isempty(nList))
           continue;
       end
       
       TijMeanDFF = mean(NeuronTraces.LPtrace(i,actlist{i}(j,1):actlist{i}(j,2)));
       
       nList = [i,nList];
       epList = [j,epList];
       meanDFFList = [TijMeanDFF,meanDffList];
       [~,maxidx] = max(meanDFFList);       
       
       
       for k = 1:length(nList)
           if ((k == maxidx) || (nList(k) == nList(maxidx)))
               continue;
           end
           
           % kill the epoch
           PSAbool(nList(k),actlist{nList(k)}(epList(k),1):actlist{nList(k)}(epList(k),2)) = false;
           if (nList(k) ~= i)
              actlist{nList(k)} = NP_FindSupraThresholdEpochs(PSAbool(nList(k),:),eps); 
           end
       end
   end
   actlist{i} = NP_FindSupraThresholdEpochs(PSAbool(i,:),eps);

       
                   
    p.progress;
end
p.stop;



save PSAbool.mat PSAbool;

