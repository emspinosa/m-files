function [u c varargout] = OptimalControlPenalize(f, varargin)
%% Algorithm for the optimisation of the considered framework.
%
% [u c ...] = OptimalControlPenalize(f, ...)
%
% Input parameters (required):
%
% f : The input image to be compressed.
%
% Input parameters (optional):
%
% Optional parameters are either struct with the following fields and
% corresponding values or option/value pairs, where the option is specified as a
% string.
%
% MaxOuter : Maximum number of outer iterations (scalar, default = 1).
% MaxInner : Maximum number of inner iterations (scalar, default = 10).
% TolOuter : Tolerance threshold for outer iterations (double, default = 1e-3).
% TolInner : Tolerance threshold for inner iterations (double, default = 1e-3).
% uInit    : Initial value for reconstruction. (array, default = f).
% cInit    : Initial value for reconstruction. (array, default = random mask).
% lambda   : Regularisation parameter. (double scalar, default = 1.0).
% penPDE   : Initial penalisation on the PDE (double, default = 1.0).
% penu     : Initial penalisation on prox. term for u (double, default = 1.0).
% penc     : Initial penalisation on prox. term for c (double, default = 1.0).
% uStep    : Penalisation increment for u (double, default = 2.0).
% cStep    : Penalisation increment for c (double, default = 2.0).
% PDEstep  : Penalisation increment for the PDE (double, default = 2.0).
% thresh   : Value at which mask should be thresholded. If negative, no
%            threshold will be done. Instead the PDE will be solved another time
%            to assert that the solution is feasible. A value of 0 means that
%            nothing will be done. Positive values imply a thresholding at the
%            given level. Note that the latter two variants may yield unfeasible
%            solutions with respect to the PDE. E.g the variables u and c may
%            not necessarily solve the PDE at the same time. (default = 0).
% maskNorm : The norm to be used to penalise the mask. Possible choices are 1 or
%            2. For 1, we penalise ||c||_1 and for 2 we use 0.5*||c||_2^2.
%            (default = 1).
%
% Output parameters (required):
%
% u     : Obtained reconstruction (array).
% c     : Corresponding mask (array).
%
% Output parameters (optional):
%
% ItIn    : Number of inner iterations performed. (scalar)
% ItOut   : Number of outer iterations performed. (scalar)
% EnVal   : Energy at each iteration step. (array)
% ReVal   : Residual at each iteration step. (array)
% IncPe   : Iterations when a increase in the penalisation happened. (array)
% SolHist : History of all solutions for every iteration. Note, that the last
%           entry in SolHist can differ from the mandatory output u. The
%           solution u may be subject to some further thresholding and is
%           additionally recomputed at the end as the solution of the PDE. These
%           steps are not performed for the entries in SolHist. They represent
%           the raw output obtained when iterating and may not even yield
%           feasible solutions. (cell array)
% MasHist : History of all masks for every iteration. (cell array)
% filterr : size of the average filter applied on the data before computing the
%           minimization w.r.t to c. Note that this has no real justification in
%           the model and is meant to be a workaround to improve robustness.
%           default = 1 (i.e. no averaging). Any value possible to be passed to
%           fspecial('average',filterr) is valid.
%
% Description
%
% Solves the optimal control formulation for PDE based image compression using
% the Laplacian.
%
% min 0.5*||u-f||_2^2 + l*||c||_1 s.th. c*(u-f)-(1-c)*D*u = 0
%
% The algorithm is a composition of several tools. The hard PDE constraint is
% replaced using an augmented formulation of the initial energy.
%
% min 0.5*||u-f||_2^2 + l*||c||_1 + t*||c*(u-f)-(1-c)*D*u||_2^2
%
% The thus obtained formulation is then solved alternatingly with respect to the
% reconstruction and to the mask. If a fix point (or the maximal number of
% alternating steps) is reached, then the penalisation on the PDE is increased.
% Then, the alternating optimisation steps are being repeated. Finally, the
% algorithm also adds to proximal terms that penalise excessively large
% deviation from the old iterates. This hopefully helps keeping the process
% stable.
%
% See also fmincon.

% Copyright 2012 Laurent Hoeltgen <laurent.hoeltgen@gmail.com>
%
% This program is free software; you can redistribute it and/or modify it under
% the terms of the GNU General Public License as published by the Free Software
% Foundation; either version 3 of the License, or (at your option) any later
% version.
%
% This program is distributed in the hope that it will be useful, but WITHOUT
% ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
% FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
% details.
%
% You should have received a copy of the GNU General Public License along with
% this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
% Street, Fifth Floor, Boston, MA 02110-1301, USA.

% Last revision on: 17.10.2012 17:00

%% Perform input and output argument checking.

narginchk(1,35);
nargoutchk(2,9);

parser = inputParser;
parser.FunctionName = mfilename;
parser.CaseSensitive = false;
parser.KeepUnmatched = true;
parser.StructExpand = true;

parser.addRequired('f', @(x) ismatrix(x)&&IsDouble(x));

