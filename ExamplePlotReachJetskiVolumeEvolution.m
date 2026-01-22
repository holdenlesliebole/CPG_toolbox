% Example code plot the jumbo survey cross-shore volume evolution for
% a specified reach (Mop range) and date range (changes plotted 
% relative to the first survey date in the range).

% Jumbo surveys have been gridded into 1m x,y (UTM) spatial resolution
% elevation points (m, NAVD88) and stored in the CPGMOP M*SG.mat files 
% for each Mop number.  So he elevation difference at a grid point from 
% two surveys is equal to the volume difference in m^3.


%% Uses the m-script function CG=CombineSGdata(mapth,MopStart,MopEnd)

%% settings
% 1. Path to CPGMOP data files
mpath='/volumes/group/MOPS/'; % reefbreak on a mac
%mpath='/Users/William/Desktop/MOPS/';

% 2. Mop range to use in volume change calculations
%MopStart=668;MopEnd=682; % start and mop numbers for Cardiff
MopStart=576;MopEnd=590; % start and mop numbers for north TP

% 3. Date range to consider. The first and last dates to not
%    have to match survey dates precisely
StartDate=datenum(1998,1,1);%datenum(2010,11,22);
EndDate=datenum(2026,1,31);%datenum(today);%datenum(2011,3,10);

% 4. Elevation bin sizes (m) to use when calculating volume change as 
%    a function of the starting survey grid elevations. Larger
%    values give smoother results with less cross-shore detail.  
zRes=0.5; % 10 cm

% Alongshore reach length (m). 
% Used to normalize first moment of the seaward deposition distribution
L=100*(MopEnd-MopStart+1);

% Cross-shore width will be calculated from the grid extent
% (computed below after loading data)

%% load the combined SG gridded mat file data.  Return the combined
%  data to a struct array SG instead of CG to use the normal 
%  single mop SG gridding and plotting code with the combined data.
SG=CombineSGdata(mpath,MopStart,MopEnd);

%% identify jumbos with jetskis by checking the original survey file names for the 
%  word jumbo
jumbo=find(contains({SG.File},'umbo') | contains({SG.File},'etski'));
% find jumbo surveys with jetski data
m=0;
jetski=[];
for j=1:length(jumbo)
    %fprintf('%s %5.1f\n',datestr(SM(jumbo(j)).Datenum),min(SM(jumbo(j)).Z1Dmean));
    if( min(SG(jumbo(j)).Z) < -3 )
        m=m+1;
        jetski(m)=jumbo(j);
    end       
end

fprintf('The SG struct array has %i Jumbo-Jetski Surveys.\n',numel(jetski))

% find the jetski surveys that fall in the date range
idx=find( [SG(jetski).Datenum] >= StartDate & [SG(jetski).Datenum] <= EndDate);

fprintf('%i Jumbo-Jetski Surveys found in the date range.\n',numel(idx))
% reduce indices to just these survey indices
jetski=jetski(idx);
datestr([SG(jetski).Datenum])

%% Need to turn the saved SG struct array grid points into a 2d grid arrays

% make base grid area encompassing all gridded survey data
minx=min(vertcat(SG.X));
maxx=max(vertcat(SG.X));
miny=min(vertcat(SG.Y));
maxy=max(vertcat(SG.Y));

% 2d UTM grid indice matrices
[X,Y]=meshgrid(minx:maxx,miny:maxy);

% Calculate cross-shore width (for normalizing first moment)
W = maxx - minx;

%% Z0 is a grid of the first survey in the date range. All grid
%  changes will be calculated relative to this reference grid.
SurvNum=jetski(1); 
% Mop area 1m gridded points with valid data for this survey
x=SG(SurvNum).X;
y=SG(SurvNum).Y;
% get 1d indice values of the valid x,y grid points
idx=sub2ind(size(X),y-miny+1,x-minx+1);
% initialize the 2d elevation Z0 array as NaNs
Z0=X*NaN; 
% overlay the valid data point elevations using the 1d indices
Z0(idx)=SG(SurvNum).Z; 

% rounded Z0 elevations relative to MSL and scaled into elevation bins  
z0bin=round((Z0-0.774)/zRes); 

%% Loop through other surveys in the date range and compare their grid
% elevations changes (volume changes) to Z0 as a function of the Z0 

