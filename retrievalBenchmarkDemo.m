function [mAP queryAPs] = retrievalBenchmarkDemo()
% RETRIEVALBENCHMARKDEMO Demo of retrieval benchmark usage
import localFeatures.*;
import datasets.*;
import benchmarks.*;

%% Define Local features detectors
detectors{1} = VggAffine('Detector','haraff');
detectors{2} = VggAffine('Detector','hesaff');
detectors{3} = CmpBinHessian();
% For MSERs use VGG SIFT as descriptors
detectors{4} = DescriptorAdapter(VggMser(),VggAffine());

detNames = {'VGG MSER + VGG SIFT','VGG Harris Affine',...
  'VGG Hessian Affine','CMP Hessian Affine'};

%% Define dataset
dataset = VggRetrievalDataset('Category','oxbuild','Lite',true);

%% Run the benchmark
retBenchmark = RetrievalBenchmark();

mAP = zeros(numel(detectors),1);
queryAPs = zeros(numel(detectors),dataset.NumQueries);

for d=1:numel(detectors)
  [mAP(d) queryAPs(d,:)]  = retBenchmark.evalDetector(detectors{d}, dataset);
end

% TODO plot / print the results