% Alongshore-averaged Eulerian anomaly movie
% This version averages anomalies across the selected MOP range and
% plots a time-evolving alongshore-mean profile (by contour) plus net volume.

clear all

%% USER SETTINGS - MODIFY THESE
MopStart = 576;  % Start of mop range
MopEnd   = 590;  % End of mop range

% Date range for analysis and wave data
dateStart = datenum(2022, 10, 1);  % Start date for analysis
dateEnd   = datenum(2025, 12, 31); % End date for analysis

% Running mean window (odd number of months) for mean seasonal MOP profiles
SeasonalAvgWindow = 3;

% Wave data monthly moving mean window (days)
WaveMovingMeanWindow = 30;  % 30-day moving average for Hs

%----------------------

%% Load wave data for the MOP range midpoint
MopMidpoint = round((MopStart + MopEnd) / 2);
targetMOP = sprintf('D%04d', MopMidpoint);

fprintf('Loading wave data for %s (midpoint of Mop %d-%d)...\n', targetMOP, MopStart, MopEnd);
try
    % Convert datenums to datetime for read_MOPline2
    dt1 = datetime(dateStart, 'ConvertFrom', 'datenum');
    dt2 = datetime(dateEnd, 'ConvertFrom', 'datenum');
    
    MOP = read_MOPline2(targetMOP, dt1, dt2);
    
    % Extract time and Hs from struct
    timeW_dt = MOP.time(:);  % datetime array
    Hs = MOP.Hs(:);
    
    % Convert datetime to datenum for compatibility with survey dates
    if isdatetime(timeW_dt)
        timeW = datenum(timeW_dt);
    else
        timeW = timeW_dt;  % already datenum
    end

    % Sort wave time series chronologically to keep plots ordered
    [timeW, widx] = sort(timeW);
    Hs = Hs(widx);

    % Calculate monthly moving mean of Hs on sorted data
    Hs_monthly = movmean(Hs, WaveMovingMeanWindow*24, 'omitnan');  % Convert days to hours
    
    fprintf('Wave data loaded successfully (%d data points).\n', length(timeW));
    waveDataAvailable = true;
catch ME
    fprintf('Warning: Could not load wave data. Top panel will show dates only.\n');
    fprintf('Error: %s\n', ME.message);
    waveDataAvailable = false;
end

load MopTableUTM.mat

MopNumbers   = MopStart:MopEnd;
NumMopPoints = length(MopNumbers);
GS.MopNumbers = MopNumbers;