parser.addParamValue('MaxOuter', 1, @(x) isscalar(x)&&IsInteger(x));
parser.addParamValue('MaxInner', 10, @(x) isscalar(x)&&IsInteger(x));

% The rather large tolerance values are correct. See the implementation below
% for more explanations. The point is that we are very tolerant here.
parser.addParamValue('TolOuter', 1e3, @(x) isscalar(x)&&(x>=0));
parser.addParamValue('TolInner',1e3, @(x) isscalar(x)&&(x>=0));

parser.addParamValue('uInit', [], @(x) ismatrix(x)&&IsDouble(x));
parser.addParamValue('cInit', [], @(x) ismatrix(x)&&IsDouble(x));

parser.addParamValue('lambda', 1.0, @(x) isscalar(x)&&(x>=0));

parser.addParamValue('penPDE', 1.0, @(x) isscalar(x)&&(x>=0));
parser.addParamValue('penu',   1.0, @(x) isscalar(x)&&(x>=0));
parser.addParamValue('penc',   1.0, @(x) isscalar(x)&&(x>=0));

parser.addParamValue('uStep',   2, @(x) isscalar(x)&&(x>=0));
parser.addParamValue('cStep',   2, @(x) isscalar(x)&&(x>=0));
parser.addParamValue('PDEstep', 2, @(x) isscalar(x)&&(x>=0));

parser.addParamValue('thresh', 0, @(x) isscalar(x)&&IsDouble(x));

parser.addParamValue('maskNorm', 1, @(x) (x==1)||(x==2));
parser.addParamValue('filterr', 1, @(x)all(IsInteger(x)));

parser.parse(f,varargin{:})
opts = parser.Results;

% Initialise solution and mask.
if isempty(opts.uInit)
    u = f;
else
    u = opts.uInit;
end

if isempty(opts.cInit)
    c = rand(size(f));
else
    c = opts.cInit;
end

if nargout > 2
    ItIn    = zeros(1,opts.MaxOuter);
    ItOut   = 0;
    EnerVal = inf*ones(1,opts.MaxInner*opts.MaxOuter);
    ResiVal = inf*ones(1,opts.MaxInner*opts.MaxOuter);
    IncPEN  = inf*ones(1,opts.MaxOuter);
    SolHist = cell(1,opts.MaxInner*opts.MaxOuter);
    MasHist = cell(1,opts.MaxInner*opts.MaxOuter);
end

[row col] = size(u);

% TODO: make passing of options more flexible.
% NOTE: the correct call would be LaplaceM(row, col, ...), however this assumes
% that the data is labeled row-wise. The standard MATLAB numbering is
% column-wise, therefore, we switch the order of the dimensions to get the
% (hopefully) correct behavior.
LapM = LaplaceM(col, row, 'KnotsR', [-1 0 1], 'KnotsC', [-1 0 1], ...
    'Boundary', 'Neumann');

