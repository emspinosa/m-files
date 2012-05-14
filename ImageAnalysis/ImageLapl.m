function out = ImageLapl( in, varargin )
%% Computes the Laplacian on an image.
%
% out = ImageLapl( in, varargin )
%
% Input parameters (required):
%
% in : input image (matrix).
%
% Input parameters (optional):
%
% Optional parameters are either struct with the following fields and
% corresponding values or option/value pairs, where the option is specified as a
% string.
%
% xSettings : either a structure or a cell array containing the optional
%             parameters that will be passed to ImageDxx to compute the 2nd x
%             derivative of the input image.
% ySettings : either a structure or a cell array containing the optional
%             parameters that will be passed to ImageDyy to compute the 2nd y
%             derivative of the input image.
%
% Output parameters:
%
% out : an array with the same size as the input containing the laplacian at
%       each point.
%
% Description:
%
% Computes the Laplacian of an input signal using a finite difference scheme.
%
% Example:
%
% I = rand(512,256)
% xSettings.scheme = 'scharr';
% ySettings = { 'scheme', 'backward', 'gridSize', [1.5 1.5] };
% ImageLapl(I, xSettings, ySettings)
%
% See also ImageDxx, ImageDyy

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

% Last revision on: 30.04.2012 07:00

%% Check Input and Output Arguments

% asserts that there's at least 1 input parameter.
error(nargchk(1, max(nargin,0), nargin));
error(nargoutchk(0, 1, nargout));

parser = inputParser;
parser.FunctionName = mfilename;
parser.CaseSensitive = false;
parser.KeepUnmatched = true;
parser.StructExpand = true;

parser.addRequired('in', @(x) validateattributes( x, {'numeric'}, ...
    {'2d', 'finite', 'nonempty', 'nonnan'}, ...
    mfilename, 'in', 1) );

parser.addParamValue('xSettings', struct([]), @(x) isstruct(x)||iscell(x) );
parser.addParamValue('ySettings', struct([]), @(x) isstruct(x)||iscell(x) );

parser.parse(in,varargin{:});
opts = parser.Results;

%% Algorithm

out = ImageDxx(in,opts.xSettings) + ImageDyy(in,opts.ySettings);
end