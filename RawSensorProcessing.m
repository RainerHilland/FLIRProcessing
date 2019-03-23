%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Thermal Image Processing
% For FLIR Vue Pro R
%
% Rainer Hilland
% Feb. 20, 2019
%
% Notes:
%  -> Need to have the Atlas MATLAB SDK installed
%  -> For additional information:
%       -> http://130.15.24.88/exiftool/forum/index.php/topic,4898.60.html
%       -> https://www.sno.phy.queensu.ca/~phil/exiftool/#alone
%  -> TODO: add some error handling for professionalism
%       -> Add support for tiff-sequences
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% SETTINGS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Set ImageDir to the location of the images
imageDir = 'C:\Users\rainer.hilland\Desktop\Personal Docs\TestingRawData\2019.02.25';
outputDir = imageDir; % Modify if you want the output files somewhere else
EXIFToolDir = 'C:\EXIF Tool'; % 'cause I don't know how to program

% Should we strip/write EXIF data? 0 - no, 1 - for the first image,
%  2 - for each image
writeEXIF = 2;

% y/n, write the raw sensor values
writeRAW = 0;

% y/n, apply correction specified in function pixelCorrection
% if this is set to 1 then it always writes out the correction
applyCorr = 0;

% this will write out an image w/ scalebar. Units will follow tempUnits,
% and if applyCorr = 1 it will write out the corrected values, if not it
% writes out an image w/ DNs. They're scaled linearly
writeIMG = 0;
colormap bone; % default - large range, good for vis

% set to 'K' or 'C'
tempUnits = 'C';

% Set to 1 to output a text file with filename:timestamp pairs
writeTimeLog = 1; 

% this suppresses image popup on creation
set(0,'DefaultFigureVisible','off');

% push updates to the command window for when you're not writing files
verbose = 1;
interval = 10;

% unused at the moment
testing = 0;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% BODY
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% loads the SDK
if init()~= 1
    error("Problem Loading SDK")
end

cd(imageDir)

if testing == 1
    % do stuff
    
    return
end

% gets a list of .jpg's in the folder
thermalImageList = getThermalImageList(imageDir);

