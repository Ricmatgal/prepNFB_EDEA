function [onsets]=flicker_RightLeft_ce_Gabor_neglect(subID, projFolder, fullScreen,usingMRI)

% function for localizer task via prepNFB.

arguments

    subID = '99';
    projFolder = 'C:\Users\gallir\Documents\OpenNFT\projects\NFB_EDEA_MRI';
    fullScreen = 1;
    usingMRI = 0;

end

sca;

% functions
enumerate = @(values) [1:length(values); values];

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
black = BlackIndex(screenNumber);

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

[screenXpixels, screenYpixels] = Screen('WindowSize', window); % Get the size of the on screen window
[xCenter, yCenter]             = RectCenter(windowRect); % Get the centre coordinate of the window

% get the gabor images filenames and N
filenames = dir(imPath);filenames = {filenames([filenames.isdir] == 0).name};
filenamesN = length(filenames);

% read the images and prepare textures
gabor_textures = cell(filenamesN,1);
gabor_images = cell(filenamesN,1);

for i = 1:length(filenames)
    filename = filenames{i};
    [gabor_images{i},~,~]   = imread([imPath,filename]);
    gabor_textures{i} = Screen('MakeTexture', window, gabor_images{i});
end

condition_names = {'Left VF - Center FIX', 'Right VF - Center FIX', 'Bilateral VF - Center FIX'...
   'Left VF - Left FIX', 'Right VF - Left FIX', 'Bilateral VF - Left FIX', ...
   'Left VF - Right FIX', 'Right VF - Right FIX', 'Bilateral VF - Right FIX'};

color_names = {'white','red','green'};

% experimental randomization (take into account 0.5 sec of pause between trials)
present_time = 10; % secs
nRepetition = 3;
pres_sequence = [repelem(1,nRepetition) repelem(2,nRepetition) repelem(7,nRepetition) ...
    repelem(3,nRepetition) repelem(4,nRepetition) repelem(8,nRepetition) ... 
    repelem(5,nRepetition) repelem(6,nRepetition) repelem(9,nRepetition)];
% presentation sequence 1:left-center 2:right-center 3:left-left 4:right-left 5:left-right 6:right-right 7:bilat-center
% 8:bilat-left 9:bilat-right

color_change = [repelem(1, (nRepetition*9)/3) repelem(2, (nRepetition*9)/3) repelem(3, (nRepetition*9)/3)];
color_change = color_change(randperm(length(color_change)));
% 1 : white 2 : red 3: green


% pres_sequence = pres_sequence(randperm(length(pres_sequence))); %
% presentation sequence randomized, if needed

% rectangle for wheel - including scaling of image with proportions kept
[s1, s2, ~]  = size(gabor_images{1,1});
aspectratio   = s2/s1; %to preserve aspect ratio and not stretch image when resizing

% We will set the height of each drawn image to a fraction of the screens height
heightScalers = 0.35;
imageHeights  = screenYpixels .* heightScalers;
imageWidths   = imageHeights .* aspectratio;

% images and cross fixed location
n_positions = 7; % 3 crosses and 2 figures per cross
cross_positions_index = [2,4,6];
yPos = yCenter; % always at middle of screen height
xPos = linspace(screenXpixels * 0.1, screenXpixels * 0.9,n_positions); 
cross_positions_value = [xPos(2),xPos(4),xPos(6)]; % left, center, right
dstRects = nan(3,2,4); % 3 fixation and two stimulation side with 4 coordinates
theRect = [0 0 imageWidths imageHeights]; % dimension of rectangle where to display image

for i = enumerate(cross_positions_index) % the positions of the cross
    index = i(1);
    position = i(2);
    dstRects(index,1,:) = CenterRectOnPointd(theRect, xPos(position-1), yPos); % left
    dstRects(index,2,:) = CenterRectOnPointd(theRect, xPos(position+1), yPos); % right
end


% Fixation Cross
% Set up alpha-blending for smooth (anti-aliased) lines
Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

