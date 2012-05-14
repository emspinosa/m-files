function M = GradientM(r,c,varargin)
%% Returns the matrix corresponding to the Gradient operator.
%
% M = GradientM(r,c,varargin)
%
% Computes the matrix corresponding to the Gradient operator. The discretisation
% is based on separable finite difference schemes (which can be specified
% through the options). The returned matrix is sparse. Boundary conditions can
% be specified through optional parameters. Accepted values are 'Neumann' or
% 'Dirichlet'. Note that the Boundary conditions must be the same for the x and
% for the y derivative. The output Matrix computes first all the derivatives in
% x direction and then all the derivatives in y direction.
%
% Input Parameters (required):
%
% r : number of rows of the signal. (positive integer)
% c : number of columns of the signal. (positive integer)
%
% Input Parameters (pairs), (optional):
%
% 'KnotsR'    : knots to consider for the row discretisation of the second
%               derivative, e.g. x-derivative. (array of integers) (default
%               [0,1])
% 'KnotsC'    : knots to consider for the column discretisation of the second
%               derivative, e.g. y-derivative. (array of integers) (default
%               [0,1])
% 'GridSizeR' : size of the grid for rows. (positive double) (default = 1.0)
% 'GridSizeR' : size of the grid for columns. (positive double) (default = 1.0)
% 'Boundary'  : boundary condition. (string) (default = 'Neumann')
% 'Tolerance' : tolerance when checking the consistency order. (default 100*eps)
%
% Output Parameters
%
% M : Matrix of the corresponding scheme. (sparse matrix)
%
% Example
%
% Remarks
%
% The implementation assumes that the points are number row-wise. This is in
% conflict with the standard numbering scheme in MATLAB, which runs column-wise
% over a matrix.
%
% See also LaplaceM, DiffFilter1D, FiniteDiff1DM.

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

% Last revision: 2012/03/14 16:25

%% Comments and Remarks.
%

%% Check input parameters

error(nargchk(2, 14, nargin));
error(nargoutchk(0, 1, nargout));

optargin = size(varargin,2);
stdargin = nargin - optargin;

assert( stdargin == 2, ...
    'LinearAlgebra:GradientM:BadInput', ...
    ['The first two parameters must be the number of rows and columns of ' ...
     'the signal.']);
assert( mod(optargin,2)==0, ...
    'LinearAlgebra:GradientM:BadInput', ...
    'Optional arguments must come in pairs.');

KnotsR = [0 1];
GridSR = 1.0;
KnotsC = [0 1];
GridSC = 1.0;
BoundCond = 'Neumann';
Tol = 100*eps;
for i = 1:2:optargin
    switch varargin{i}
        case 'KnotsR'
            KnotsR = varargin{i+1};
        case 'KnotsC'
            KnotsC = varargin{i+1};
        case 'GridSizeR'
            GridSR = varargin{i+1};
        case 'GridSizeC'
            GridSC = varargin{i+1};
        case 'Boundary'
            BoundCond = varargin{i+1};
        case 'Tolerance'
            Tol = varargin{i+1};
    end
end

%% Set up internal variables.

MR = FiniteDiff1DM(c, KnotsR, 1, ...
    'GridSize', GridSR, 'Boundary', BoundCond, 'Tolerance', Tol);
MC = FiniteDiff1DM(r, KnotsC, 1, ...
    'GridSize', GridSC, 'Boundary', BoundCond, 'Tolerance', Tol);
if r == 1
    M = MR;
elseif c == 1
    M = MC;
else
    M = [ kron(speye(r,r),MR) ; kron(MC,speye(c,c)) ];
end