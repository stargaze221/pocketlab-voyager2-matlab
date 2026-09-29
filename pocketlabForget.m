function pocketlabForget()
%POCKETLABFORGET Delete the saved PocketLab pairing.

pairingFile = fullfile(fileparts(mfilename('fullpath')), ...
    'pocketlab_pairing.mat');

if isfile(pairingFile)
    delete(pairingFile);
    fprintf('PocketLab pairing removed.\n');
else
    fprintf('No saved PocketLab pairing was found.\n');
end
end