% Loop through Mop SM mat files
mm = 0;
dc = 0.5;              % contour spacing
cont_levels = -9:dc:2; % contour levels (MSL)
for m = MopStart:MopEnd  % Mop number loop
    mm = mm+1;

    % load mop SM mat file
    load([ 'M'  num2str( m , '%5.5i' )  'SM.mat' ],'SM');
    load([ 'M'  num2str( m , '%5.5i' )  'GM.mat' ],'GM');

    fprintf('Loaded: %s %i\n',[ 'M'  num2str( m , '%5.5i' )  'SM.mat' ],size(SM,2));

    cnum = 0;
    for ElvMsl = cont_levels   % elevation contour loop
        cnum = cnum+1;
        Elv = ElvMsl+0.774; % convert to navd88

        % get global mean and seasonal mean profile Elv locations for this mop
        clear gx gsx

        % global Elv location(s)
        idx = find(GM.Z1Dmean >= Elv-0.5*dc & GM.Z1Dmean < Elv+0.5*dc);
        if isempty(idx)
            gx.x = NaN;
        else
            gx.x = round(GM.X1D(idx));
        end

        % seasonal mean Elv location(s)
        for mon = 1:12
            dm = (SeasonalAvgWindow-1)/2;
            mons = mon-dm:mon+dm;
            mons(mons < 1)  = mons(mons < 1) + 12;
            mons(mons > 12) = mons(mons > 12) - 12;
            Zsm = nanmean(reshape([GM.MM(mons).Z1Dmean],[length(GM.MM(1).Z1Dmean),SeasonalAvgWindow]),2);
            idx = find(Zsm >= Elv-0.5*dc & Zsm < Elv+0.5*dc);
            if isempty(idx)
                gsx.MM(mon).x = NaN;
            else
                gsx.MM(mon).x = GM.MM(mon).X1D(idx);
            end
        end

        % step through survey dates
        for n = 1:size(SM,2)
            sdate = SM(n).Datenum;
            mon   = month(datetime(datestr(sdate))); % survey month
            stype = SM(n).Source;

            % anomaly relative to global mean profile
            idx = find(ismember(round(SM(n).X1D),gx.x));
            ganom = nanmean(SM(n).Z1Dmean(idx)-Elv)*length(idx);
            % anomaly relative to global mean seasonal profile
            idx = find(ismember(round(SM(n).X1D),gsx.MM(mon).x));
            gsanom = nanmean(SM(n).Z1Dmean(idx)-Elv)*length(idx);

            if m == MopStart && n == 1
                idx = [];
            else
                idx = find([Anom.Datenum] == sdate & strcmpi({Anom.Source}, stype)==1);
            end

            if isempty(idx)
                if m == MopStart && n == 1
                    nn=1;
                else
                    nn=size(Anom,2)+1;
                end
                Anom(nn).Datenum  = sdate;
                Anom(nn).Source   = stype;
                Anom(nn).Global   = ganom;
                Anom(nn).Seasonal = gsanom;
                Anom3D(nn,cnum,mm)= Anom(nn).Seasonal;
            else
                Anom(idx).Global   = ganom;
                Anom(idx).Seasonal = gsanom;
                Anom3D(idx,cnum,mm)= Anom(idx).Seasonal;
            end
        end
    end
end

%%
d = [Anom.Datenum]; % survey dates in array
[sd,id] = sort(d);  % sorted survey dates
jumbo = find(nansum(abs(squeeze(Anom3D(:,5,:))),2) > 0); % jumbo dates

% Filter survey dates to date range and keep them sorted
date_mask = (sd >= dateStart & sd <= dateEnd);
if ~any(date_mask)
    warning('No surveys found in specified date range. Using all available dates.');
    id_filtered = id;  % use all surveys
    sd_filtered = sd;
else
    fprintf('Found %d surveys in date range.\n', sum(date_mask));
    id_filtered = id(date_mask);
    sd_filtered = sd(date_mask);
end

% Also filter jumbo for wave plot x-axis limits (and sort by date)
jumbo_filtered = jumbo(d(jumbo) >= dateStart & d(jumbo) <= dateEnd);
if isempty(jumbo_filtered)
    jumbo_filtered = jumbo;  % fallback to all if none in range
end
jumbo_dates = d(jumbo_filtered);
[jumbo_dates, jf_sort] = sort(jumbo_dates);
jumbo_filtered = jumbo_filtered(jf_sort);

%% Figure + movie
nf = 0;
clear M
figure('units','normalized','outerposition',[0 0 1 1],'menu','none');

% panel geometry
ax_width = 0.72;
ax_left  = 0.1;
colorbar_width = 0.04; % (unused here but kept for consistency)
ax1_width = ax_width;
ax1_height = 0.10;
ax2_height = 0.52;
ax3_height = 0.18;
ax1_bottom = 0.87;
ax2_bottom = 0.28;
ax3_bottom = 0.08;

