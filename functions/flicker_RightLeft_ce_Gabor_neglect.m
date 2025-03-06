function [onsets]=flicker_RightLeft_ce_Gabor_neglect(subID, projFolder, fullScreen,usingMRI)

% function for localizer task via prepNFB.

arguments

    subID = '99';
    projFolder = 'C:\Users\gallir\Documents\OpenNFT\projects\NFB_EDEA_MRI';
    fullScreen = 1;
    usingMRI = 0;

end

sca;

% directories
rootPath     = pwd; % needs to be dir where prep_NFB is run from.. if run as intended this should not be a problem.
imPath       = [rootPath, filesep, 'Images_Localizer', filesep, 'gabor_wheels', filesep]; % images path
rootPathData = [projFolder, filesep, subID, filesep, 'Localizer', filesep, 'beh', filesep]; % where the onsets will be saved


% Psychtoolbox settings
PsychDefaultSetup(2)
Screen('Preference', 'Verbosity', 0);
Screen('Preference', 'SkipSyncTests',1);
Screen('Preference', 'VisualDebugLevel',0);
Screen('Preference', 'ScreenToHead', 0, 1, 1);

% screen and colors
screens      = Screen('Screens');
screenNumber = max(screens);
white = WhiteIndex(screenNumber);
black = BlackIndex(screenNumber);
grey = white / 2;

% only for debugging
if ~ usingMRI
    screenNumber = 2;
end

% fullscreen or not
if fullScreen
    [window, windowRect]           = Screen('OpenWindow', screenNumber, black, []);
else
    [window, windowRect]           = Screen('OpenWindow', screenNumber, black, [40 40 640 520]);
end


ifi = Screen('GetFlipInterval', window);

[screenXpixels, screenYpixels] = Screen('WindowSize', window); % Get the size of the on screen window
[xCenter, yCenter]             = RectCenter(windowRect); % Get the centre coordinate of the window

% get the gabor images filenames and N
filenames = dir(imPath);
filenames = {filenames([filenames.isdir] == 0).name};
filenamesN = length(filenames);

% read the images and prepare textures
gabor_images = cell(0);
alpha_gabor_images = cell(0);
our_textures = cell(0);

for filename = filenames
    [gabor_images{end+1},~, alpha_gabor_images{end+1}]   = imread([imPath,filename{1,1}]);
end

for gabor = gabor_images
    our_textures{end+1}   = Screen('MakeTexture', window, gabor{1,1});
end

% experimental randomization (take into account 0.5 sec of pause between trials)
present_time = 1; % secs
nRepetition = 2;
pres_sequence = [repelem(1,nRepetition) repelem(2,nRepetition) repelem(3,nRepetition) ...
    repelem(4,nRepetition) repelem(5,nRepetition) repelem(6,nRepetition) ...
    repelem(7,nRepetition) repelem(8,nRepetition) repelem(9,nRepetition)];
color_change = [repelem(1, (nRepetition*9)/3) repelem(2, (nRepetition*9)/3) repelem(3, (nRepetition*9)/3)];
% 1 : white 2 : red 3: green

% presentation sequence 1:left-center 2:right-center 3:left-left 4:right-left 5:left-right 6:right-right 7:bilat-center
% 8:bilat-left 9:bilat-right
% pres_sequence = pres_sequence(randperm(length(pres_sequence))); % presentation sequence randomized


% rectangle for wheel - including scaling of image with proportions kept
[s1, s2, ~]  = size(gabor_images{1,1});
aspectratio   = s2/s1; %to preserve aspect ratio and not stretch image when resizing

% We will set the height of each drawn image to a fraction of the screens height
heightScalers = 0.35;
imageHeights  = screenYpixels .* heightScalers;
imageWidths   = imageHeights .* aspectratio;

% images positioning
n_items = 7; % 3 crosses and 2 figures per cross
yPos = yCenter;
xPos = linspace(screenXpixels * 0.1, screenXpixels * 0.9,n_items);
dstRects = nan(3,2,4); % 3 fixation and two stimulation side
enumerate = @(values) [1:length(values); values];
theRect = [0 0 imageWidths imageHeights]; % dimension of rectangle where to display image

