function [mets, elements, metNrs, atomTransitionNrs, isSubstrate, instances] = readRXNFile(rxnfileName, rxnfileDirectory)
% Read atom mappings from a MDL rxn file.
%
% USAGE:
%
%    [mets, elements, metNrs, atomTransitionNrs, isSubstrate, instances] = readRXNFile(rxnfileName, rxnfileDirectory)
%
% INPUT:
%    rxnfileName:         The file name.
%
% OPTIONAL INPUT:
%    rxnfileDirectory:    Path to directory containing the rxnfile. Defaults
%                         to current directory.
%
% OUTPUTS:
%    mets:                A `p` x 1 cell array of metabolite identifiers for atoms.
%    elements:            A `p` x 1 cell array of element symbols for atoms.
%    metNrs:              A `p` x 1 vector containing the numbering of atoms within
%                         each metabolite molfile.
%    atomTransitionNrs:   A `p` x 1 vector of atom transition indices.
%    isSubstrate:         A `p` x 1 logical array. True for substrates, false for
%                         products in the reaction.
%    instances:           A `p` x 1 vector indicating which instance of a repeated metabolite atom `i` belongs to.
%
% .. Author: - Hulda S. Haraldsdóttir and Ronan M. T. Fleming, 2022

rxnfileName = regexprep(rxnfileName,'(\.rxn)$',''); % Format inputs and remove rxnfile ending from reaction identifier

if ~exist('rxnfileDirectory','var')
    rxnfileDirectory = pwd;
end
% Make sure input path ends with directory separator
rxnfileDirectory = [regexprep(rxnfileDirectory,'(/|\\)$',''), filesep];

% Read reaction file
if strcmp(rxnfileName, '3AIBTm')
    rxnFilePath = [rxnfileDirectory '3AIBtm (Case Conflict).rxn'];
else
    rxnFilePath = [rxnfileDirectory rxnfileName '.rxn'];
end

fileStr = fileread(rxnFilePath); % Read file contents into a string
fileCell = regexp(fileStr, '\$MOL\r?\n', 'split'); % Split file into text blocks

% Get reaction data
headerStr = fileCell{1}; % First block contains reaction data
headerCell = regexp(headerStr, '\r?\n', 'split');

if ~strcmp(headerCell{2}, rxnfileName)
    warning('Reaction identifier in the rxnfile %s.rxn does not match file name.', rxnfileName);
end

rxnFormulaFull = headerCell{4}; % fourth line should contain the reaction formula
rxnFormula = strtrim(regexp(rxnFormulaFull,'<=>|->', 'split'));
leftside = rxnFormula{1};
leftside = strtrim(regexp(leftside, '\+', 'split'));
rightside = rxnFormula{2};
rightside = strtrim(regexp(rightside, '\+', 'split'));

umets = cell(length(leftside) + length(rightside), 1);
s = zeros(length(leftside) + length(rightside), 1);
for i = 1:length(leftside)
    [w1, w2] = strtok(leftside{i});
    if isempty(w2)
        umets{i} = w1;
        s(i) = - 1;
    else
        umets{i} = strtrim(w2);
        s(i) = - str2double(w1);
    end
end
for i = 1:length(rightside)
    [w1,w2] = strtok(rightside{i});
    if isempty(w2)
        umets{i + length(leftside)} = w1;
        s(i + length(leftside)) = 1;
    else
        umets{i + length(leftside)} = strtrim(w2);
        s(i + length(leftside)) = str2double(w1);
    end
end

nReactants = str2double(headerCell{5}(1:3)); % Fifth line is reactant/product line
nProducts = str2double(headerCell{5}(4:6));
if sum(abs(s)) ~= nReactants + nProducts
    hidx = [find(ismember(umets,'h')) strmatch('h[', umets)]; % Atom mapping may not include hydrogen atoms
    s = s(setdiff(1:length(s), hidx));
    umets = umets(setdiff(1:length(umets), hidx));
end

if sum(abs(s)) ~= nReactants + nProducts
    warning('Incorrect reaction formula in the rxnfile %s.', rxnfileName);
end

% Get metabolite data
nAtoms = zeros(size(umets));

mets = {}; % metabolite identifiers
isSubstrate = []; % true for reactants
instances = []; % order with repetitions
elements = {}; % element symbols
metNrs = []; % Atom numbers in metabolites
atomTransitionNrs = []; % Atom numbers in reaction

counter = 1;
for i = 1:length(umets)
    id = umets{i};
    rbool = s(i) < 0;    
    for j = 1:abs(s(i)) % Molfile is repeated abs(s(j)) times
        counter = counter + 1;
        molStr = fileCell{counter}; % Mol block for metabolite
        molCell = regexp(molStr, '\r?\n', 'split');
        %assert(strcmp(strtrim(molCell{1}),regexprep(id,'(\[\w\])$','')),'Metabolite identifiers do not match.'); % First line should be metabolite id without compartment assignment

        nAtoms(i) = str2double(molCell{4}(1:3)); % Fourth line is counts line. First three characters on the line are the number of atoms.

        for k = (1 + 4):(nAtoms(i) + 4)
            atomStr = molCell{k};

            mets = [mets; id];
            isSubstrate = [isSubstrate; rbool];
            instances = [instances; j];
            elements = [elements; strtrim(atomStr(31:33))];
            metNrs = [metNrs; (k - 4)];
            atomTransitionNrs = [atomTransitionNrs; str2double(strtok(atomStr(61:end)))];

        end
    end
end

isSubstrate = logical(isSubstrate);

if mod(length(elements),2)~=0
    fprintf('%s%s%s%s\n',rxnfileName,' ',rxnFormulaFull,' is elementally unbalanced.');
end


%checks specific for atom transitions
if ~all(atomTransitionNrs==0)
    if ~all(sort(atomTransitionNrs(isSubstrate)) == (1:sum(isSubstrate))')
        warning([rxnfileName, '.rxn, Substrate transition numbers not ordered 1:q.\n'])
    end
    if ~all(all(sort(atomTransitionNrs(~isSubstrate)) == (1:sum(~isSubstrate))'))
        warning([rxnfileName, '.rxn, Product transition numbers not ordered 1:q.\n'])
    end
    if ~all(sort(atomTransitionNrs(isSubstrate)) == sort(atomTransitionNrs(~isSubstrate)))
        warning([rxnfileName, '.rxn, Substrate and product transition numbers not matching order 1:q.\n'])
    end
    
    nAtomTransitions = max(atomTransitionNrs);
    matchingElementBool=false(nAtomTransitions,1);
    for i=1:nAtomTransitions
        if strcmp(elements(atomTransitionNrs==i & isSubstrate),elements(atomTransitionNrs==i & ~isSubstrate))
            matchingElementBool(i)=1;
        end
    end
    if ~all(matchingElementBool)
        fprintf('%s%s%s%s%u%s\n',rxnfileName,' ',rxnFormulaFull,' contains ', nnz(~matchingElementBool), ' atom transitions violating elemental conservation.');
    end
end