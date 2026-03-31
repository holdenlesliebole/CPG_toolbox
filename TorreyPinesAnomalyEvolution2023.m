load MopTableUTM.mat

MopStart=find(strcmp([Mop.Name],'D0574'));
MopEnd=find(strcmp([Mop.Name],'D0590'));
% MopStart=find(strcmp([Mop.Name],'D0632'));
% MopEnd=find(strcmp([Mop.Name],'D0647'));
% MopStart=find(strcmp([Mop.Name],'D0636'));
% MopEnd=find(strcmp([Mop.Name],'D0665'));

% san dieguito
% MopStart=find(strcmp([Mop.Name],'D0634'));
% MopEnd=find(strcmp([Mop.Name],'D0646'));

% solana nourishment
% MopStart=find(strcmp([Mop.Name],'D0634'));
% MopEnd=find(strcmp([Mop.Name],'D0667'));

% plot entire year 3 rows 4 columns
mon=10;
mons=[(mon+1):12 1:mon];
yrs=[2022*ones(numel((mon+1):12),1)' 2023*ones(mon,1)'];

% san dieguito figure
figure('position',[  1          61        1400         736]);%plot(lon,lat,'y.');
CS=SAcombineMops(MopStart,MopEnd);

mm=0;
for m=1:12

    %% build Global month mean grid for mop range
    Mon=mons(m);
    CGM=GMcombineMopsMonth(MopStart,MopEnd,Mon);

    xmin=min(vertcat(CGM.X2D));xmax=max(vertcat(CGM.X2D));
    ymin=min(vertcat(CGM.Y2D));ymax=max(vertcat(CGM.Y2D));
    xmin=floor(xmin);xmax=ceil(xmax);
    ymin=floor(ymin);ymax=ceil(ymax);
    x=CGM.X2D;
    y=CGM.Y2D;
    % x,y grid arrays
    [Xg,Yg]=meshgrid(xmin:xmax,ymin:ymax);
    idx=sub2ind(size(Xg),y-ymin+1,x-xmin+1);
    % Global Month Mean z grid array
    Zmean=Xg*NaN; % initialize as NaNs
    Zmean(idx)=CGM.Z2Dmean; % assign valid z grid data points


    for jj=1:2
        if jj == 1
            DateStart=datenum(yrs(m),mons(m),1);
            DateEnd=datenum(yrs(m),mons(m),15);
        else
            DateStart=datenum(yrs(m),mons(m),16);
            DateEnd=datenum(yrs(m),mons(m),31);
        end

        Zmon=Xg*NaN;
        mm=mm+1;
        subplot(3,8,mm);

        % all survey sources (subaerial and subaqueous)
        ndx=find([CS.Datenum] >= DateStart & [CS.Datenum] <= DateEnd);

        for idx = ndx
            x=CS(idx).X;
            y=CS(idx).Y;
            z=CS(idx).Z;
            gdx=sub2ind(size(Xg),y-ymin+1,x-xmin+1);
            % overlay gridded recent survey data on grid
            Zmon(gdx)=z; % assign valid z grid data points
        end

        Anom=Zmon-Zmean;
        mdx=find(~isnan(Anom(:)));
        %figure;surf(Xg,Yg,Zjuly-Zmean);colormap(flipud(polarmap));shading flat;view(2)
        %%
        [lat,lon]=utm2deg(Xg(mdx),Yg(mdx),repmat('11 S',[length(Xg(mdx)) 1]));
        [ScatterPlot,ColorBarPlot]=ColorScatterPolarmap(lon,lat,Anom(mdx));
        delete(ColorBarPlot)
        hold on



        %%
        % ndx=find((strcmp({CS.Source},'AtvMR') | strcmp({CS.Source},'Trk')) &...
        %     [CS.Datenum] >= DateStart & [CS.Datenum] <= DateEnd);
        %
        % if numel(ndx) > 0
        %
        % x=[];y=[];z=[];
        % for idx = ndx
        % x=[x' vertcat(CS(idx).X)']';
        % y=[y' vertcat(CS(idx).Y)']';
        % z=[z' vertcat(CS(idx).Z)']';
        % end
        % % trim higher elevations
        % zidx=find(z < 10);
        % x=x(zidx);y=y(zidx);z=z(zidx);
        % % convert to lat lon
        % [lat,lon]=utm2deg(x,y,repmat('11 S',[length(x) 1]));

        %hold on;

        % ScatterPlotBeachLatLon(lat,lon,z,'2d');
        % hold on
        % load MopTableUTM.mat
        % for n=MopStart:MopEnd
        % plot([Mop.BackLon(n) Mop.OffLon(n)],[Mop.BackLat(n) Mop.OffLat(n)],'m-')
        % text(Mop.OffLon(n),Mop.OffLat(n),num2str(n),'horizontalalign','right','color','w')
        % end
        %plot(lon2(idx2),lat2(idx2),'m.')
        plot_google_map('MapType', 'satellite')
        % set(gca,'clim',[-13 -4])
        % set(gca,'clim',[-1 6])
        set(gca,'fontsize',16)

        % title({[datestr(CS(idx).Datenum) ' |  Multibeam '],...
        %     'Mops 645 to 655'},...
        %     'fontsize',16);
        title({datestr(CS(idx).Datenum)},'fontsize',18)
        set(gca,'xtick',[],'ytick',[]);box on;
        % pos=get(gca,'position');
        % set(gca,'position',[pos(1)-0.085 0.05 pos(3)-.12 0.85])
        pos=get(gca,'position');
        fac=0.15;
        dx=pos(3)*fac;dy=pos(4)*fac;set(gca,'position',[pos(1)-dx pos(2)-dy pos(3)+dx pos(4)+dy])
    end
end
%end
% title({'Solana Beach, CA',datestr(CS(idx).Datenum)},'fontsize',18)
% set(gca,'xtick',[],'ytick',[]);box on;
% %%
% pos=get(gca,'position');
% set(gca,'position',[pos(1)-0.085 0.05 pos(3)-.12 0.85])
%BeachColorbar
%%
ax1=axes('position',[.04 .075 .01 .85]);
colormap(flipud(polarmap(64)))
cb=colorbar;
set(gca,'clim',[-1 1]);
%cb.Label.String='Time of Year Elevation Anomaly (m)';
set(cb,'position',[0.05  0.0747    0.01    0.8505])
%set(NavdAxes,'position',[0.05  0.0747    0.01    0.8505],'fontsize',12)
set(cb,'fontsize',14)
%title(BeachColorBarTitleString)
axes(ax1)
axis off
text(1.75,1.05,{'Time of Year','Elevation Anomaly (m)'},'color','k','fontsize',16,'horizontalalign','center')
%%
makepng('TorreyPinesAnomalyEvolution2023.png')