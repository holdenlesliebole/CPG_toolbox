% Analyze Seaward Sand Deposition (SSD) temporal dynamics
% Calculates SSD time series, rate of change (dSSD/dt), and generates three
% complementary visualizations to understand beach state evolution and forcing mechanisms.
%
% Outputs:
%  1. Stacked time series: SSD(t) cumulative state + dSSD/dt rate of change
%  2. Phase plane: SSD vs dSSD/dt as connected trajectory (reveals attractors/cycles)
%  3. Forcing analysis: dSSD/dt vs significant wave height (mechanism identification)

%% Settings
% 1. Path to CPGMOP data files
mpath='/volumes/group/MOPS/'; % reefbreak on a mac
%mpath='/Users/William/Desktop/MOPS/';

% 2. Mop range to use in volume change calculations
%MopStart=668;MopEnd=682; % start and mop numbers for Cardiff
MopStart=576;MopEnd=590; % start and mop numbers for north TP

% 3. Date range to consider
StartDate=datenum(2022,10,1);
EndDate=datenum(2023,10,31);

% 4. Elevation bin sizes (m) to use when calculating volume change
zRes=0.5; % 0.5 m

% Alongshore reach length (m)
L=100*(MopEnd-MopStart+1);

%% Load combined SG gridded data
SG=CombineSGdata(mpath,MopStart,MopEnd);

%% Identify jumbos with jetskis
jumbo=find(contains({SG.File},'umbo') | contains({SG.File},'etski'));
m=0;
jetski=[];
for j=1:length(jumbo)
    if( min(SG(jumbo(j)).Z) < -3 )
        m=m+1;
        jetski(m)=jumbo(j);
    end       
end

fprintf('The SG struct array has %i Jumbo-Jetski Surveys.\n',numel(jetski))

% Find jetski surveys in the date range
idx=find( [SG(jetski).Datenum] >= StartDate & [SG(jetski).Datenum] <= EndDate);
fprintf('%i Jumbo-Jetski Surveys found in the date range.\n',numel(idx))
jetski=jetski(idx);

%% Create 2D grid from survey data
minx=min(vertcat(SG.X));
maxx=max(vertcat(SG.X));
miny=min(vertcat(SG.Y));
maxy=max(vertcat(SG.Y));
[X,Y]=meshgrid(minx:maxx,miny:maxy);

% Cross-shore width for normalization
W = maxx - minx;

%% Z0 reference grid (first survey)
SurvNum=jetski(1); 
x=SG(SurvNum).X;
y=SG(SurvNum).Y;
idx_pts=sub2ind(size(X),y-miny+1,x-minx+1);
Z0=X*NaN; 
Z0(idx_pts)=SG(SurvNum).Z; 
z0bin=round((Z0-0.774)/zRes); 

%% Calculate SSD time series and dSSD/dt
ssd_vals = zeros(1, length(jetski));
survey_dates = zeros(1, length(jetski));
ssd_vals(1) = 0;
survey_dates(1) = SG(jetski(1)).Datenum;

fprintf('\n--- Seaward Sand Deposition (SSD) Time Series ---\n')
fprintf('Date                   SSD (m)\n')
fprintf('%s              %7.4f\n', datestr(SG(jetski(1)).Datenum), 0)

for n=2:length(jetski)
    SurvNum=jetski(n);
    x=SG(SurvNum).X;
    y=SG(SurvNum).Y;
    idx_pts=sub2ind(size(X),y-miny+1,x-minx+1);
    Z=X*NaN;
    Z(idx_pts)=SG(SurvNum).Z;
    dz=Z-Z0;
    
    % Calculate first moment (SSD)
    mu=0;
    for iz=min(z0bin(:)):max(z0bin(:))
        dv_raw=sum(dz(z0bin==iz),'omitnan');
        if(iz < 0) mu=mu+dv_raw*iz*zRes;end
    end
    mu=round(-mu/(L*W), 4);
    
    ssd_vals(n) = mu;
    survey_dates(n) = SG(jetski(n)).Datenum;
    
    fprintf('%s              %7.4f\n', datestr(SG(jetski(n)).Datenum), mu)