% iterate through each jpg in the folder
for i = 1:length(thermalImageList)
    
    if verbose == 1
        if rem(i, interval) == 0
            fprintf('%i of %i\n',i,length(thermalImageList));
        end
    end
    
    fileName = thermalImageList(i).name;    % get the file info
    [p,n,e] = fileparts(fileName); % separates fname from ext (bad at programming)
    
    imageIn = openThermalImage(fileName); % open the thermal image
    
    if i == 1 || writeEXIF == 2 || writeTimeLog == 1
        
        % gets exif data for constants on the first loop
        imageEXIF = getEXIF(fileName, imageDir, EXIFToolDir);
        constants = getConstants(imageEXIF);
        
        if i == 1 && writeEXIF == 1 || writeEXIF == 2
            
            % if this is the first iteration and wE is set to 1 (write the
            %  EXIF data on first iteration only, write the exif
            % OR if wE is set to 2 (always write), then write
            
            cd(outputDir);
            
            fileOutName = strcat(n,'_EXIF.txt');
            fileOutID = fopen(fileOutName, 'w');
            fprintf(fileOutID,'%s \r\n', imageEXIF);
            fclose(fileOutID);
            
            cd(imageDir);
        end            
            
     
    end
    
    rawSensor = readSensor(imageIn); % get the raw sensor reading
    
    if writeRAW == 1
        
        % writes out the raw sensor reading if asked for
        cd(outputDir);
        fileOutName = strcat(n,'_RAW.txt'); % is a txt the best format?
        csvwrite(fileOutName,rawSensor);
        cd(imageDir);
        
    end
    
    if writeTimeLog == 1
        
        % this writes out timestamps of when each image was taken,
        % this information will likely be necessary for instrument
        % syncing, though can't be sure right now what format makes the
        % most sense
        
        if i == 1
            timeTable = buildTable(length(thermalImageList));
        end
        
        timeTable = newEntry(timeTable, i, imageIn, fileName);
        
        if i == length(thermalImageList)
            cd(outputDir);
            writetable(timeTable,'TimeTable.txt');
            cd(imageDir);
        end
        
    end
    
    if applyCorr == 1
        
        % this applies whatever function is defined in the pixelCorrection
        % function. rn it's using a simplified method of T calculation that
        % assumes target emissivity is 1, and atmospheric transmission is 1
        % (i.e. distance to object = 0)
        % These settings will not be changed for the current project, but
        % the first link in the header to the exiftool forum shows the
        % longer calculations should that change
        cd(outputDir);
        
        imageCorr = pixelCorrection(rawSensor, constants, tempUnits);
        fileOutName = strcat(n,'_CORR.txt');
        csvwrite(fileOutName, imageCorr);
        
        if writeIMG == 1
            
            status = getImage(imageCorr, n);
        
        end
        
        cd(imageDir);
    
    elseif writeIMG == 1
        
        cd(outputDir);
        status = getImage(imageIn, n);
        cd(imageDir);
        
    end
    
    
    status = closeThermalImage(imageIn);   

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% FUNCTIONS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function initStatus = init()

% Loads SDK to communicate with .NET Framework

atPath = getenv('FLIR_Atlas_MATLAB');
atImage = strcat(atPath,'Flir.Atlas.Image.dll');
asmInfo = NET.addAssembly(atImage);

initStatus = 1; % Because I don't know how to make a function that doesn't 
                %  return a variable

end


function [thermalImage] = openThermalImage(fname)

% Takes a file name fname, creates an instance of a ThermalImageFile,
%  and then opens the image. Return: thermalImage

thermalImage = Flir.Atlas.Image.ThermalImageFile;
thermalImage.Open(fname);

end

function [status] = closeThermalImage(thermalImage)

thermalImage.Close();
status = 1;

end


function [rawSensor] = readSensor(thermalImage)

% Takes a ThermalImageFile object as input and returns the raw sensor array

rawSensor = double(thermalImage.ImageProcessing.GetPixelsArray);

end

function thermalImageList = getThermalImageList(direct)

% Lists all the jpgs in the current folder

cd(direct);
thermalImageList = dir('*.jpg');

end

function [exif] = getEXIF(fname, imageDir, EXIFToolDir)

% Navigate to the exif tool directory and run the exiftool through cmd

cd(EXIFToolDir);
fileLocation = string(strcat('"',imageDir, '\', fname,'"'));

[~,exifChar] = system(strcat("perl exiftool ",fileLocation));

exif = splitlines(string(exifChar));

cd(imageDir);
    
end

function [constants] = getConstants(exif)

% This gets the constants(?) from the exif data and returns a structure
% called constants which can be dot-indexed. Similar method can be used to
% pick up the precise time info if you want that (though this data seems to
% be accessible from the metadata accessible through Atlas SDK

% K after further testing it looks like these are constants. For this
% script it makes more sense probably to manually define these constants at
% the beginning, so work on that.

% Also if you ever used this for a different imager there's no guarantee
% that these constants will occur on the same lines - you're not parsing
% this text, just picking lines out that you already know are correct. 

R1 = split(exif(72)); 
R1 = double(R1(end));

B = split(exif(73));
B = double(B(end));

F = split(exif(74));
F = double(F(end));

O = split(exif(99));
O = double(O(end));

R2 = split(exif(100));
R2 = double(R2(end));

constants = struct('R1',R1,'R2',R2,'B',B,'F',F,'O',O);

end

function [timeTable] = newEntry(tableIn, index, imageIn, fName)

time = imageIn.DateTime;

entry = {fName, time.Year, time.Month, time.Day, time.DayOfYear, ...
    time.Hour, time.Minute, time.Second, time.Millisecond, time.Kind};

tableIn(index,:) = entry;

timeTable = tableIn; % lol this is such a mess. I think this copies the whole 
% tabel in memory each iteration, which slows things down

end

function [timeTable] = buildTable(n)

sz = [n 10];
varNames = {'File','Year','Month','Day','YD','Hour','Minute','Second', ...
    'Millisecond','TZ'};
varTypes = {'string','double','double','double','double','double', ...
    'double','double','double','string'};                
timeTable = table('Size',sz,'VariableTypes',varTypes,'VariableNames',varNames);

end

function [imageCorr] = pixelCorrection(rawSensor, constants, tempUnits)

% right now this just applies that first equation that lets you back out
% the temps that the camera calculates, assuming emissivity is 1, and 
% distance is 0

% set this to the correction you want to do (if simple enough to do so)
if tempUnits == 'K'
    fun = @(x)constants.B/log(constants.R1/(constants.R2*(x+constants.O))+1);
else
    fun = @(x)constants.B/log(constants.R1/(constants.R2*(x+constants.O))+1) - 273.15;
end

imageCorr = arrayfun(fun, rawSensor);

end


function [status] = getImage(imageIn, n)

fileName = strcat(n, '_IMG.png');
image(imageIn, 'CDataMapping','Scaled');
colorbar;
set(gca,'XTick',[], 'YTick', []);

saveas(gcf,fileName);

status = 1;

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%