figure('position',[ 21          56        1385         728]);
col=jet(length(jetski)-1);

% Pre-allocate arrays to store SSD values and dates for derivative calculation
ssd_vals = zeros(1, length(jetski));
survey_dates = zeros(1, length(jetski));

% First survey (reference)
ssd_vals(1) = 0;
survey_dates(1) = SG(jetski(1)).Datenum;

for n=2:length(jetski)
    
   SurvNum=jetski(n); 
    % Mop area 1m gridded points with valid data for this survey
    x=SG(SurvNum).X;
    y=SG(SurvNum).Y;
    % get 1d indice values of the valid x,y grid points
    idx=sub2ind(size(X),y-miny+1,x-minx+1);
    % initialize the 2d elevation Z0 array as NaNs
    Z=X*NaN; 
    % overlay the valid data point elevations using the 1d indices
    Z(idx)=SG(SurvNum).Z; 
    
    % change grid relative to initial grid
    dz=Z-Z0;

    
    dv=[];
    m=0;
    mu=0; % initialize first moment parameter
    % loop through the Z0 reference grid elevation bins
    for iz=min(z0bin(:)):max(z0bin(:))
      m=m+1;
      % net volume change "density" in the elevation bin (for plotting)
      dv(m)=sum(dz(z0bin==iz),'omitnan')/zRes;
      % add to first moment (use raw volume sum, not density)
      % includes all volume changes at subaqueous elevations (deposition and erosion)
      dv_raw=sum(dz(z0bin==iz),'omitnan');
      if(iz < 0) mu=mu+dv_raw*iz*zRes;end
    end
    % normalize by area (alongshore L and cross-shore W) to get equivalent depth
    mu=round(-mu/(L*W), 4); 
    
    % Store SSD value and date for derivative calculation
    ssd_vals(n) = mu;
    survey_dates(n) = SG(jetski(n)).Datenum;
    
    % plot results
    fprintf('%s\n',[datestr(SG(jetski(n)).Datenum) '  Seaward Sand Deposition (SSD) = ' num2str(mu) ' m'])
    plot((min(z0bin(:)):max(z0bin(:)))*zRes,dv/1000,'-','color',col(n-1,:),...
    'DisplayName',...
    [datestr(SG(jetski(n)).Datenum) '  SSD = ' num2str(mu) ' m'] ,'linewidth',2);hold on
end

% Add horizontal line at zero for first survey date
xlim_vals = [min(z0bin(:)) max(z0bin(:))]*zRes;
plot(xlim_vals, [0 0], 'k-', 'linewidth', 2, 'DisplayName', [datestr(SG(jetski(1)).Datenum) ' (Reference)']);

grid on;
legend('numcolumns',1,'Location','bestoutside', 'fontsize', 11)
set(gca,'xtick',min(z0bin(:)):max(z0bin(:))*zRes,'xlim',xlim_vals);
xlabel([ datestr(SG(jetski(1)).Datenum) ' Nearshore Elevation, Z_o (m, MSL)'], 'fontsize', 14);
ylabel('Net Volume Change Density (m^{3} m^{-1})', 'fontsize', 14,'interpreter','tex');
set(gca,'fontsize',12);
title(['Net Cross-shore Volume Change since ' datestr(SG(jetski(1)).Datenum)...
    ' : MOPs ' num2str(MopStart) ' to ' num2str(MopEnd)],'fontsize',16)
set(gca,'position',[0.1300    0.4100    0.65 0.5150])

%% Calculate and display dSSD/dt (rate of SSD change)
fprintf('\n\n--- Rate of Seaward Sand Deposition (dSSD/dt) ---\n')
fprintf('Date Interval                   Days    dSSD/dt (m/day)   dSSD/dt (cm/day)\n')
fprintf('%-34s %6s %17s %17s\n', '---', '---', '---', '---')

for n=2:length(jetski)
    dt_days = survey_dates(n) - survey_dates(n-1);
    dssd = ssd_vals(n) - ssd_vals(n-1);
    dssd_dt = dssd / dt_days;  % m/day
    dssd_dt_cm = dssd_dt * 100;  % cm/day
    
    date_str = sprintf('%s to %s', datestr(survey_dates(n-1)), datestr(survey_dates(n)));
    fprintf('%-34s %6.0f %17.5f %17.3f\n', date_str, dt_days, dssd_dt, dssd_dt_cm)
