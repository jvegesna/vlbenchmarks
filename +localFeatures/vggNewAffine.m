% VGGNEWAFFINE class to wrap around the VGG new affine co-variant detectors.
%
%   obj = affineDetectors.vggNewAffine('Option','OptionValue',...);
%   frames = obj.detectPoints(img)
%
%   obj class implements the genericDetector interface and wraps around the
%   vgg implementation of harris and hessian affine detectors (Philbin
%   version).
%
%   The constructor call above takes the following options:
%
%   Detector:: ['hessian']
%     One of 'hessian' or 'harris' to select what type of corner detector to use
%
%   threshold:: [-1]
%     Cornerness threshold.
%
%   noAngle:: [false]
%     Compute rotation variant descriptors if true (no rotation esimation)
%
%   Magnification:: [binary default]
%     Magnification of the measurement region for the descriptor
%     calculation.
%



classdef vggNewAffine < localFeatures.genericLocalFeatureExtractor
  properties (SetAccess=private, GetAccess=public)
    opts
    detBinPath
  end
  
  properties (Constant)
    rootInstallDir = fullfile('data','software','vggNewAffine','');
  end

  methods
    % The constructor is used to set the options for vggNewAffine
    function obj = vggNewAffine(varargin)
      import localFeatures.*;
      import helpers.*;

      if ~vggNewAffine.isInstalled(),
        obj.isOk = false;
        obj.errMsg = 'vggNewAffine not found installed';
        return;
      end

      % Parse the passed options
      obj.opts.detector= 'hessian';
      obj.opts.threshold = -1;
      obj.opts.noAngle = false;
      obj.opts.magnification = -1;
      [obj.opts varargin] = vl_argparse(obj.opts,varargin);

      switch(lower(obj.opts.detector))
        case 'hessian'
          obj.opts.detectorType = 'hesaff';
        case 'harris'
          obj.opts.detectorType = 'haraff';
        otherwise
          error('Invalid detector type: %s\n',obj.opts.detector);
      end
      obj.detectorName = [obj.opts.detector '-affine(new vgg)'];
  
      % Check platform dependence
      machineType = computer();
      obj.detBinPath = '';
      switch(machineType)
        case {'GLNXA64','GLNX86'}
          obj.detBinPath = fullfile(vggNewAffine.rootInstallDir,'detect_points_2.ln');
        otherwise
          obj.isOk = false;
          obj.errMsg = sprintf('Arch: %s not supported by vggNewAffine',...
                                machineType);
      end
      obj.configureLogger(obj.detectorName,varargin);
    end

    function [frames descriptors] = extractFeatures(obj, imagePath)
      import helpers.*;
      import localFeatures.*;
      if ~obj.isOk, frames = zeros(5,0); return; end

      [frames descriptors] = obj.loadFeatures(imagePath,nargout > 1);
      if numel(frames) > 0; return; end;

      startTime = tic;
      obj.info('computing frames for image %s.',getFileName(imagePath)); 
      
      noAngle = obj.opts.noAngle;
      
      tmpName = tempname;
      framesFile = [tmpName '.' obj.opts.detectorType];
      
      detArgs = '';
      if obj.opts.threshold >= 0
        detArgs = sprintf('-thres %f ',obj.opts.threshold);
      end
      detArgs = sprintf('%s-%s -i "%s" -o "%s" %s',...
                     detArgs, obj.opts.detectorType,...
                     imagePath,framesFile);

      detCmd = [obj.detBinPath ' ' detArgs];

      [status,msg] = system(detCmd);
      if status
        error('%d: %s: %s', status, detCmd, msg) ;
      end
      
      if nargout ==2
        [ frames descriptors ] = helpers.vggCalcSiftDescriptor( imagePath, ...
                                  framesFile, 'Magnification', obj.opts.magnification,...
                                  'NoAngle', noAngle );
      else
        % read the frames in own way because the output files are not
        % correct (descr. size is set to 1 even when it is zero...).
        fid = fopen(framesFile, 'r');
        dim=fscanf(fid, '%f',1);
        if dim==1
          dim=0;
        end
        nb=fscanf(fid, '%d',1);
        frames = fscanf(fid, '%f', [5+dim, inf]);
        fclose(fid);
        
        % Compute the inverse of the shape matrix
        frames(1:2,:) = frames(1:2,:) + 1 ; % matlab origin
        den = frames(3,:) .* frames(5,:) - frames(4,:) .* frames(4,:) ;
        frames(3:5,:) = [frames(5,:) ; -frames(4,:) ; frames(3,:)] ./ den([1 1 1], :) ;    
      end
      
      delete(framesFile);
      
      timeElapsed = toc(startTime);
      obj.debug('Frames of image %s computed in %gs',...
        getFileName(imagePath),timeElapsed);
      
      obj.storeFeatures(imagePath, frames, descriptors);
    end
    
    function sign = getSignature(obj)
      signList = {helpers.fileSignature(obj.detBinPath) ... 
                  helpers.struct2str(obj.opts)};
      sign = helpers.cell2str(signList);
    end

  end

  methods (Static)

    function response = isInstalled()
      import localFeatures.*;
      installDir = vggNewAffine.rootInstallDir;
      if(exist(installDir,'dir')),  response = true;
      else response = false; end
    end

  end % ---- end of static methods ----

end % ----- end of class definition ----