end

%% Calculate dSSD/dt (rate of change)
dssd_dt_vals = zeros(1, length(jetski)-1);  % one fewer value
dssd_dt_days = zeros(1, length(jetski)-1);
dssd_dt_cm_day = zeros(1, length(jetski)-1);
dssd_survey_dates = survey_dates(2:end);  % dates for rate measurements

fprintf('\n--- Rate of Seaward Sand Deposition (dSSD/dt) ---\n')
fprintf('Date Interval                   Days    dSSD/dt (m/day)   dSSD/dt (cm/day)\n')
fprintf('%-34s %6s %17s %17s\n', '---', '---', '---', '---')

for n=1:length(jetski)-1
    dt_days = survey_dates(n+1) - survey_dates(n);
    dssd = ssd_vals(n+1) - ssd_vals(n);
    dssd_dt = dssd / dt_days;  % m/day
    dssd_dt_cm = dssd_dt * 100;  % cm/day
    
    dssd_dt_vals(n) = dssd_dt;
    dssd_dt_days(n) = dt_days;
    dssd_dt_cm_day(n) = dssd_dt_cm;
    
    date_str = sprintf('%s to %s', datestr(survey_dates(n)), datestr(survey_dates(n+1)));
    fprintf('%-34s %6.0f %17.5f %17.3f\n', date_str, dt_days, dssd_dt, dssd_dt_cm)
end

%% Load wave data for Option 3
MopNumber=580;
stn=['D0' num2str(MopNumber)];
urlbase='http://thredds.cdip.ucsd.edu/thredds/dodsC/cdip/model/MOP_alongshore/';
urlend = '_hindcast.nc';
dsurl=strcat(urlbase,stn,urlend);

try
    wavetime=ncread(dsurl,'waveTime');
    hctime=datetime(wavetime,'ConvertFrom','posixTime');
    hchs=ncread(dsurl,'waveHs');
    wave_data_available = true;
    fprintf('\nWave data loaded successfully from CDIP MOP D0580\n')
catch
    fprintf('\nWarning: Could not load wave data. Option 3 will show placeholders.\n')
    wave_data_available = false;
end

%% ===== FIGURE 1: STACKED TIME SERIES =====
figure('position',[50 100 1300 800]);

% Panel A: SSD cumulative state
ax1 = subplot(2,1,1);
plot(datetime(survey_dates,'convertfrom','datenum'), ssd_vals, 'o-', ...
    'linewidth', 2.5, 'markersize', 6, 'color', [0 0.4 0.8]);
hold on
plot(datetime(survey_dates,'convertfrom','datenum'), zeros(size(survey_dates)), 'k--', ...
    'linewidth', 1.5, 'alpha', 0.5)
grid on
ylabel('SSD (m)', 'fontsize', 14)
title('Seaward Sand Deposition (SSD) State Evolution', 'fontsize', 16, 'fontweight', 'bold')
set(gca, 'fontsize', 12)
set(ax1, 'position', [0.1 0.55 0.85 0.4])

% Panel B: dSSD/dt rate of change with color coding
ax2 = subplot(2,1,2);
% Color code: red for offshore (positive), blue for recovery (negative)
colors = zeros(length(dssd_dt_vals), 3);
for k=1:length(dssd_dt_vals)
    if dssd_dt_vals(k) > 0
        % Positive (offshore): scale from light red to dark red
        intensity = min(dssd_dt_vals(k) / max(dssd_dt_vals), 1);
        colors(k,:) = [intensity 0.2 0.2];  % red
    else
        % Negative (recovery): scale from light blue to dark blue
        intensity = min(abs(dssd_dt_vals(k)) / max(abs(dssd_dt_vals)), 1);
        colors(k,:) = [0.2 0.2 intensity];  % blue
    end
end

% Plot bars with colors
dssd_dates_plot = datetime(dssd_survey_dates, 'convertfrom', 'datenum');
bar(dssd_dates_plot, dssd_dt_vals * 100, 'facecolor', 'flat', 'edgecolor', 'none');
ax2.CData = colors;
hold on
plot(datetime(survey_dates,'convertfrom','datenum'), zeros(size(survey_dates)), 'k-', ...
    'linewidth', 1.5)