for i = enumerate([2,4,6])
    dstRects(i(1),1,:) = CenterRectOnPointd(theRect, xPos(i(2)-1), yPos);
    dstRects(i(1),2,:) = CenterRectOnPointd(theRect, xPos(i(2)+1), yPos);
end

% adjusted using Soraya function for distance
% [solution_in_cm_mirror,solution_in_cm_stimuliscreen,solution_in_pixel_stimuliscreen] = compute_distance_readable_from_screen_center_overt_fmri(50,60, 6.45, 3);
% distanceStimuli = solution_in_pixel_stimuliscreen;

% dstRects(:,1) = CenterRectOnPointd(theRect, xCenter -  distanceStimuli , yPos); % left according to fixation point
% dstRects(:,2) = CenterRectOnPointd(theRect, xCenter +  distanceStimuli , yPos); % right according to fixation point

% dstRects(:,1) = CenterRectOnPointd(theRect, xPos(1), yPos); % left according to fixation point
% dstRects(:,2) = CenterRectOnPointd(theRect, xPos(2), yPos); % right according to fixation point


% Fixation Cross
% Set up alpha-blending for smooth (anti-aliased) lines
Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

% Here we set the size of the arms of our fixation cross
fixCrossDimPix = 30;

% Now we set the coordinates (these are all relative to zero we will let
% the drawing routine center the cross in the center of our monitor for us)
xCoords = [-fixCrossDimPix fixCrossDimPix 0 0];
yCoords = [0 0 -fixCrossDimPix fixCrossDimPix];
CROSSCoords = [xCoords; yCoords];

% Set the line width for our fixation cross
lineWidthPix = 4;
topPriorityLevel = MaxPriority(window);
Priority(topPriorityLevel);

% wait for MRI trigger
Screen('DrawLines', window, CROSSCoords,...
    lineWidthPix, [255 255 255], [xCenter yCenter], 2); % for some reason white is not taken..
Screen('Flip', window);
disp('Waiting for MRI trigger')

wait4me = 0;
while wait4me == 0

    [~, ~, keyCode]=KbCheck;
    rsp=KbName(keyCode);

    if ~(isempty(rsp))

        if strcmp(rsp,'5%')==1

            wait4me=1;
            startIRM=GetSecs;
        end
    end
end
disp('Starting experiment')

%% MRI settings

if usingMRI
    parportAddr = hex2dec('2FD8');
    config_io;
    % Set condition code to zero:
    outp( parportAddr, 0);
    % Set automatic BIOPAC and eye tracker recording to "stop":
    outp( parportAddr+2, bitset(inp( parportAddr+2), 3, 0));
end


%% Experimental routine

[a,b,c,d,e,f,g,h,i] = deal(1);
timeToPresent = present_time/filenamesN; % presentation_time/number of images
rsp = struct;

names = {'Left VF - Center FIX', 'Right VF - Center FIX', 'Left VF - Left FIX', ...
    'Right VF - Left FIX', 'Left VF - Right FIX', 'Right VF - Right FIX', 'Bilateral VF - Center FIX', ...
    'Bilateral VF - Left FIX', 'Bilateral VF - Right FIX'};

color_names = {'white','red','green'};

Screen('DrawLines', window, CROSSCoords,...
    lineWidthPix, [255 255 255], [xCenter yCenter], 2); % for some reason white is not taken..
Screen('Flip', window);
WaitSecs(1);
last_pos = xPos(4);