k = 1;
NumIter = 0;
while k <= opts.MaxOuter
    %% Outer loop increases the penalization of deviations in the constraint.
    
    uOldK = u;
    cOldK = c;
    
    i = 1;
    while i <= opts.MaxInner
        %% Inner loop minimizes alternatively with respect to u and c.
        
        % Minimization w.r.t. to u is an lsq problem.
        % Minimization w.r.t. to c can be done through an extended variant of
        % soft shrinkage.
        
        uOldI = u;
        cOldI = c;
        
        % Find optimal u by solving a least squares problem.
        
        coeffs = [ 1 opts.penPDE opts.penu ];
        A = cell(3,1);
        b = cell(3,1);
        
        % NOTE: In the 2D case, the operators will have to respect the
        % column-wise numbering of the pixels!
        A{1} = speye(length(f(:)),length(f(:)));
        b{1} = f(:);
        
        A{2} = ConstructMat4u(cOldI,LapM);
        b{2} = cOldI(:).*f(:);
        
        A{3} = speye(length(f(:)),length(f(:)));
        b{3} = uOldI(:);
        
        u = Optimization.MinQuadraticEnergy(coeffs,A,b);
        % TODO: This shouldn't be necessary...
        u = reshape(u,size(f));
        
         % We integrate the data over a small local region to incorporate
         % more local data. Hopefully this improves the awareness of where
         % mask points are important.
         
         Intu = imfilter(u - f, ...
             fspecial('average', opts.filterr)*prod(opts.filterr), ...
             'Symmetric');
         
         if opts.maskNorm == 1
             % Find optimal c through a shrinkage approach.
             % This is the 1 norm case.
             lambda = opts.lambda*ones(length(c(:)),1);
             theta = [ opts.penPDE opts.penc ];
             
             A = [ Intu(:)+LapM*u(:) cOldI(:) ];
             b = [ LapM*u(:) cOldI(:) ];
             c = Optimization.SoftShrinkage(lambda,theta,A,b);
        else
            % Find optimal c through a least squares approach with diagonal
            % matrix. All diagonal entries are necessarily positive since the
            % penalisations must be positive.
            % This is the 2 norm case.
            c = (opts.penPDE*(Intu(:)+LapM*u(:)).*(LapM*u(:))+opts.penc)./ ...
                ((opts.lambda + opts.penc) + ...
                opts.penPDE*(Intu(:)+LapM*u(:)).^2 );
        end
        
        if nargout > 2
            EnerVal((k-1)*opts.MaxInner+i) = Energy(u,c,opts.f(:),opts.lambda);
            ResiVal((k-1)*opts.MaxInner+i) = Residual(u,c,opts.f(:));
            ItIn(k) = ItIn(k) + 1;
        end
        
        % While it might be unusual to have the following situation, we should
        % still account for it:
        %
        % Assume x_k = 1e12; Then
        % (xk + eps(xk)/2) - xk returns 0 although eps(xk)/2 is not 0.
        % In fact eps(xk)/2 is roughly 10e-4. In this case, a convergence test
        % of the form abs((xk + eps(xk)/2) - xk) < 1e-6 would always fail.
        %
        % A far better test would be:
        % abs((xk + eps(xk)/2) - xk) < 10*E_TOL*eps(xk)
        % where E_TOL is the tolerance measure and the factor 10 should allow
        % rounding errors. With this formulation we have:
        %
        % abs((xk + 11*E_TOL*eps(xk)) - xk) < 10*E_TOL*eps(xk) -> FALSE
        % abs((xk +  9*E_TOL*eps(xk)) - xk) < 10*E_TOL*eps(xk) -> TRUE
        %
        % This holds for any xk now.
        
        changeI = max([norm(uOldI(:)-u(:),Inf) norm(cOldI(:)-c(:),Inf)]);
        NumIter = NumIter + 1;
        
        % Save the history of the iterates u and c.
        SolHist{NumIter} = reshape(u,row,col);
        MasHist{NumIter} = reshape(c,row,col);
        
        % Note that opts.TolInner should be chosen rather large for our usual
        % data ranges.
        if ( ( norm(u(:)) > 1e8 ) && ...
                ( changeI < 10*opts.TolInner*eps(changeI) ) ) ...
                || ( ( norm(u(:))<=1e8 ) && ( changeI<opts.TolInner ) )
            break;
        else
            i = i + 1;
        end
        
    end
    
    % Check if we can end the algorithm and compute optional results.
    
    changeK = max([norm(uOldK(:)-u(:),Inf) norm(cOldK(:)-c(:),Inf)]);
    
    if nargout > 2
        ItOut = ItOut + 1;
    end
    
    % See the comments above changeI for details.
    if ((changeK > 1e8) && (changeK < 10*opts.TolOuter*eps(changeK) )) ...
            || (( changeK <=1e8) && (changeK < opts.TolOuter))
        break;
    else
        opts.penPDE = opts.penPDE*opts.PDEstep;
        opts.penu = opts.penu*opts.uStep;
        opts.penc = opts.penc*opts.cStep;
        if nargout > 2
            IncPEN(k) = NumIter;
        end
        k = k + 1;
    end
    
end

u = reshape(u,row,col);
c = reshape(c,row,col);

% If thresholding is positive, we use this value as a threshold for the mask.
% 0 means we do nothing to the solution from the iterative strategy.
% For negative values we solve the corresponding PDE in order to assert the the
% solution is feasible.
if opts.thresh < 0
    u = SolvePde(f,c);
elseif opts.thresh > 0
    u = SolvePde(f,Threshold(c,opts.thresh));
end

if nargout > 2
    % Remove the empty entries from the data.
    EnerVal(EnerVal==Inf) = [];
    ResiVal(ResiVal==Inf) = [];
    IncPEN(IncPEN==Inf) = [];
    SolHist = SolHist(~cellfun(@isempty,SolHist));
    MasHist = MasHist(~cellfun(@isempty,MasHist));
end

switch nargout
    case 3
        varargout{1} = ItIn;
    case 4
        varargout{1} = ItIn;
        varargout{2} = ItOut;
    case 5
        varargout{1} = ItIn;
        varargout{2} = ItOut;
        varargout{3} = Enerval;
    case 6
        varargout{1} = ItIn;
        varargout{2} = ItOut;
        varargout{3} = EnerVal;
        varargout{4} = ResiVal;
    case 7
        varargout{1} = ItIn;
        varargout{2} = ItOut;
        varargout{3} = EnerVal;
        varargout{4} = ResiVal;
        varargout{5} = IncPEN;
    case 8
        varargout{1} = ItIn;
        varargout{2} = ItOut;
        varargout{3} = EnerVal;
        varargout{4} = ResiVal;
        varargout{5} = IncPEN;
        varargout{6} = SolHist;
    case 9
        varargout{1} = ItIn;
        varargout{2} = ItOut;
        varargout{3} = EnerVal;
        varargout{4} = ResiVal;
        varargout{5} = IncPEN;
        varargout{6} = SolHist;
        varargout{7} = MasHist;
end
end

function out = ConstructMat4u(c,D)
out = spdiags(c(:),0,length(c(:)),length(c(:))) - ...
    spdiags(1-c(:),0,length(c(:)),length(c(:)))*D;
end
