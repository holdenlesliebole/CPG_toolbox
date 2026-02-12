function MOP = read_MOPline2(MOPname, date1, date2)
    % MOP = read_MOPline2(MOPname, date1, date2)
    %
    % This function reads the 1D E(f) spectrum from the CDIP thredds server
    % plus other parameters, retrieving only the required date range.
    %
    % INPUT:
    %   MOPname: e.g., 'D0586'
    %   date1, date2: bounding datetimes (with or without time zones)
    %
    % OUTPUT:
    %   MOP: struct containing fields for time, spec1D, frequency, Hs, etc.
    %
    % Holden Leslie-Bole, June 2024
    
    % --- Ensure tSwitch is in the same time zone as date1/date2 ---
    if isempty(date1.TimeZone)
        % If your input dates are naive, we can keep tSwitch naive too:
        tSwitch = datetime(2025,4,1,0,0,0); % no time zone
    else
        % If date1/date2 have a time zone, match it
        tSwitch = datetime(2025,4,1,0,0,0,'TimeZone',date1.TimeZone);
    end
    
    % Compare date2 with tSwitch
    if date2 < tSwitch
        url = ['http://thredds.cdip.ucsd.edu/thredds/dodsC/cdip/model/MOP_alongshore/' MOPname '_hindcast.nc'];
        disp('Using hindcast');
        MOP = read_MOP_data(url, date1, date2);
    
    elseif date1 >= tSwitch
        if date1 == dateshift(datetime('now','TimeZone',date1.TimeZone),'start','day')
            url = ['http://thredds.cdip.ucsd.edu/thredds/dodsC/cdip/model/MOP_alongshore/' MOPname '_forecast.nc'];
            disp('Using forecast');
        else
            url = ['http://thredds.cdip.ucsd.edu/thredds/dodsC/cdip/model/MOP_alongshore/' MOPname '_nowcast.nc'];
            disp('Using nowcast');
        end
        MOP = read_MOP_data(url, date1, date2);
    
    elseif date1 < tSwitch && date2 > tSwitch
        % Load hindcast data
        url_hindcast = ['http://thredds.cdip.ucsd.edu/thredds/dodsC/cdip/model/MOP_alongshore/' MOPname '_hindcast.nc'];
        disp('Using hindcast for first portion');
        MOP_hindcast = read_MOP_data(url_hindcast, date1, tSwitch);
    
        % Load nowcast data
        url_nowcast = ['http://thredds.cdip.ucsd.edu/thredds/dodsC/cdip/model/MOP_alongshore/' MOPname '_nowcast.nc'];
        disp('Using nowcast for second portion');
        MOP_nowcast = read_MOP_data(url_nowcast, tSwitch, date2);
    
        % Concatenate hindcast and nowcast data along the time dimension
        MOP.time       = [MOP_hindcast.time;        MOP_nowcast.time];
        MOP.spec1D     = [MOP_hindcast.spec1D;      MOP_nowcast.spec1D];
        MOP.Hs         = [MOP_hindcast.Hs;          MOP_nowcast.Hs];
        MOP.fp         = [MOP_hindcast.fp;          MOP_nowcast.fp];
        MOP.fm         = [MOP_hindcast.fm;          MOP_nowcast.fm];
        MOP.Dp         = [MOP_hindcast.Dp;          MOP_nowcast.Dp];
        MOP.flag1      = [MOP_hindcast.flag1;       MOP_nowcast.flag1];
        MOP.flag2      = [MOP_hindcast.flag2;       MOP_nowcast.flag2];
        MOP.Sxy        = [MOP_hindcast.Sxy;         MOP_nowcast.Sxy];
        MOP.Sxx        = [MOP_hindcast.Sxx;         MOP_nowcast.Sxx];
        MOP.a1         = [MOP_hindcast.a1;          MOP_nowcast.a1];
        MOP.b1         = [MOP_hindcast.b1;          MOP_nowcast.b1];
        MOP.a2         = [MOP_hindcast.a2;          MOP_nowcast.a2];
        MOP.b2         = [MOP_hindcast.b2;          MOP_nowcast.b2];
        MOP.dirspread1 = [MOP_hindcast.dirspread1;  MOP_nowcast.dirspread1];
        MOP.dirspread2 = [MOP_hindcast.dirspread2;  MOP_nowcast.dirspread2];
    
        % Metadata (use hindcast meta data)
        MOP.depth       = MOP_hindcast.depth;
        MOP.lat         = MOP_hindcast.lat;
        MOP.lon         = MOP_hindcast.lon;
        MOP.shorenormal = MOP_hindcast.shorenormal;
        MOP.name        = MOP_hindcast.name;
        MOP.fbounds     = MOP_hindcast.fbounds;
        MOP.frequency   = MOP_hindcast.frequency;
        MOP.fbw         = MOP_hindcast.fbw;
    end
    
    f = MOP.frequency;
    fswell = [0.02 0.0813];
    fseas = [0.0900 0.400];
    % Determine swell and seas frequency indices
    iswell = find(f >= fswell(1) & f <= fswell(2));
    iseas = find(f >= fseas(1) & f <= fseas(2));
    df = double(MOP.fbounds(2,:) - MOP.fbounds(1,:))'; % f bounds are not constant!!
    
    % Define constants
    rho = 1028;    % density (kg/m^3)
    g = 9.81;      % gravity (m/s^2)
    
    % Function to estimate energy flux
        function [EfluxX, EfluxY] = estimateEnergyFlux(MOP, indices)
            k = get_k(MOP.frequency(indices), MOP.depth);
            Cg = get_cg(k, MOP.depth);   % group speed
    
            % Calculate position
            posX = rho * g * Cg' .* MOP.a1(:, indices) .* MOP.spec1D(:, indices);
            posY = rho * g * Cg' .* MOP.b1(:, indices) .* MOP.spec1D(:, indices);
    
            % Convert to radians and rotate into +x = 0 on shorenormal
            theta = deg2rad(-MOP.shorenormal);
            [posXR, posYR] = xyRotate(posX, posY, theta);
    
            % Sum over all frequencies
            EfluxX = sum(posXR' .* df(indices));
            EfluxY = sum(posYR' .* df(indices));
        end
    
    % Estimate energy flux for swell and seas
    [EfluxXswell, EfluxYswell] = estimateEnergyFlux(MOP, iswell);
    [EfluxXseas, EfluxYseas] = estimateEnergyFlux(MOP, iseas);
    
    % Total energy flux
    EfluxXtotal = EfluxXseas + EfluxXswell;
    EfluxYtotal = EfluxYseas + EfluxYswell;
    
    MOP.EfluxXswell = EfluxXswell;
    MOP.EfluxXseas = EfluxXseas;
    MOP.EfluxXtotal = EfluxXtotal;
    MOP.EfluxYswell = EfluxYswell;
    MOP.EfluxYseas = EfluxYseas;
    MOP.EfluxYtotal = EfluxYtotal;
    MOP.Tp = 1./MOP.fp;
end


function MOP = read_MOP_data(url, date1, date2)
    % read_MOP_data
    % Helper function to read partial data from the netCDF file between date1 & date2
    
    time = ncread(url,'waveTime');
    T    = datetime(double(time),'ConvertFrom','posixTime');
    
    % unify with date1's time zone if needed
    if ~isempty(date1.TimeZone)
        if isempty(T.TimeZone)
            T.TimeZone = date1.TimeZone;
        end
    end
    
    disp(['Data is available from ' datestr(T(1)) ' to ' datestr(T(end))])
    itime = find(T>=date1 & T<=date2);
    if isempty(itime)
        warning('No MOP data within the requested range!');
        % Create empty fields
        MOP.time = T([]);
        MOP.spec1D = [];
        MOP.frequency = [];
        MOP.fbw = [];
        MOP.Hs = [];
        MOP.fp = [];
        MOP.fm = [];
        MOP.Dp = [];
        MOP.flag1 = [];
        MOP.flag2 = [];
        MOP.Sxy = [];
        MOP.Sxx = [];
        MOP.a1 = [];
        MOP.b1 = [];
        MOP.a2 = [];
        MOP.b2 = [];
        MOP.dirspread1 = [];
        MOP.dirspread2 = [];
        MOP.depth = [];
        MOP.lat = [];
        MOP.lon = [];
        MOP.shorenormal = [];
        MOP.name = [];
        MOP.fbounds = [];
        return;
    end
    
    MOP.time = T(itime);
    MOP.spec1D = permute(ncread(url,'waveEnergyDensity',[1,min(itime)],[inf,length(itime)]),[2,1]);
    MOP.frequency = double(ncread(url,'waveFrequency'));
    MOP.fbw = double(ncread(url,'waveBandwidth'));
    MOP.Hs = ncread(url,'waveHs',min(itime),length(itime));
    MOP.fp = 1./ncread(url,'waveTp',min(itime),length(itime));
    MOP.fm = 1./ncread(url,'waveTa',min(itime),length(itime));
    MOP.Dp = ncread(url,'waveDp',min(itime),length(itime));
    
    MOP.flag1 = ncread(url,'waveFlagPrimary',min(itime),length(itime));
    MOP.flag2 = ncread(url,'waveFlagSecondary',min(itime),length(itime));
    
    a1 = ncread(url,'waveA1Value',[1,min(itime)],[inf,length(itime)]);
    b1 = ncread(url,'waveB1Value',[1,min(itime)],[inf,length(itime)]);
    a2 = ncread(url,'waveA2Value',[1,min(itime)],[inf,length(itime)]);
    b2 = ncread(url,'waveB2Value',[1,min(itime)],[inf,length(itime)]);
    
    % Directional spreads
    m1 = sqrt(a1.^2 + b1.^2);
    spread1 = (180/pi) .* ( sqrt( 2 .* ( 1 - m1 ) ) );
    MOP.dirspread1 = mean(spread1(1:18,:),1)';
    dir2 = atan2(b2,a2)/2;
    m2 = a2.*cos(2*dir2) + b2.*sin(2*dir2);
    spread2 = (180/pi).* sqrt(abs( 0.5.*(1 - m2) ));
    MOP.dirspread2 = mean(spread2(1:18,:),1)';
    
    MOP.a1 = a1';
    MOP.b1 = b1';
    MOP.a2 = a2';
    MOP.b2 = b2';
    
    MOP.Sxy = ncread(url,'waveSxy',min(itime),length(itime));
    MOP.Sxx = ncread(url,'waveSxx',min(itime),length(itime));
    
    % Meta
    MOP.depth       = ncread(url,'metaWaterDepth');
    MOP.lat         = ncread(url,'metaLatitude');
    MOP.lon         = ncread(url,'metaLongitude');
    MOP.shorenormal = ncread(url,'metaShoreNormal');
    MOP.name        = ncread(url,'metaSiteLabel');
    MOP.fbounds     = ncread(url,'waveFrequencyBounds');
end