% Here we set the size of the arms of our fixation cross
fixCrossDimPix = 30;

% Now we set the coordinates (these are all relative to zero we will let
% the drawing routine center the cross in the center of our monitor for us)
xCoords = [-fixCrossDimPix fixCrossDimPix 0 0];
yCoords = [0 0 -fixCrossDimPix fixCrossDimPix];
cross_coords = [xCoords; yCoords];

% Set the line width for our fixation cross
lineWidthPix = 4;
topPriorityLevel = MaxPriority(window);
Priority(topPriorityLevel);

Screen('DrawLines', window, cross_coords,...
    lineWidthPix, [255 255 255], [xCenter yCenter], 2); % for some reason white is not taken..
Screen('Flip', window);

% wait for MRI trigger
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

[a,b,c,d,e,f,g,h,i] = deal(1); % set counters for the presentation conditions

time_to_present = present_time/filenamesN; % presentation_time/number of images

rsp = struct; % answers struct

ons = []; % onsets

for trial = 1:numel(pres_sequence) % for each trial

    condition = pres_sequence(trial); % stimulation condition code
    color = color_change(trial); % color of the cross condition code

    rsp(trial).trial = trial;
    rsp(trial).condition = condition_names{condition};
    rsp(trial).color = color_names{color};

    switch color

        case 1

            color_cross = [255,255,255]; % white
            record_answer = 0;
            rsp(trial).response_expected = 0;

        case 2

            color_cross = [255,0,0]; % red
            keyChosen = "1!";
            keyAnswer = KbName(convertStringsToChars(keyChosen));
            KbCheckList = keyAnswer;
            RestrictKeysForKbCheck(KbCheckList); % other keys are ignored
            record_answer = 1;
            rsp(trial).response_expected = 1;


        case 3

            color_cross = [0,255,0]; % green
            keyChosen = "2@";
            keyAnswer = KbName(convertStringsToChars(keyChosen));
            KbCheckList = keyAnswer;
            RestrictKeysForKbCheck(KbCheckList); % other keys are ignored
            record_answer = 1;
            rsp(trial).response_expected = 1;

    end

    switch condition % presentation sequence (stimulus and fix) 1:left-center 2:right-center 3:left-left 4:right-left 5:left-right 6:right-right

        case 1 %left stimulus, center fixation

        [a,last_pos] = show_trial_uni(a,cross_positions_value(2),2,record_answer,1);

        case 2 %right stimulus, center fixation

        [b,last_pos] = show_trial_uni(b,cross_positions_value(2),2,record_answer,2);

        case 3 %left stimulus, left fixation

        [c,last_pos] = show_trial_uni(c,cross_positions_value(1),1,record_answer,1);

        case 4 %right stimulus, left fixation

        [d,last_pos] = show_trial_uni(d,cross_positions_value(1),1,record_answer,2);

        case 5 %left stimulus, right fixation

        [e,last_pos] = show_trial_uni(e,cross_positions_value(3),3,record_answer,1);

        case 6 %right stimulus, right fixation

        [f,last_pos] = show_trial_uni(f,cross_positions_value(3),3,record_answer,2);

        case 7 %bilateral stimulus, center fixation

        [g,last_pos] = show_trial_bil(g,cross_positions_value(2),2,record_answer);

        case 8 %bilateral stimulus, left fixation

        [h,last_pos] = show_trial_bil(h,cross_positions_value(1),1,record_answer);

        case 9 %bilateral stimulus, right fixation

        [i,last_pos] = show_trial_bil(i,cross_positions_value(3),3,record_answer);

    end

    Screen('DrawLines', window, cross_coords,...
    lineWidthPix, [255 255 255], [last_pos yCenter], 2); % for some reason white is not taken..
    Screen('Flip', window);

end

fprintf('TOTAL TIME: %f secs \n', GetSecs - startIRM);
sca;
clearvars a b c d e f g h i


%% Saving