end

%% Add wave Hs time series as 2nd axes below FIRST figure

% use Mop in middle of Cardiff for wave info
MopNumber=580;%675;
stn=['D0' num2str(MopNumber)];

urlbase=...  % nearshore station
'http://thredds.cdip.ucsd.edu/thredds/dodsC/cdip/model/MOP_alongshore/';

% read hindcast file dates and wave height info
urlend = '_hindcast.nc'; 
dsurl=strcat(urlbase,stn,urlend); % full url path and filename
wavetime=ncread(dsurl,'waveTime'); % read wave times
% convert mop unix time to UTC
hctime=datetime(wavetime,'ConvertFrom','posixTime');
hchs=ncread(dsurl,'waveHs'); % read wave heights

ax_wave1=axes('position',[0.1300    0.08    0.65 0.2150]);

% plot time series
plot(hctime,hchs,'k-','linewidth',2); hold on;

% just show date range of jetski surveys
set(ax_wave1,'xlim',[datetime(StartDate-7,'convertfrom','datenum') ...
datetime(EndDate+7,'convertfrom','datenum')]);

% mark dates of surveys 
yl=get(gca,'ylim');
for n=2:length(jetski)
    x=datetime(SG(jetski(n)).Datenum,'convertfrom','datenum');
    plot([x x],yl,'-','color',col(n-1,:),'linewidth',2); hold on;
end

% replot time series
plot(hctime,hchs,'k-','linewidth',2); hold on;

ylabel('Hs (m)', 'fontsize', 14)
xlabel('Date', 'fontsize', 14)
set(gca,'fontsize',12);
grid on;

makepng('TBR23_VolumeEvolution_by_InitialElevation.png')
% Instead of plotting volume change vs initial elevation, plot it vs cross-shore distance

figure('position',[ 21          56        1385         728]);
col=jet(length(jetski)-1);

for n=2:length(jetski)
    
   SurvNum=jetski(n); 
    % Mop area 1m gridded points with valid data for this survey
    x=SG(SurvNum).X;
    y=SG(SurvNum).Y;
    % get 1d indice values of the valid x,y grid points
    idx=sub2ind(size(X),y-miny+1,x-minx+1);
    % initialize the 2d elevation Z0 array as NaNs
    Z=X*NaN; 
    % overlay the valid data point elevations using the 1d indices
    Z(idx)=SG(SurvNum).Z; 
    
    % change grid relative to initial grid
    dz=Z-Z0;
    
    % Extract cross-shore distance and volume change
    x_all = X(idx);
    dv_all = dz(idx);
    
    % Bin by cross-shore distance and calculate mean volume change
    x_bins = min(x_all):5:max(x_all);  % 5m cross-shore bins
    dv_binned = zeros(1, length(x_bins)-1);
    x_bin_centers = zeros(1, length(x_bins)-1);
    
    for ib = 1:length(x_bins)-1
        mask = x_all >= x_bins(ib) & x_all < x_bins(ib+1);
        if sum(mask) > 0
            dv_binned(ib) = nanmean(dv_all(mask));
            x_bin_centers(ib) = (x_bins(ib) + x_bins(ib+1)) / 2;
        else
            dv_binned(ib) = NaN;
            x_bin_centers(ib) = NaN;
        end
    end
    
    % Get first moment (SSD) for this survey
    % includes all volume changes at subaqueous elevations (deposition and erosion)
    z0bin_all = round((Z0-0.774)/zRes); 
    mu=0;
    for iz=min(z0bin_all(:)):max(z0bin_all(:))
      dz_bin_raw=sum(dz(z0bin_all==iz),'omitnan');
      if(iz < 0) mu=mu+dz_bin_raw*iz*zRes;end
    end
    mu=round(-mu/(L*W), 2);
    
    % plot results
    plot(x_bin_centers, dv_binned, '-', 'color', col(n-1,:), ...
        'DisplayName', [datestr(SG(jetski(n)).Datenum) '  SSD = ' num2str(mu) ' m'], ...
        'linewidth', 2);
    hold on
end

% Add horizontal line at zero for first survey date
xlim_vals = [min(x_all) max(x_all)];
plot(xlim_vals, [0 0], 'k-', 'linewidth', 2, 'DisplayName', [datestr(SG(jetski(1)).Datenum) ' (Reference)']);

