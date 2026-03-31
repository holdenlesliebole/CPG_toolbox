function CompareONItoWaveMetrics(mopNumber)
% CompareONItoWaveMetrics
%   Compares ONI (Oceanic Niño Index) to three key wave metrics:
%   1. Hours per month above 2.5m Hs
%   2. Maximum 12-hour averaged Hs per month
%   3. Three-month accumulated energy flux anomaly
%
%   Wave data is fetched directly from CDIP thredds server using read_MOPline2
%   for the full historical period (1990 to present).
%
% Usage:
%   CompareONItoWaveMetrics(582)     % MOP 582 (Torrey Pines)
%   CompareONItoWaveMetrics()         % defaults to MOP 582

    if nargin < 1 || isempty(mopNumber)
        mopNumber = 582;  % Torrey Pines focus
    end

    % ====================================================================
    % FETCH ONI
    % ====================================================================
    fprintf('\nFetching ONI from CPC...\n');
    try
        oni = fetchONI_CPC_robust();
        fprintf('  Loaded %d ONI months (%s to %s).\n', ...
            numel(oni.time), datestr(oni.time(1)), datestr(oni.time(end)));
    catch ME
        warning('Failed to fetch ONI: %s', ME.message);
        oni = struct('time', datetime.empty(0,1), 'val', []);
    end

    % ====================================================================
    % LOAD WAVE DATA DIRECTLY USING read_MOPline2
    % ====================================================================
    fprintf('\nFetching wave spectral data using read_MOPline2...\n');
    
    % MOP name for Torrey Pines (convert mopNumber to MOP name)
    mopName = sprintf('D%04d', mopNumber);
    
    % Try progressively more recent start dates if hindcast unavailable
    % CDIP hindcast coverage is typically 2000–present
    dateRanges = {
        [datetime(1990, 1, 1, 'TimeZone', 'UTC'), datetime('now', 'TimeZone', 'UTC')], ...
        [datetime(2000, 1, 1, 'TimeZone', 'UTC'), datetime('now', 'TimeZone', 'UTC')], ...
        [datetime(2010, 1, 1, 'TimeZone', 'UTC'), datetime('now', 'TimeZone', 'UTC')] ...
    };
    
    MOP = [];
    for d = 1:numel(dateRanges)
        dt1 = dateRanges{d}(1);
        dt2 = dateRanges{d}(2);
        
        try
            fprintf('  Attempting %s (%s to %s)...\n', mopName, datestr(dt1), datestr(dt2));
            MOP = read_MOPline2(mopName, dt1, dt2);
            fprintf('  ✓ Loaded wave data successfully.\n');
            break;
        catch ME
            fprintf('  ✗ Failed for %s: %s\n', datestr(dt1), ME.message);
            if d == numel(dateRanges)
                error('Could not fetch wave data for %s in any date range. Check MOP number and network connectivity.', mopName);
            end
        end
    end
    
    fprintf('  Wave data loaded for %s (%s to %s)\n', mopName, datestr(dt1), datestr(dt2));
    
    t_wave = MOP.time(:);
    wavehs = MOP.Hs(:);
    
    % Compute energy flux from 1D spectrum and frequency
    freq = MOP.frequency(:);
    spec1D = MOP.spec1D;  % time x frequency
    
    % Group velocity at reference depth (use MOP.depth if available)
    if isfield(MOP, 'depth')
        depth = MOP.depth;
    else
        depth = 5;  % default 5m depth
    end
    
    [~, ~, Cg] = LinearDispersion(freq', depth);
    Cg = repmat(Cg(:), [1 numel(t_wave)])';  % repeat for each time step
    
    % Energy flux = integral of S(f)*Cg(f) df (approximate dot product)
    fbw = MOP.fbw;  % Frequency bandwidth
    if isscalar(fbw)
        df = fbw;
    else
        df = mean(diff(freq));
    end
    
    EfluxTS = (spec1D .* Cg) * df;  % sum across frequencies, scale by bandwidth
    
    fprintf('  Wave time range: %s to %s (%d samples)\n', ...
        datestr(t_wave(1)), datestr(t_wave(end)), numel(t_wave));

    % ====================================================================
    % COMPUTE WAVE METRICS ON ROLLING 3-MONTH WINDOW (one point per month)
    % ====================================================================
    fprintf('\nComputing wave metrics (rolling 3-month window for every month)...\n');

    % Create time vector for computation: monthly intervals
    t_monthly = dateshift(min(t_wave), 'start', 'month'):calmonths(1):dateshift(max(t_wave), 'end', 'month');
    t_monthly = t_monthly(:);

    tMon = [];          % Month label
    hsHours25 = [];     % Hours above 2.5 m Hs in 3-mo window ending this month
    hsMax12h = [];      % Max 12-h Hs in 3-mo window
    efluxAnom = [];     % 3-month accumulated energy flux

    for i = 1:numel(t_monthly)
        t_end_month = t_monthly(i);
        t_start_month = t_end_month - calmonths(3);  % 3 months before

        % Find samples in this 3-month window
        idx_window = t_wave >= t_start_month & t_wave <= t_end_month;

        if nnz(idx_window) < 10
            continue;  % Skip if insufficient data
        end

        hs_win = wavehs(idx_window);
        eflux_win = EfluxTS(idx_window);

        % 1. Hours above 2.5 m Hs
        nHours_above25 = nnz(hs_win > 2.5);

        % 2. Maximum 12-hour averaged Hs
        if numel(hs_win) >= 12
            hs12h = movmax(hs_win, 12, 'EndPoints', 'shrink');
            max_hs12 = max(hs12h);
        else
            max_hs12 = max(hs_win);
        end

        % 3. Three-month accumulated energy flux
        eflux_accum = sum(eflux_win, 'omitnan');

        tMon = [tMon; t_end_month];          %#ok<AGROW>
        hsHours25 = [hsHours25; nHours_above25];     %#ok<AGROW>
        hsMax12h = [hsMax12h; max_hs12];             %#ok<AGROW>
        efluxAnom = [efluxAnom; eflux_accum];        %#ok<AGROW>
    end

    % Compute anomalies relative to climatology
    efluxClim = mean(efluxAnom, 'omitnan');
    efluxAnom_detrend = efluxAnom - efluxClim;

    fprintf('  Computed %d 3-month windows.\n', numel(tMon));

    % ====================================================================
    % MAP ONI TO SAME TIME GRID
    % ====================================================================
    if ~isempty(oni.time)
        oniAtMon = oniForSurveyTimes(tMon, oni.time, oni.val);
    else
        oniAtMon = nan(size(tMon));
    end

    % ====================================================================
    % PLOT 1: Time series with ENSO background shading
    % ====================================================================
    fig1 = figure('Name', 'Wave Metrics vs ONI', 'Position', [100 100 1200 800]);
    tl = tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    % Panel A: Hours > 2.5m Hs
    ax1 = nexttile;
    plot(tMon, hsHours25, 'o-', 'LineWidth', 1.5, 'MarkerSize', 6, 'Color', [0 0.6 1]);
    grid on; box on;
    ylabel('Hours/3-mo above 2.5m Hs', 'Interpreter', 'tex');
    title('Wave Metrics vs ONI (Torrey Pines)', 'FontSize', 14, 'FontWeight', 'bold');
    if ~isempty(oni.time)
        shadeENSO(ax1, oni.time, oni.val);
    end

    % Panel B: Max 12-hour Hs
    ax2 = nexttile;
    plot(tMon, hsMax12h, 'o-', 'LineWidth', 1.5, 'MarkerSize', 6, 'Color', [1 0.4 0]);
    grid on; box on;
    ylabel('Max 12-h Hs (m)', 'Interpreter', 'tex');
    if ~isempty(oni.time)
        shadeENSO(ax2, oni.time, oni.val);
    end

    % Panel C: Energy flux anomaly
    ax3 = nexttile;
    plot(tMon, efluxAnom_detrend, 'o-', 'LineWidth', 1.5, 'MarkerSize', 6, 'Color', [0.6 0 0.8]);
    yline(0, 'k--', 'LineWidth', 0.5);
    grid on; box on;
    xlabel('Time (years)', 'Interpreter', 'tex');
    ylabel('3-mo Energy Flux Anomaly (m^3/s)', 'Interpreter', 'tex');
    if ~isempty(oni.time)
        shadeENSO(ax3, oni.time, oni.val);
    end

    % Link x-axes
    linkaxes([ax1, ax2, ax3], 'x');

    % Add ENSO colorbar
    addENSOColorbar(fig1, [-3 3]);

    exportgraphics(fig1, 'WaveMetrics_vs_ONI_TimeSeries.png', 'Resolution', 300);

    % ====================================================================
    % PLOT 2: Scatter plots (zero-lag correlation)
    % ====================================================================
    valid = ~isnan(oniAtMon) & ~isnan(hsHours25) & ~isnan(hsMax12h) & ~isnan(efluxAnom_detrend);

    if nnz(valid) >= 8
        fig2 = figure('Name', 'Scatter: Wave metrics vs ONI', 'Position', [150 150 1100 350]);
        tl2 = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

        % A. Hours > 2.5m vs ONI
        ax2a = nexttile;
        scatter(oniAtMon(valid), hsHours25(valid), 60, 'b', 'filled', 'MarkerFaceAlpha', 0.6);
        [r1, p1] = corr(oniAtMon(valid), hsHours25(valid));
        hold on;
        lsline;
        grid on; box on;
        xlabel('ONI (°C)', 'Interpreter', 'tex');
        ylabel('Hours/3-mo > 2.5m Hs', 'Interpreter', 'tex');
        title(sprintf('r=%.3f, p=%.4f', r1, p1), 'FontSize', 11);

        % B. Max 12-h Hs vs ONI
        ax2b = nexttile;
        scatter(oniAtMon(valid), hsMax12h(valid), 60, 'r', 'filled', 'MarkerFaceAlpha', 0.6);
        [r2, p2] = corr(oniAtMon(valid), hsMax12h(valid));
        hold on;
        lsline;
        grid on; box on;
        xlabel('ONI (°C)', 'Interpreter', 'tex');
        ylabel('Max 12-h Hs (m)', 'Interpreter', 'tex');
        title(sprintf('r=%.3f, p=%.4f', r2, p2), 'FontSize', 11);

        % C. Energy flux anomaly vs ONI
        ax2c = nexttile;
        scatter(oniAtMon(valid), efluxAnom_detrend(valid), 60, 'm', 'filled', 'MarkerFaceAlpha', 0.6);
        [r3, p3] = corr(oniAtMon(valid), efluxAnom_detrend(valid));
        hold on;
        lsline;
        grid on; box on;
        xlabel('ONI (°C)', 'Interpreter', 'tex');
        ylabel('3-mo Energy Flux Anom. (m^3/s)', 'Interpreter', 'tex');
        title(sprintf('r=%.3f, p=%.4f', r3, p3), 'FontSize', 11);

        exportgraphics(fig2, 'WaveMetrics_vs_ONI_Scatter.png', 'Resolution', 300);
    end

    % ====================================================================
    % PRINT SUMMARY STATISTICS
    % ====================================================================
    fprintf('\n=== SUMMARY STATISTICS ===\n');
    fprintf('Hours > 2.5m Hs/3-mo: mean=%.1f, std=%.1f, min=%.1f, max=%.1f\n', ...
        mean(hsHours25, 'omitnan'), std(hsHours25, 'omitnan'), ...
        min(hsHours25), max(hsHours25));
    fprintf('Max 12-h Hs (m): mean=%.2f, std=%.2f, min=%.2f, max=%.2f\n', ...
        mean(hsMax12h, 'omitnan'), std(hsMax12h, 'omitnan'), ...
        min(hsMax12h), max(hsMax12h));
    fprintf('3-mo Energy Flux Anom (m^3/s): mean=%.2e, std=%.2e\n', ...
        mean(efluxAnom_detrend, 'omitnan'), std(efluxAnom_detrend, 'omitnan'));

    if ~isempty(oni.time) && nnz(valid) >= 8
        fprintf('\n=== ZERO-LAG CORRELATIONS WITH ONI ===\n');
        fprintf('Hours > 2.5m Hs vs ONI:   r=%+.3f, p=%.4f\n', r1, p1);
        fprintf('Max 12-h Hs vs ONI:      r=%+.3f, p=%.4f\n', r2, p2);
        fprintf('Energy Flux Anom vs ONI: r=%+.3f, p=%.4f\n', r3, p3);
    end

    % Return data table for further analysis
    resultsTable = table(tMon, hsHours25, hsMax12h, efluxAnom, efluxAnom_detrend, oniAtMon, ...
        'VariableNames', {'Time', 'HoursAbove2p5m', 'Max12hHs', 'EnergyFlux3mo', ...
        'EnergyFluxAnomaly', 'ONI'});
    
    save('WaveMetrics_vs_ONI_Results.mat', 'resultsTable', 'tMon', 'hsHours25', 'hsMax12h', ...
        'efluxAnom', 'efluxAnom_detrend', 'oniAtMon', 'oni');
    
    fprintf('\n✓ Results saved to WaveMetrics_vs_ONI_Results.mat\n');
end


%% ========================= HELPER FUNCTIONS ============================

function oni = fetchONI_CPC_robust()
% Fetch ONI from CPC ASCII file

    url = 'https://www.cpc.ncep.noaa.gov/data/indices/oni.ascii.txt';
    txt = webread(url);
    [t, v] = parseONI_ascii(txt);

    if isempty(t)
        error('Parsed ONI returned empty. CPC format may have changed.');
    end

    oni.time = t(:);
    oni.val  = v(:);
end

function [t, v] = parseONI_ascii(txt)
% Parse ONI ASCII format: SEAS YR TOTAL ANOM

    lines = regexp(txt, '\r\n|\n|\r', 'split');

    t = datetime.empty(0,1);
    v = [];

    seasonToMonth = containers.Map( ...
        {'DJF','JFM','FMA','MAM','AMJ','MJJ','JJA','JAS','ASO','SON','OND','NDJ'}, ...
        num2cell(1:12) );

    for i = 1:numel(lines)
        L = strtrim(lines{i});
        if isempty(L); continue; end

        if startsWith(L, 'SEAS', 'IgnoreCase', true)
            continue;
        end

        parts = strsplit(L);

        if numel(parts) < 4
            continue;
        end

        ssn = parts{1};
        if ~isKey(seasonToMonth, ssn)
            continue;
        end

        yr   = str2double(parts{2});
        anom = str2double(parts{4});

        if isnan(yr) || isnan(anom)
            continue;
        end

        mo = seasonToMonth(ssn);
        t(end+1,1) = datetime(yr, mo, 15);  %#ok<AGROW>
        v(end+1,1) = anom;                  %#ok<AGROW>
    end
end

function shadeENSO(ax, tONI, vONI)
% Shade El Niño/La Niña periods

    if isempty(tONI) || isempty(vONI) || ~isvalid(ax)
        return;
    end

    % Remove timezone from tONI for comparison compatibility
    if ~isempty(tONI(1).TimeZone)
        tONI_naive = datetime(tONI, 'TimeZone', '');
    else
        tONI_naive = tONI;
    end

    xL = ax.XLim;
    if isnumeric(xL)
        tMin = datetime(xL(1), 'ConvertFrom', 'datenum');
        tMax = datetime(xL(2), 'ConvertFrom', 'datenum');
        useDatenumPatch = true;
    else
        tMin = xL(1);
        tMax = xL(2);
        useDatenumPatch = false;
    end

    % Ensure tMin/tMax are also naive for comparison
    if ~isempty(tMin.TimeZone)
        tMin = datetime(tMin, 'TimeZone', '');
    end
    if ~isempty(tMax.TimeZone)
        tMax = datetime(tMax, 'TimeZone', '');
    end

    idx = (tONI_naive >= dateshift(tMin,'start','month')) & (tONI_naive <= dateshift(tMax,'end','month'));
    t = tONI_naive(idx);  % Use naive version to match axis data without timezone
    v = vONI(idx);
    if isempty(t); return; end

    yL = ax.YLim;
    ax.YLimMode = 'manual';
    hold(ax, 'on');

    % Determine axis timezone from first plotted datetime at XLim
    if ~isempty(tMin.TimeZone)
        axisTimeZone = tMin.TimeZone;
    else
        axisTimeZone = '';
    end

    for i = 1:numel(t)
        if v(i) >= 0.5
            col = [1 0 0];
        elseif v(i) <= -0.5
            col = [0 0 1];
        else
            continue;
        end

        t0 = dateshift(t(i), 'start', 'month');
        t1 = dateshift(t(i), 'end', 'month') + days(1);
        
        % Apply axis timezone to patch datetimes for compatibility
        if ~isempty(axisTimeZone)
            t0 = datetime(t0, 'TimeZone', axisTimeZone);
            t1 = datetime(t1, 'TimeZone', axisTimeZone);
        end

        a = min(abs(v(i)), 2.5);
        alpha = 0.10 + 0.45*(a/2.5);

        yPatch = [yL(1) yL(1) yL(2) yL(2)];
        if useDatenumPatch
            xPatch = datenum([t0 t1 t1 t0]);
        else
            xPatch = [t0 t1 t1 t0];
        end

        p = patch(ax, xPatch, yPatch, col, ...
            'EdgeColor', 'none', 'FaceAlpha', alpha, 'HandleVisibility', 'off');

        try, uistack(p, 'bottom'); catch, end
    end

    ylim(ax, yL);
end

function addENSOColorbar(figHandle, climVals)
% Add ENSO colorbar to figure

    if nargin < 2 || isempty(climVals)
        climVals = [-3 3];
    end

    delete(findall(figHandle, 'Type', 'ColorBar'));
    delete(findall(figHandle, 'Type', 'Axes', 'Tag', 'ENSOColorbarAxes'));

    axCB = axes(figHandle, 'Position', [0.90 0.15 0.001 0.70], ...
        'Tag', 'ENSOColorbarAxes', 'Visible', 'off');

    colormap(axCB, redbluecmap(256));
    clim(axCB, climVals);

    cb = colorbar(axCB);
    cb.Position = [0.92 0.15 0.02 0.70];
    cb.Ticks = ceil(climVals(1)):1:floor(climVals(2));
    cb.Label.String = 'ONI (°C)';
    cb.Label.Interpreter = 'tex';
end

function oniAtSurvey = oniForSurveyTimes(tSurvey, tONI, vONI)
% Map each survey time to ONI value for that month

    tSurvey = tSurvey(:);
    
    % Remove timezones for consistent comparison
    if ~isempty(tONI(1).TimeZone)
        tONI = datetime(tONI, 'TimeZone', '');
    end
    if ~isempty(tSurvey(1).TimeZone)
        tSurvey = datetime(tSurvey, 'TimeZone', '');
    end
    
    keyONI = dateshift(tONI(:), 'start', 'month');
    keyS   = dateshift(tSurvey, 'start', 'month');

    kStr = cellstr(datestr(keyONI, 'yyyymm'));
    m = containers.Map(kStr, num2cell(vONI(:)));

    oniAtSurvey = nan(numel(keyS),1);
    for i = 1:numel(keyS)
        ks = datestr(keyS(i), 'yyyymm');
        if isKey(m, ks)
            oniAtSurvey(i) = m(ks);
        end
    end
end

function cmap = redbluecmap(m)
% Red-blue diverging colormap

    if nargin < 1 || isempty(m), m = 256; end
    n1 = floor(m/2);
    n2 = m - n1;

    b = [linspace(0,1,n1)', linspace(0,1,n1)', ones(n1,1)];
    r = [ones(n2,1), linspace(1,0,n2)', linspace(1,0,n2)'];

    cmap = [b; r];
end