grid on
ylabel('dSSD/dt (cm/day)', 'fontsize', 14)
xlabel('Survey Date', 'fontsize', 14)
title('Rate of Sand Deposition/Erosion (dSSD/dt)', 'fontsize', 16, 'fontweight', 'bold')
set(gca, 'fontsize', 12)
set(ax2, 'position', [0.1 0.1 0.85 0.4])

% Add legend for color coding
legend_red = patch([NaN NaN], [NaN NaN], [0.8 0.2 0.2]);
legend_blue = patch([NaN NaN], [NaN NaN], [0.2 0.2 0.8]);
legend([legend_red legend_blue], 'Offshore Transport', 'Beach Recovery', ...
    'location', 'bestoutside', 'fontsize', 11);

makepng('SSDDynamics_1_TimeSeries.png')

%% ===== FIGURE 2: PHASE PLANE =====
figure('position',[50 100 1000 900]);

% Plot SSD vs dSSD/dt as trajectory
% Color by time progression
time_progress = 1:length(ssd_vals);
scatter(ssd_vals(1:end-1), dssd_dt_vals*100, 80, time_progress(1:end-1), ...
    'filled', 'marker', 'o', 'cmap', 'jet');
hold on
% Draw connecting lines
plot(ssd_vals(1:end-1), dssd_dt_vals*100, '-', 'color', [0.5 0.5 0.5], ...
    'linewidth', 1.5, 'alpha', 0.5);
% Mark endpoints
plot(ssd_vals(1), 0, 's', 'markersize', 12, 'markerfacecolor', 'green', ...
    'markeredgecolor', 'darkgreen', 'linewidth', 2, 'displayname', 'Start');
plot(ssd_vals(end), dssd_dt_vals(end)*100, '^', 'markersize', 12, ...
    'markerfacecolor', 'red', 'markeredgecolor', 'darkred', 'linewidth', 2, ...
    'displayname', 'End');

grid on
xlabel('SSD - Cumulative Offshore Transport (m)', 'fontsize', 14)
ylabel('dSSD/dt - Rate of Change (cm/day)', 'fontsize', 14)
title('Phase Plane: Beach State Dynamics', 'fontsize', 16, 'fontweight', 'bold')
set(gca, 'fontsize', 12)

% Add zero reference lines
plot(xlim, [0 0], 'k--', 'linewidth', 1.5, 'alpha', 0.5, 'displayname', 'Equilibrium')
ax = gca;
ax.XAxisLocation = 'origin';

% Colorbar
cb = colorbar;
cb.Label.String = 'Time Progression (survey index)';
cb.Label.FontSize = 12;

% Add legend
legend('location', 'bestoutside', 'fontsize', 11);

% Annotate quadrants
text(ax.XLim(2)*0.7, ax.YLim(2)*0.7, 'Offshore \& Accelerating', ...
    'fontsize', 11, 'color', [0.5 0 0], 'fontweight', 'bold', 'alpha', 0.5)
text(ax.XLim(2)*0.7, ax.YLim(1)*0.7, 'Offshore \& Decelerating', ...
    'fontsize', 11, 'color', [0 0 0.5], 'fontweight', 'bold', 'alpha', 0.5)
text(ax.XLim(1)*0.7, ax.YLim(1)*0.7, 'Recovery \& Accelerating', ...
    'fontsize', 11, 'color', [0 0.5 0], 'fontweight', 'bold', 'alpha', 0.5)

makepng('SSDDynamics_2_PhasePlane.png')

%% ===== FIGURE 3: FORCING ANALYSIS (Wave Energy vs Response Rate) =====
figure('position',[50 100 1200 800]);