grid on;
legend('numcolumns', 1, 'Location', 'bestoutside', 'fontsize', 11)
set(gca, 'xlim', xlim_vals);
xlabel('Cross-Shore Distance (m)', 'fontsize', 14);
ylabel('Mean Elevation Change (m)', 'fontsize', 14);
set(gca, 'fontsize', 12);
title(['Net Elevation Change by Cross-Shore Distance since ' datestr(SG(jetski(1)).Datenum)...
    ' : MOPs ' num2str(MopStart) ' to ' num2str(MopEnd)], 'fontsize', 16)
set(gca, 'position', [0.1300    0.4100    0.65 0.5150])

%% add wave Hs time series as 2nd axes below SECOND figure
ax_wave2=axes('position',[0.1300    0.08    0.65 0.2150]);

% plot time series
plot(hctime,hchs,'k-','linewidth',2); hold on;

% just show date range of jetski surveys
set(ax_wave2,'xlim',[datetime(StartDate-7,'convertfrom','datenum') ...
datetime(EndDate+7,'convertfrom','datenum')]);

% mark dates of surveys 
yl=get(gca,'ylim');
for n=2:length(jetski)
    x=datetime(SG(jetski(n)).Datenum,'convertfrom','datenum');
    plot([x x],yl,'-','color',col(n-1,:),'linewidth',2); hold on;
end

% replot time series
plot(hctime,hchs,'k-','linewidth',2); hold on;

ylabel('Hs (m)', 'fontsize', 14)
xlabel('Date', 'fontsize', 14)
set(gca,'fontsize',12);
grid on;

makepng('TBR23_VolumeEvolution_by_CrossShoreDistance.png')
%makepng('CardiffFrequentJetskiEvolution.png')