for l = 1:numel(pres_sequence)

    j = pres_sequence(l);
    k = color_change(l);

    Screen('DrawLines', window, CROSSCoords,...
        lineWidthPix, [255 255 255], [last_pos yCenter], 2); % for some reason white is not taken..
    Screen('Flip', window);
    WaitSecs(1);

    switch k

        case 1

            color_cross = [255,255,255]; % white
            record_answer = 0;
            rsp(l).response_expected = 0;

        case 2

            color_cross = [255,0,0]; % red
            keyChosen = "1!";
            keyAnswer = KbName(convertStringsToChars(keyChosen));
            KbCheckList = [keyAnswer];
            RestrictKeysForKbCheck(KbCheckList); % other keys are ignored
            record_answer = 1;
            rsp(l).response_expected = 1;


        case 3

            color_cross = [0,255,0]; % green
            keyChosen = "2@";
            keyAnswer = KbName(convertStringsToChars(keyChosen));
            KbCheckList = [keyAnswer];
            RestrictKeysForKbCheck(KbCheckList); % other keys are ignored
            record_answer = 1;
            rsp(l).response_expected = 1;

    end

    switch j % presentation sequence (stimulus and fix) 1:left-center 2:right-center 3:left-left 4:right-left 5:left-right 6:right-right

        case 1 %left stimulus, center fixation

            flip_time = GetSecs;
            timestamp = flip_time-startIRM;
            ons(j,a) = timestamp;
            fprintf(['ONSET RECORDED: %f FOR CONDITION %s WITH CROSS COLOR %s\n'],timestamp,names{j},color_names{k})
            a = a+1;

            for texture = our_textures

                Screen('DrawTextures', window, texture{1,1}, [],...
                    reshape(dstRects(2, 1, :),[2,2]), [], [], []);
                Screen('DrawLines', window, CROSSCoords,...
                    lineWidthPix, color_cross, [xPos(4) yCenter], 2);
                Screen('Flip', window);
                % WaitSecs(timeToPresent); % secs/nStim
                t0 = GetSecs;
                if record_answer && (GetSecs - t0 < timeToPresent) 
                    fprintf('INSIDE LOOP \n')
                    [keyIsDown, ~, keyCode, ~] = KbCheck;
                    if keyIsDown % if a response is given
                        fprintf('KEY PRESSED \n')
                        rsp(l).response = KbName(keyCode); % get response and overwrite
                        record_answer = 0; % no timedout
                    end
                end
            end

            last_pos = xPos(4);

        case 2 %right stimulus, center fixation

            flip_time = GetSecs;
            timestamp = flip_time-startIRM;
            ons(j,b) = timestamp;
            fprintf(['ONSET RECORDED: %f FOR CONDITION %s WITH CROSS COLOR %s\n'],timestamp,names{j},color_names{k})
            b = b+1;

            for texture = our_textures

                Screen('DrawTextures', window, texture{1,1}, [],...
                    reshape(dstRects(2, 2, :),[2,2]), [], [], []);
                Screen('DrawLines', window, CROSSCoords,...
                    lineWidthPix, color_cross, [xPos(4) yCenter], 2);
                Screen('Flip', window);
                % WaitSecs(timeToPresent); % secs/nStim
                t0 = GetSecs;
                if record_answer && (GetSecs - t0 < timeToPresent) 
                    fprintf('INSIDE LOOP \n')
                    [keyIsDown, ~, keyCode, ~] = KbCheck;
                    if keyIsDown % if a response is given
                        fprintf('KEY PRESSED \n')
                        rsp(l).response = KbName(keyCode); % get response and overwrite
                        record_answer = 0; % no timedout
                    end
                end
            end

            last_pos = xPos(4);

        case 3 %left stimulus, left fixation

            flip_time = GetSecs;
            timestamp = flip_time-startIRM;
            ons(j,c) = timestamp;
            fprintf(['ONSET RECORDED: %f FOR CONDITION %s WITH CROSS COLOR %s\n'],timestamp,names{j},color_names{k})
            c = c+1;

            for texture = our_textures

                Screen('DrawTextures', window, texture{1,1}, [],...
                    reshape(dstRects(1, 1, :),[2,2]), [], [], []);
                Screen('DrawLines', window, CROSSCoords,...
                    lineWidthPix, color_cross, [xPos(2)  yCenter], 2);
                Screen('Flip', window);
                % WaitSecs(timeToPresent); % secs/nStim
                t0 = GetSecs;
                if record_answer && (GetSecs - t0 < timeToPresent) 
                    fprintf('INSIDE LOOP \n')
                    [keyIsDown, ~, keyCode, ~] = KbCheck;
                    if keyIsDown % if a response is given
                        fprintf('KEY PRESSED \n')
                        rsp(l).response = KbName(keyCode); % get response and overwrite
                        record_answer = 0; % no timedout
                    end
                end
            end

            last_pos = xPos(2);

        case 4 %right stimulus, left fixation

            flip_time = GetSecs;
            timestamp = flip_time-startIRM;
            ons(j,d) = timestamp;
            fprintf(['ONSET RECORDED: %f FOR CONDITION %s WITH CROSS COLOR %s\n'],timestamp,names{j},color_names{k})
            d = d+1;

            for texture = our_textures

                Screen('DrawTextures', window, texture{1,1}, [],...
                    reshape(dstRects(1, 2, :),[2,2]), [], [], []);
                Screen('DrawLines', window, CROSSCoords,...
                    lineWidthPix, color_cross, [xPos(2)  yCenter], 2);
                Screen('Flip', window);
                % WaitSecs(timeToPresent); % secs/nStim
                t0 = GetSecs;
                if record_answer && (GetSecs - t0 < timeToPresent) 
                    fprintf('INSIDE LOOP \n')
                    [keyIsDown, ~, keyCode, ~] = KbCheck;
                    if keyIsDown % if a response is given
                        fprintf('KEY PRESSED \n')
                        rsp(l).response = KbName(keyCode); % get response and overwrite
                        record_answer = 0; % no timedout
                    end
                end
            end

            last_pos = xPos(2);

        case 5 %left stimulus, right fixation

            flip_time = GetSecs;
            timestamp = flip_time-startIRM;
            ons(j,e) = timestamp;
            fprintf(['ONSET RECORDED: %f FOR CONDITION %s WITH CROSS COLOR %s\n'],timestamp,names{j},color_names{k})
            e = e+1;

            for texture = our_textures

                Screen('DrawTextures', window, texture{1,1}, [],...
                    reshape(dstRects(3, 1, :),[2,2]), [], [], []);
                Screen('DrawLines', window, CROSSCoords,...
                    lineWidthPix, color_cross, [xPos(6)  yCenter], 2);
                Screen('Flip', window);
                % WaitSecs(timeToPresent); % secs/nStim
                t0 = GetSecs;
                if record_answer && (GetSecs - t0 < timeToPresent) 
                    fprintf('INSIDE LOOP \n')
                    [keyIsDown, ~, keyCode, ~] = KbCheck;
                    if keyIsDown % if a response is given
                        fprintf('KEY PRESSED \n')
                        rsp(l).response = KbName(keyCode); % get response and overwrite
                        record_answer = 0; % no timedout
                    end
                end
            end

            last_pos = xPos(6);

        case 6 %right stimulus, right fixation

            flip_time = GetSecs;
            timestamp = flip_time-startIRM;
            ons(j,f) = timestamp;
            fprintf(['ONSET RECORDED: %f FOR CONDITION %s WITH CROSS COLOR %s\n'],timestamp,names{j},color_names{k})
            f = f+1;

            for texture = our_textures

                Screen('DrawTextures', window, texture{1,1}, [],...
                    reshape(dstRects(3, 2, :),[2,2]), [], [], []);
                Screen('DrawLines', window, CROSSCoords,...
                    lineWidthPix, color_cross, [xPos(6)  yCenter], 2);
                Screen('Flip', window);
                % WaitSecs(timeToPresent); % secs/nStim
                t0 = GetSecs;
                if record_answer && (GetSecs - t0 < timeToPresent) 
                    fprintf('INSIDE LOOP \n')
                    [keyIsDown, ~, keyCode, ~] = KbCheck;
                    if keyIsDown % if a response is given
                        fprintf('KEY PRESSED \n')
                        rsp(l).response = KbName(keyCode); % get response and overwrite
                        record_answer = 0; % no timedout
                    end
                end
            end

            last_pos = xPos(6);

        case 7 %bilateral stimulus, center fixation

            flip_time = GetSecs;
            timestamp = flip_time-startIRM;
            ons(j,g) = timestamp;
            fprintf(['ONSET RECORDED: %f FOR CONDITION %s WITH CROSS COLOR %s\n'],timestamp,names{j},color_names{k})
            g = g+1;

            for texture = our_textures

                Screen('DrawTextures', window, texture{1,1}, [],...
                    reshape(dstRects(2, 1, :),[2,2]), [], [], []);
                Screen('DrawTextures', window, texture{1,1}, [],...
                    reshape(dstRects(2, 2, :),[2,2]), [], [], []);
                Screen('DrawLines', window, CROSSCoords,...
                    lineWidthPix, color_cross, [xPos(4)  yCenter], 2);
                Screen('Flip', window);
                % WaitSecs(timeToPresent); % secs/nStim
                t0 = GetSecs;
                if record_answer && (GetSecs - t0 < timeToPresent) 
                    fprintf('INSIDE LOOP \n')
                    [keyIsDown, ~, keyCode, ~] = KbCheck;
                    if keyIsDown % if a response is given
                        fprintf('KEY PRESSED \n')
                        rsp(l).response = KbName(keyCode); % get response and overwrite
                        record_answer = 0; % no timedout
                    end
                end
            end

            last_pos = xPos(4);

        case 8 %bilateral stimulus, left fixation

            flip_time = GetSecs;
            timestamp = flip_time-startIRM;
            ons(j,h) = timestamp;
            fprintf(['ONSET RECORDED: %f FOR CONDITION %s WITH CROSS COLOR %s\n'],timestamp,names{j},color_names{k})
            h = h+1;

            for texture = our_textures

                Screen('DrawTextures', window, texture{1,1}, [],...
                    reshape(dstRects(1, 1, :),[2,2]), [], [], []);
                Screen('DrawTextures', window, texture{1,1}, [],...
                    reshape(dstRects(1, 2, :),[2,2]), [], [], []);
                Screen('DrawLines', window, CROSSCoords,...
                    lineWidthPix, color_cross, [xPos(2)  yCenter], 2);
                Screen('Flip', window);
                % WaitSecs(timeToPresent); % secs/nStim
                t0 = GetSecs;
                if record_answer && (GetSecs - t0 < timeToPresent) 
                    fprintf('INSIDE LOOP \n')
                    [keyIsDown, ~, keyCode, ~] = KbCheck;
                    if keyIsDown % if a response is given
                        fprintf('KEY PRESSED \n')
                        rsp(l).response = KbName(keyCode); % get response and overwrite
                        record_answer = 0; % no timedout
                    end
                end
            end

            last_pos = xPos(2);

        case 9 %bilateral stimulus, right fixation

            flip_time = GetSecs;
            timestamp = flip_time-startIRM;
            ons(j,i) = timestamp;
            fprintf(['ONSET RECORDED: %f FOR CONDITION %s WITH CROSS COLOR %s\n'],timestamp,names{j},color_names{k})
            i = i+1;

            for texture = our_textures

                Screen('DrawTextures', window, texture{1,1}, [],...
                    reshape(dstRects(3, 1, :),[2,2]), [], [], []);
                Screen('DrawTextures', window, texture{1,1}, [],...
                    reshape(dstRects(3, 2, :),[2,2]), [], [], []);
                Screen('DrawLines', window, CROSSCoords,...
                    lineWidthPix, color_cross, [xPos(6)  yCenter], 2);
                Screen('Flip', window);
                % WaitSecs(timeToPresent); % secs/nStim
                t0 = GetSecs;
                if record_answer && (GetSecs - t0 < timeToPresent) 
                    fprintf('INSIDE LOOP \n')
                    [keyIsDown, ~, keyCode, ~] = KbCheck;
                    if keyIsDown % if a response is given
                        fprintf('KEY PRESSED \n')
                        rsp(l).response = KbName(keyCode); % get response and overwrite
                        record_answer = 0; % no timedout
                    end
                end
            end

            last_pos = xPos(6);

    end

end

fprintf('TOTAL TIME: %f secs \n', GetSecs - startIRM);

Screen('DrawLines', window, CROSSCoords,...
    lineWidthPix, [255 255 255], [last_pos yCenter], 2); % for some reason white is not taken..
Screen('Flip', window);
WaitSecs(1);
sca;


%% Saving

%create onset matrix

durations = {present_time,present_time,present_time,present_time,present_time,present_time,present_time,present_time,present_time}; %presentation time

[onsets]= cell(1,9);

for k = 1:size(ons,1)

    onsets{k} = cell2mat(num2cell(ons(k,:)));

end

filename = fullfile(rootPathData,'Onsets_SPM.mat');
filename_csv = fullfile(rootPathData,'localizer_results.csv');
save(filename, 'names', 'durations', 'onsets');
fprintf(['\n SPM_onset file saved in: ', '%s \n'],rootPathData);
writetable(struct2table(rsp),filename_csv);
fprintf(['\n localizer results saved in: ', '%s \n'],rootPathData);

end