% create onset matrix
durations = {present_time,present_time,present_time,present_time,present_time,present_time,present_time,present_time,present_time}; %presentation time
[onsets]= cell(1,9);
for i = 1:size(ons,1)
    onsets{i} = cell2mat(num2cell(ons(i,:)));
end

% saving
filename = fullfile(rootPathData,'Onsets_SPM.mat');
filename_csv = fullfile(rootPathData,'localizer_results.csv');
save(filename, 'condition_names', 'durations', 'onsets');
fprintf(['\n SPM_onset file saved in: ', '%s \n'],rootPathData);
writetable(struct2table(rsp),filename_csv);
fprintf(['\n localizer results saved in: ', '%s \n'],rootPathData);


    function [counter,fixation_pos] = show_trial_uni(counter,fixation_pos,fixation_index,record_answer,side)

        Screen('DrawLines', window, cross_coords,...
        lineWidthPix, [255 255 255], [fixation_pos yCenter], 2);
        Screen('Flip', window);
        WaitSecs(2.5);

        flip_time = GetSecs;
        timestamp = flip_time-startIRM;
        ons(condition,counter) = timestamp;
        fprintf('ONSET RECORDED: %f FOR CONDITION %s WITH CROSS COLOR %s\n',timestamp,condition_names{condition},color_names{color})
        counter = counter+1;


        for texture = gabor_textures'

            Screen('DrawLines', window, cross_coords,...
                lineWidthPix, color_cross, [fixation_pos yCenter], 2);
            Screen('DrawTextures', window, texture{1,1}, [],...
                reshape(dstRects(fixation_index, side, :),[2,2]), [], [], []);
            Screen('Flip', window);

            t0 = GetSecs;
            if record_answer && (GetSecs - t0 < time_to_present) 
                [keyIsDown, ~, keyCode, ~] = KbCheck;
                if keyIsDown % if a response is given
                    fprintf('KEY PRESSED \n')
                    rsp(trial).response = KbName(keyCode); % get response and overwrite
                    record_answer = 0; % no timedout
                end
            end
        end

        Screen('DrawLines', window, cross_coords,...
        lineWidthPix, [255 255 255], [fixation_pos yCenter], 2);
        Screen('Flip', window);
        WaitSecs(2.5);

    end

    function [counter,fixation_pos] = show_trial_bil(counter,fixation_pos,fixation_index,record_answer)

        Screen('DrawLines', window, cross_coords,...
        lineWidthPix, [255 255 255], [fixation_pos yCenter], 2);
        Screen('Flip', window);
        WaitSecs(2.5);

        flip_time = GetSecs;
        timestamp = flip_time-startIRM;
        ons(condition,counter) = timestamp;
        fprintf('ONSET RECORDED: %f FOR CONDITION %s WITH CROSS COLOR %s\n',timestamp,condition_names{condition},color_names{color})
        counter = counter+1;


        for texture = gabor_textures'

            Screen('DrawLines', window, cross_coords,...
                lineWidthPix, color_cross, [fixation_pos yCenter], 2);
            Screen('DrawTextures', window, texture{1,1}, [],...
                reshape(dstRects(fixation_index, 1, :),[2,2]), [], [], []);
            Screen('DrawTextures', window, texture{1,1}, [],...
                reshape(dstRects(fixation_index, 2, :),[2,2]), [], [], []);
            Screen('Flip', window);

            t0 = GetSecs;
            if record_answer && (GetSecs - t0 < time_to_present) 
                [keyIsDown, ~, keyCode, ~] = KbCheck;
                if keyIsDown % if a response is given
                    fprintf('KEY PRESSED \n')
                    rsp(trial).response = KbName(keyCode); % get response and overwrite
                    record_answer = 0; % no timedout
                end
            end
        end

        Screen('DrawLines', window, cross_coords,...
        lineWidthPix, [255 255 255], [fixation_pos yCenter], 2);
        Screen('Flip', window);
        WaitSecs(2.5);

    end


end