%
% 
% %--- a make regular grid for a specific survey
% 
% %% 2016 
% 
% % first survey
% 
% didx=find([SG(jumbo).Datenum] ==  datenum(2015,7,15)); % TP
% 
% SurvNum=jumbo(didx); 
% % Mop area 1m grid points with valid data
% x=SG(SurvNum).X;
% y=SG(SurvNum).Y;
% 
% % Make 2d x,y utm arrays encompassing the valid points
% idx=sub2ind(size(X),y-miny+1,x-minx+1);
% 
% Z1=X*NaN; % initialize the 2d elevation Z array as NaNs
% Z1(idx)=SG(SurvNum).Z; % overlay the valid data points using the 1d indices
% 
% % nextjumbo survey
% didx=find([SG(jumbo).Datenum] ==  datenum(2016,1,27));
% SurvNum2=jumbo(didx);
% 
% x=SG(SurvNum2).X;
% y=SG(SurvNum2).Y;
% 
% % Make 2d x,y utm arrays encompassing the valid points
% idx=sub2ind(size(X),y-miny+1,x-minx+1);
% 
% Z2=X*NaN; % initialize the 2d elevation Z array as NaNs
% Z2(idx)=SG(SurvNum2).Z; % overlay the valid data points using the 1d indices
% Z2=Z2+.15;
% d=Z2-Z1;
% 
% figure('position',[84         229        1108         475]);
% 
% dz=0.1;dz=1/dz; % calculate vol changes in .1m Fall depth increments
% 
% z=round((Z1-0.774)*dz); %rounded fall elevations relative to MSL
% dv=[];
% m=0;
% mu=0;
% for iz=min(z(:)):max(z(:))
%     m=m+1;
%     dv(m)=sum(d(z==iz),'omitnan');
%     if(iz < 0 && dv(m) > 0) mu=mu+dv(m)*iz;end
% end
% mu=round(-mu/L)
% plot([min(z(:)):max(z(:))]/dz,dv/1000,'DisplayName',...
%     ['2016  \mu_{SSD} = ' num2str(mu)] ,'linewidth',2);hold on
% 
% 
% 
% % figure;
% % idx=find(~isnan(d(:)));
% % plot(Z1(idx),d(idx),'k.','markersize',1);
% % grid on;
% 
% % 
% % % plot the xutm,yutm,z 3d surface
% % 
% % ax1=axes('position',[0.05    0.0500    0.1504    0.95]);
% % p1=surf(X,Y,Z2-Z1,'linestyle','none');
% % 
% % set(gca,'xlim',[473300 474100]);hold on;
% % set(gca,'dataaspectratio',[1 1 1])
% % 
% % grid on;
% % set(gca,'color',[.7 .7 .7],'fontsize',14);
% % 
% % y_labels = get(gca, 'YTick');
% % set(gca, 'YTickLabel', num2str(y_labels'));ytickangle(45);
% % ylabel('northings (m)');
% % x_labels = get(gca, 'XTick');
% % set(gca, 'XTickLabel', num2str(x_labels'));xtickangle(45);
% % xlabel('eastings (m)');
% % zlabel('Elevation (m.NAVD88)');
% % 
% % view(2)
% % %axis equal
% % 
% % d=Z2-Z1;erode=round(sum(d(d<0))/1000);dep=round(sum(d(d>0))/1000);
% % str=['-V= ' num2str(erode) 'K  ; +V= ' num2str(dep) 'K'];
% % text(473350,3653120,str,'fontweight','bold','fontsize',18);
% % 
% % set(gca,'clim',[-3 3]);
% % polarmap;
% % 
% % title({
% %     datestr(SG(SurvNum).Datenum), ' to ', datestr(SG(SurvNum2).Datenum)},...
% %     'fontsize',16)
% % 
% %% -------------------------------------
% %% 2017 
% 
% % first survey
% 
% didx=find([SG(jumbo).Datenum] ==  datenum(2016,9,27));
% 
% SurvNum=jumbo(didx); 
% % Mop area 1m grid points with valid data
% x=SG(SurvNum).X;
% y=SG(SurvNum).Y;
% 
% % Make 2d x,y utm arrays encompassing the valid points
% idx=sub2ind(size(X),y-miny+1,x-minx+1);
% 
% Z1=X*NaN; % initialize the 2d elevation Z array as NaNs
% Z1(idx)=SG(SurvNum).Z; % overlay the valid data points using the 1d indices
% 
% % nextjumbo survey
% %didx=find([SG(jumbo).Datenum] ==  datenum(2017,1,9)); % Torrey
% SurvNum2=jumbo(didx);
% 
% x=SG(SurvNum2).X;
% y=SG(SurvNum2).Y;
% 
% % Make 2d x,y utm arrays encompassing the valid points
% idx=sub2ind(size(X),y-miny+1,x-minx+1);
% 
% Z2=X*NaN; % initialize the 2d elevation Z array as NaNs
% Z2(idx)=SG(SurvNum2).Z; % overlay the valid data points using the 1d indices
% 
% d=Z2-Z1;
% 
% z=round((Z1-0.774)*dz); %rounded fall elevations relative to MSL
% dv=[];
% m=0;
% mu=0;
% for iz=min(z(:)):max(z(:))
%     m=m+1;
%     dv(m)=sum(d(z==iz),'omitnan');
%     if(iz < 0 && dv(m) > 0) mu=mu+dv(m)*iz;end
% end
% mu=round(-mu/L)
% plot([min(z(:)):max(z(:))]/dz,dv/1000,'DisplayName',...
%     ['2017  \mu_{SSD} = ' num2str(mu)] ,'linewidth',2);hold on
% 
% 
% % % plot the xutm,yutm,z 3d surface
% % 
% % ax2=axes('position',[0.35    0.0500    0.1504    0.95]);
% % p2=surf(X,Y,Z2-Z1,'linestyle','none');
% % 
% % set(gca,'xlim',[473300 474100]);hold on;
% % set(gca,'dataaspectratio',[1 1 1])
% % 
% % grid on;
% % set(gca,'color',[.7 .7 .7],'fontsize',14);
% % 
% % y_labels = get(gca, 'YTick');
% % set(gca, 'YTickLabel', num2str(y_labels'));ytickangle(45);
% % ylabel('northings (m)');
% % x_labels = get(gca, 'XTick');
% % set(gca, 'XTickLabel', num2str(x_labels'));xtickangle(45);
% % xlabel('eastings (m)');
% % zlabel('Elevation (m.NAVD88)');
% % 
% % view(2)
% % %axis equal
% % 
% % d=Z2-Z1;erode=round(sum(d(d<0))/1000);dep=round(sum(d(d>0))/1000);
% % str=['-V= ' num2str(erode) 'K  ; +V= ' num2str(dep) 'K'];
% % text(473350,3653120,str,'fontweight','bold','fontsize',18);
% % 
% % set(gca,'clim',[-3 3]);
% % polarmap;
% % 
% % title({
% %     datestr(SG(SurvNum).Datenum), ' to ', datestr(SG(SurvNum2).Datenum)},...
% %     'fontsize',16)
% % 
% % %% -------------------------------------
% % 
% % %% -------------------------------------
% %% 2021 
% 
% % first survey
% 
% didx=find([SG(jumbo).Datenum] ==  datenum(2020,10,14)); % Torrey
% 
% 
% SurvNum=jumbo(didx); 
% % Mop area 1m grid points with valid data
% x=SG(SurvNum).X;
% y=SG(SurvNum).Y;
% 
% % Make 2d x,y utm arrays encompassing the valid points
% idx=sub2ind(size(X),y-miny+1,x-minx+1);
% 
% Z1=X*NaN; % initialize the 2d elevation Z array as NaNs
% Z1(idx)=SG(SurvNum).Z; % overlay the valid data points using the 1d indices
% 
% % nextjumbo survey
% didx=find([SG(jumbo).Datenum] ==  datenum(2021,2,10)); % Torrey
% SurvNum2=jumbo(didx);
% 
% x=SG(SurvNum2).X;
% y=SG(SurvNum2).Y;
% 
% % Make 2d x,y utm arrays encompassing the valid points
% idx=sub2ind(size(X),y-miny+1,x-minx+1);
% 
% Z2=X*NaN; % initialize the 2d elevation Z array as NaNs
% Z2(idx)=SG(SurvNum2).Z; % overlay the valid data points using the 1d indices
% 
% d=Z2-Z1;
% 
% z=round((Z1-0.774)*dz); %rounded fall elevations relative to MSL
% dv=[];
% m=0;
% mu=0;
% for iz=min(z(:)):max(z(:))
%     m=m+1;
%     dv(m)=sum(d(z==iz),'omitnan');
%     if(iz < 0 && dv(m) > 0) mu=mu+dv(m)*iz;end
% end
% mu=round(-mu/L)
% plot([min(z(:)):max(z(:))]/dz,dv/1000,'DisplayName',...
%     ['2021  \mu_{SSD} = ' num2str(mu)] ,'linewidth',2);hold on
% 
% 
% 
% % 
% % % plot the xutm,yutm,z 3d surface
% % 
% % ax3=axes('position',[0.35    0.0500    0.1504    0.95]);
% % p2=surf(X,Y,Z2-Z1,'linestyle','none');
% % 
% % set(gca,'xlim',[473300 474100]);hold on;
% % set(gca,'dataaspectratio',[1 1 1])
% % 
% % grid on;
% % set(gca,'color',[.7 .7 .7],'fontsize',14);
% % 
% % y_labels = get(gca, 'YTick');
% % set(gca, 'YTickLabel', num2str(y_labels'));ytickangle(45);
% % ylabel('northings (m)');
% % x_labels = get(gca, 'XTick');
% % set(gca, 'XTickLabel', num2str(x_labels'));xtickangle(45);
% % xlabel('eastings (m)');
% % zlabel('Elevation (m.NAVD88)');
% % 
% % view(2)
% % %axis equal
% % 
% % d=Z2-Z1;erode=round(sum(d(d<0))/1000);dep=round(sum(d(d>0))/1000);
% % str=['-V= ' num2str(erode) 'K  ; +V= ' num2str(dep) 'K'];
% % text(473350,3653120,str,'fontweight','bold','fontsize',18);
% % 
% % 
% % 
% % set(gca,'clim',[-3 3]);
% % polarmap;
% % 
% % title({
% %     datestr(SG(SurvNum).Datenum), ' to ', datestr(SG(SurvNum2).Datenum)},...
% %     'fontsize',16)
% % 
% % %% -------------------------------------
% % %% -------------------------------------
% %% 2023 
% 
% % first survey
% 
% didx=find([SG(jumbo).Datenum] ==  datenum(2022,10,10)); % Torrey
% 
% SurvNum=jumbo(didx); 
% % Mop area 1m grid points with valid data
% x=SG(SurvNum).X;
% y=SG(SurvNum).Y;
% 
% % Make 2d x,y utm arrays encompassing the valid points
% idx=sub2ind(size(X),y-miny+1,x-minx+1);
% 
% Z1=X*NaN; % initialize the 2d elevation Z array as NaNs
% Z1(idx)=SG(SurvNum).Z; % overlay the valid data points using the 1d indices
% 
% % nextjumbo survey
% didx=find([SG(jumbo).Datenum] ==  datenum(2023,1,24)); % Torrey
% SurvNum2=jumbo(didx);
% 
% x=SG(SurvNum2).X;
% y=SG(SurvNum2).Y;
% 
% % Make 2d x,y utm arrays encompassing the valid points
% idx=sub2ind(size(X),y-miny+1,x-minx+1);
% 
% Z2=X*NaN; % initialize the 2d elevation Z array as NaNs
% Z2(idx)=SG(SurvNum2).Z; % overlay the valid data points using the 1d indices
% 
% d=Z2-Z1;
% 
% z=round((Z1-0.774)*dz); %rounded fall elevations relative to MSL
% dv=[];
% m=0;
% mu=0;
% for iz=min(z(:)):max(z(:))
%     m=m+1;
%     dv(m)=sum(d(z==iz),'omitnan');
%     if(iz < 0 && dv(m) > 0) mu=mu+dv(m)*iz;end
% end
% mu=round(-mu/L)
% plot([min(z(:)):max(z(:))]/dz,dv/1000,'DisplayName',...
%     ['2023  \mu_{SSD} = ' num2str(mu)] ,'linewidth',2);hold on
% 
% grid on;
% 
% % % plot the xutm,yutm,z 3d surface
% % 
% % ax4=axes('position',[0.35    0.0500    0.1504    0.95]);
% % p2=surf(X,Y,Z2-Z1,'linestyle','none');
% % 
% % set(gca,'xlim',[473300 474100]);hold on;
% % set(gca,'dataaspectratio',[1 1 1])
% % 
% % grid on;
% % set(gca,'color',[.7 .7 .7],'fontsize',14);
% % 
% % y_labels = get(gca, 'YTick');
% % set(gca, 'YTickLabel', num2str(y_labels'));ytickangle(45);
% % ylabel('northings (m)');
% % x_labels = get(gca, 'XTick');
% % set(gca, 'XTickLabel', num2str(x_labels'));xtickangle(45);
% % xlabel('eastings (m)');
% % zlabel('Elevation (m.NAVD88)');
% % 
% % view(2)
% % %axis equal
% % 
% % d=Z2-Z1;erode=round(sum(d(d<0))/1000);dep=round(sum(d(d>0))/1000);
% % str=['-V= ' num2str(erode) 'K  ; +V= ' num2str(dep) 'K'];
% % text(473350,3653120,str,'fontweight','bold','fontsize',18);
% % 
% % set(gca,'clim',[-3 3]);
% % polarmap;
% % 
% % % title({
% % %     datestr(SG(SurvNum).Datenum), ' to ', datestr(SG(SurvNum2).Datenum)},...
% % %     'fontsize',16)
% % 
% % title({
% %     datestr(SG(SurvNum).Datenum), ' to ','23-Jan-2023'},...
% %     'fontsize',16)
% % 
% % t=text(ax4,473550,3652000,10,{'PLEASE','STAND BY'},'fontweight','bold','fontsize',20)
% % %% -------------------------------------
% % 
% % cb=colorbar;
% % cb.Label.String='Elevation Change (m)';
% % cb.FontSize=14;
% % 
% % set(ax1,'position',[0.075    0.0500    0.1504    0.95]);
% % set(ax2,'position',[0.3    0.0500    0.1504    0.95]);
% % set(ax3,'position',[0.525    0.0500    0.1504    0.95]);
% % set(ax4,'position',[0.75    0.0500    0.1504    0.95]);
% % colormap(flipud(colormap))
% %
% 
% set(gca,'xtick',min(z(:)):max(z(:)),'xlim',[-10 4]);
% xlabel('Fall Nearshore Elevation (m, MSL)');
% ylabel('Net Volume Change (m^{3} x 1000)');
% set(gca,'fontsize',14);
% title('Cardiff Net Cross-shore Volume Change, from Fall to Late January : Mops 568-598','fontsize',18)
% 
% legend
%makepng('CardiffSevereWinterChangesVsFallDepthNorthTP.png')