function out = PdeM(c,varargin)
%Matrix corresponding to the PDE considered in this framework.

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

% Last revision on: 10.09.2012 11:55

narginchk(1, 2);
nargoutchk(0, 1);

[row col] = size(c);
D = LaplaceM(row, col, ...
    'KnotsR',[-1 0 1],'KnotsC',[-1 0 1], ...
    'Boundary', 'Neumann');

out = Mask(c(:)) - (speye(length(c(:))) - Mask(c(:)))*D;

end