if wave_data_available
    % Compute mean Hs during each survey interval for forcing estimation
    mean_Hs = zeros(1, length(dssd_dt_vals));
    max_Hs = zeros(1, length(dssd_dt_vals));
    
    for n=1:length(dssd_dt_vals)
        t_start = survey_dates(n);
        t_end = survey_dates(n+1);
        mask = hctime >= datetime(t_start, 'convertfrom', 'datenum') & ...
               hctime <= datetime(t_end, 'convertfrom', 'datenum');
        if sum(mask) > 0
            mean_Hs(n) = nanmean(hchs(mask));
            max_Hs(n) = nanmax(hchs(mask));
        end
    end
    
    % Panel A: dSSD/dt vs Mean Hs
    subplot(1,2,1)
    % Color by sign of dSSD/dt (red=offshore, blue=recovery)
    colors_forcing = zeros(length(dssd_dt_vals), 3);
    for k=1:length(dssd_dt_vals)
        if dssd_dt_vals(k) > 0
            intensity = min(dssd_dt_vals(k) / max(dssd_dt_vals), 1);
            colors_forcing(k,:) = [intensity 0.2 0.2];
        else
            intensity = min(abs(dssd_dt_vals(k)) / max(abs(dssd_dt_vals)), 1);
            colors_forcing(k,:) = [0.2 0.2 intensity];
        end
    end
    
    scatter(mean_Hs, dssd_dt_vals*100, 100, colors_forcing, 'filled', 'o', ...
        'markeredgecolor', 'black', 'linewidth', 1.5);
    hold on
    
    % Add trend line
    p = polyfit(mean_Hs, dssd_dt_vals*100, 1);
    Hs_fit = linspace(min(mean_Hs), max(mean_Hs), 100);
    plot(Hs_fit, polyval(p, Hs_fit), 'k--', 'linewidth', 2.5, 'alpha', 0.7, ...
        'displayname', sprintf('Trend: slope = %.3f cm/day per m Hs', p(1)));
    
    plot(xlim, [0 0], 'k-', 'linewidth', 1.5, 'alpha', 0.5)
    grid on
    xlabel('Mean Hs During Interval (m)', 'fontsize', 13)
    ylabel('dSSD/dt - Response Rate (cm/day)', 'fontsize', 13)
    title('Forcing Response: Mean Wave Height vs SSD Rate', 'fontsize', 14, 'fontweight', 'bold')
    set(gca, 'fontsize', 11)
    legend('location', 'bestoutside', 'fontsize', 10)
    
    % Panel B: dSSD/dt vs Max Hs
    subplot(1,2,2)
    scatter(max_Hs, dssd_dt_vals*100, 100, colors_forcing, 'filled', 'o', ...
        'markeredgecolor', 'black', 'linewidth', 1.5);
    hold on
    
    % Add trend line
    p2 = polyfit(max_Hs, dssd_dt_vals*100, 1);
    Hs_fit2 = linspace(min(max_Hs), max(max_Hs), 100);
    plot(Hs_fit2, polyval(p2, Hs_fit2), 'k--', 'linewidth', 2.5, 'alpha', 0.7, ...
        'displayname', sprintf('Trend: slope = %.3f cm/day per m Hs', p2(1)));
    
    plot(xlim, [0 0], 'k-', 'linewidth', 1.5, 'alpha', 0.5)
    grid on
    xlabel('Max Hs During Interval (m)', 'fontsize', 13)
    ylabel('dSSD/dt - Response Rate (cm/day)', 'fontsize', 13)
    title('Forcing Response: Peak Wave Height vs SSD Rate', 'fontsize', 14, 'fontweight', 'bold')
    set(gca, 'fontsize', 11)
    legend('location', 'bestoutside', 'fontsize', 10)
    
else
    % Placeholder if wave data unavailable
    text(0.5, 0.5, 'Wave data not available - see console output for dSSD/dt values', ...
        'horizontalalignment', 'center', 'fontsize', 14, 'transform', gca('currentaxes').Parent)
end

makepng('SSDDynamics_3_ForcingAnalysis.png')

fprintf('\n=== Analysis Complete ===\n')
fprintf('Three visualization figures generated:\n')
fprintf('  1. SSDDynamics_1_TimeSeries.png - Cumulative SSD and rate of change\n')
fprintf('  2. SSDDynamics_2_PhasePlane.png - State space trajectory\n')
fprintf('  3. SSDDynamics_3_ForcingAnalysis.png - Wave forcing relationships\n')