for ids = 1:length(id_filtered)
    if (nansum(abs(Anom3D(id_filtered(ids),5,:))) > 0)
        nf = nf+1;
        clf

        % Alongshore-mean anomaly for this date
        a1_mean = squeeze(nanmean(Anom3D(id_filtered(ids),:,:),3)); % contour dimension
        total_vol = nansum(a1_mean); % net volume anomaly (m^3/m-shore summed over contours)

        % Top panel: Wave height time series with survey dates
        ax1=axes('position',[ax_left ax1_bottom ax1_width ax1_height]);
        if waveDataAvailable
            plot(timeW, Hs_monthly, 'b-', 'linewidth', 1.5);
            hold on;
            set(ax1,'xlim',[min(sd_filtered) max(sd_filtered)]);
            for jj = 1:length(jumbo_filtered)
                [~, tidx] = min(abs(timeW - jumbo_dates(jj)));
                if ~isempty(tidx)
                    plot(jumbo_dates(jj), Hs_monthly(tidx), 'k.', 'markersize', 10);
                end
            end
            [~, tidx_curr] = min(abs(timeW - sd_filtered(ids)));
            if ~isempty(tidx_curr)
                plot(sd_filtered(ids), Hs_monthly(tidx_curr), 'r.', 'markersize', 20);
            end
            ylabel('Hs (m)', 'fontsize', 10);
            datetick('x', 'mmm yyyy', 'keeplimits');
            grid on;
            title(sprintf('%d-day Moving Mean Significant Wave Height', WaveMovingMeanWindow), ...
                'fontsize', 10, 'fontweight', 'normal');
        else
            set(ax1,'xlim',[min(sd_filtered) max(sd_filtered)],'ylim',[-1 1]);
            plot(sd_filtered,0*sd_filtered,'k.','markersize',10);hold on;
            plot(sd_filtered(ids),0,'r.','markersize',20);
            set(ax1,'ytick',[]);
            datetick('x', 'mmm yyyy', 'keeplimits');
        end
        text(sd_filtered(ids), max(get(ax1,'ylim'))*0.95, datestr(sd_filtered(ids)), ...
            'horizontalalign','center','fontweight','bold','color','r','fontsize',11);

        % Middle panel: alongshore-mean contour anomalies (profile)
        ax2=axes('position',[ax_left ax2_bottom ax_width ax2_height]);
        plot(a1_mean, cont_levels, 'b-', 'linewidth', 2);
        hold on; plot([0 0],[cont_levels(1) cont_levels(end)],'k--','linewidth',1.5);
        grid on;
        xlabel('Contour Xshore Vol Anom (m^3/m-shore)');
        ylabel('Seasonal Mean Contour Elevation (m,MSL)');
        title(sprintf('%s - Mop %d to %d (Alongshore Mean)', datestr(sd_filtered(ids)), MopStart, MopEnd));
        set(gca,'ylim',[cont_levels(1) cont_levels(end)]);

        % Bottom panel: net volume anomaly (scalar)
        ax3=axes('position',[ax_left ax3_bottom ax_width ax3_height]);
        set(gca,'xlim',[0 1],'ylim',[-310 310]); grid on; hold on;
        plot([0 1],[0 0],'k--','linewidth',2);
        bar_color = 'b';
        if total_vol < 0
            bar_color = 'r';
        end
        b = bar(0.5, total_vol, 0.4, 'FaceColor', bar_color, 'EdgeColor', bar_color);
        xlabel('Alongshore Mean');
        ylabel({'Total Xshore Vol','Anom (m^3/m-shore)'});
        box on;
        text(0.5, total_vol*0.9, sprintf('%+.0f', total_vol), 'horizontalalign','center','fontweight','bold');

        % Capture frame with consistent size
        frame = getframe(gcf);
        if nf == 1
            frameSize = size(frame.cdata);
            M(nf) = frame;
        else
            if ~isequal(size(frame.cdata), frameSize)
                M(nf).cdata = imresize(frame.cdata, frameSize(1:2));
                M(nf).colormap = frame.colormap;
            else
                M(nf) = frame;
            end
        end
    end
end

% Only create video if frames were captured
if exist('M', 'var') && ~isempty(M)
    videoFilename = sprintf('Mop%d-%dAnomalySeasonal_alongshoreMean.mp4', MopStart, MopEnd);
    v=VideoWriter(videoFilename,'MPEG-4');
    v.FrameRate=1;
    open(v)
    writeVideo(v,M)
    close(v)
    fprintf('Video saved as: %s\n', videoFilename);
else
    fprintf('No frames captured. Video not created.\n');
end
