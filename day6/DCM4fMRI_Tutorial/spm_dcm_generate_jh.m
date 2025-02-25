function [Y,X] = spm_dcm_generate_jh(syn_model,SNR)
% Generate synthetic data from a DCM specification
% FORMAT [Y,x] = spm_dcm_generate(syn_model,SNR)
% 
% syn_model   - Name of synthetic DCM file
% SNR         - Signal to noise ratio [default: 1]
%
% This routine will update the DCM.Y field as follows: 
%           Y.y    - synthetic BOLD data
%           Y.secs - overall number of seconds
%           Y.Q    - components of error precision
%
% and will enter neuronal activity (first hidden var in each region) into 
% DCM.x
%
% Y           - Simulated (Noisy) BOLD data
% x           - Simulated neuronal activity (first hidden variable in each region)
%__________________________________________________________________________
% Copyright (C) 2002-2014 Wellcome Trust Centre for Neuroimaging

% Will Penny & Klaas Enno Stephan
% $Id: spm_dcm_generate.m 6031 2014-06-02 12:49:52Z guillaume $

% Check parameters and load specified DCM
%--------------------------------------------------------------------------
if isstruct(syn_model)
    DCM       = syn_model;
    syn_model = ['DCM-' date '.mat'];
else
    load(syn_model)
end
if nargin < 2 || isempty(SNR)
    SNR = 1;
end

nOut=6; %number of outputs.
% Unpack
%--------------------------------------------------------------------------
U     = DCM.U;        % inputs
v     = DCM.v;        % number of scans
n     = DCM.n;        % number of regions
m     = size(U.u,2);  % number of inputs


% Check whether the model is stable by examining the eigenvalue 
% spectrum for the intrinsic connectivity matrix 
%--------------------------------------------------------------------------
[is_stable, eigval] = spm_dcm_check_stability(DCM);
if ~is_stable
    fprintf('Modelled system is potentially unstable:\n');
    fprintf('Lyapunov exponent of combined connectivity matrix is %f\n',max(eigval));
    fprintf('Check the output to ensure that values are in a normal range.\n')
end


% check whether this is a nonlinear DCM
%--------------------------------------------------------------------------
if ~isfield(DCM,'d') || isempty(DCM.d)
    DCM.d = zeros(n,n,0);
    M.IS  = 'spm_int';
else
    M.IS  = 'spm_int_D';
end


% priors
%--------------------------------------------------------------------------
[pE,pC] = spm_dcm_fmri_priors(DCM.a,DCM.b,DCM.c,DCM.d);


% complete model specification
%--------------------------------------------------------------------------
M.f     = 'spm_fx_fmri';
M.g     = 'spm_gx_state_fmri_jh';
M.x     = sparse(n,5);
M.pE    = pE;
M.pC    = pC;
M.m     = size(U.u,2);
M.n     = size(M.x(:),1);
M.l     = size(M.x,1)*nOut; % twice as many "outputs" (as hemo and neuronal)
M.N     = 32;
M.dt    = 16/M.N;
M.ns    = v;
M.nOut  = 6;

% fMRI slice time sampling
%--------------------------------------------------------------------------
try, M.delays = DCM.delays; end
try, M.TE     = DCM.TE;     end

% twice as many "outputs" (hemo and neuronal) - need this to coerce spm_int
%--------------------------------------------------------------------------
M.delays = repmat(M.delays,nOut,1); 
 
% Integrate and compute hemodynamic response at v sample points
%--------------------------------------------------------------------------
y      = feval(M.IS,DCM.Ep,M,U);


% Compute required r: standard deviation of additive noise, for all areas
%--------------------------------------------------------------------------
r      = diag(std(y(:,1:n))/SNR);


% Add noise
%--------------------------------------------------------------------------
p      = 1;
a      = 1/16;
a      = [1 -a];
K      = inv(spdiags(ones(v,1)*a,-[0:p],v,v));
K      = K*sqrt(v/trace(K*K'));
z      = randn(v,n);
e      = K*z;
Y      = DCM.Y;
Y.Q    = spm_Ce(v*ones(1,n));

Y.yData    = y(:,1:n) + e*r; 
Y.y      = y(:,1:n);
X.x      = y(:,n+1:5:6*n);
X.s      = y(:,n+2:5:6*n);
X.f      = y(:,n+3:5:6*n);
X.v      = y(:,n+4:5:6*n);
X.q      = y(:,n+5:5:6*n);

Y.secs = Y.dt*v;

% Save synthetic DCM
%--------------------------------------------------------------------------
DCM.Y  = Y;                                    % simulated data
DCM.y  = y(:,1:n);                             % simulated BOLD
DCM.x  = X.x;                                    % simulated neuronal
DCM.M  = M;                                    % model

if nargout==1
    varargout{1} = DCM;
end

if spm('CmdLine'), return; end

% % Display the time series generated
% %--------------------------------------------------------------------------
% spm_figure('Create','Graphics','Simulated BOLD time series');
% t     = Y.dt*[1:1:v];
% for i = 1:n,
%     subplot(n,1,i);
%     plot(t,Y.y(:,i));
%     title(sprintf('Region %s', Y.name{i}));
%     if i<n set(gca,'XTickLabel',[]); end
% end
% xlabel('secs');
% 
% spm_figure('Create','Graphics','Simulated Neuronal Activity');
% t     = Y.dt*[1:1:v];
% for i = 1:n,
%     subplot(n,1,i);
%     plot(t,x(:,i));
%     title(sprintf('Region %s', Y.name{i}));
%     if i<n set(gca,'XTickLabel',[]); end
% end
% xlabel('secs');

