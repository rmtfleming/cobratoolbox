function [A,a,D,d,A0] = lrsOutputReadHalfspace(filename)
%read in a V-representation of the positive orthant convex hull of some matrix
%
%INPUT
% filename output from lrs
% https://www.mankier.com/1/lrs#File_Formats
% H-representation
% 
% m is the number of input rows, each being an inequality or equation.
% n is the number of input columns and d=n-1 is the dimension of the input.
% An inequality or equation of the form:
% 
% b + a_1 x_1 + ... + a_d x_d >=  0
% 
% b + a_1 x_1 + ... + a_d x_d =  0
% 
% is input as the line:
% 
% b  a_1 ... a_d
% 
% The coefficients can be entered as integers or rationals in the format x/y. To distinguish an equation a linearity option must be supplied before the begin line (see below).

%OUTPUT
%    A:             matrix of linear equalities :math:`A x =(a)`
%    D:             matrix of linear inequalities :math:`D x \geq (d)`


% EXAMPLE file
% test
% H-representation
% nonnegative 
% begin
% 14 10 integer
% 0 -1 0 0 0 0 0 1 0 0
% 0 1 0 0 0 0 0 -1 0 0
% 0 1 -2 -2 0 0 0 0 0 0
% 0 -1 2 2 0 0 0 0 0 0
% 0 0 1 0 0 -1 -1 0 0 0
% 0 0 -1 0 0 1 1 0 0 0
% 0 0 0 1 -1 1 0 0 0 0
% 0 0 0 -1 1 -1 0 0 0 0
% 0 0 0 0 1 0 1 0 -1 0
% 0 0 0 0 -1 0 -1 0 1 0
% 0 0 1 1 0 0 0 0 0 -1
% 0 0 -1 -1 0 0 0 0 0 1
% 0 0 0 -1 1 -1 0 0 0 0
% 0 0 0 1 -1 1 0 0 0 0
% end

fid = fopen(filename);

% pause(eps)
countRows = 0;
while 1
    tline = fgetl(fid);
    if countRows ~=0
        countRows = countRows + 1;
    end
    if countRows==3
        if isempty(findstr('/', tline))
            scannedLine = sscanf(tline, '%d')';
            nCols = length(scannedLine);
        else
            line = strrep(line, '/', '.');
            scannedLine = sscanf(line, '%f')';
            nCols = length(scannedLine);
        end
    end
    if strcmp(tline, 'begin')
        countRows = 1;
    elseif ~ischar(tline)
        error('Could not read lrs output file.');
    end
    if strcmp(tline,'end')
        break
    end
end
nRows = countRows -3;


% tline = fgetl(fid);
% sscantf_tline = sscanf(tline, '%s');
% if contains(sscantf_tline,'*****')
%     sscantf_tline = strrep(sscantf_tline,'*****','');
%     sscantf_tline = strrep(sscantf_tline,'rational','');
%     nRows = str2num(sscantf_tline);
%     nCols = str2num(sscantf_tline);
% else
%     error('todo')
%     % find the number of rows and columns
%     C = textscan(fid, '%f %f %s', 1);
%     nRows = C{1};
%     nCols = C{2};
% end

fclose(fid);

% pwd
fid = fopen(filename);

while 1
    if strcmp(fgetl(fid), 'begin')
        break;
    end
end
%skip the next row
line = fgetl(fid);

% read rows into a matrix
A = sparse(nRows, nCols);

for r = 1:nRows
    line = fgetl(fid);
    if isempty(findstr('/', line))
        scannedLine = sscanf(line, '%d')';  % added transpose here for reading in LP solutions
        if length(scannedLine)~=nCols
            %for some reason the second integer is not always the number of columns
            A = sparse(nRows, length(scannedLine));
            nCols = length(scannedLine);
        end
        A(r, :) = scannedLine;
    else
        line = strrep(line, '/', '.');
        scannedLine = sscanf(line, '%f')';
        for c = 1:nCols
            M = mod(scannedLine(c), 1);
            if M ~= 0
                F = fix(scannedLine(c));
                scannedLine(c) = F / M;
            else
                scannedLine(c) = int16(scannedLine(c));
            end
        end
        % pause(eps);
    end
end
fclose(fid);

A0 = A;

if nRows ~= nCols || 1
    a = A(:,1);
    A = A(:,2:end);
else
    a = zeros(size(A,1),1);
end

D = [];
d = [];