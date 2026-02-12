%load MeanElevChange.mat
figure('position',[ 87          59        1196         722]);
yyaxis right
%idx=find(datenum(wavetime) > datenum(2023,4,6) & datenum(wavetime) < dv(end));
%p(4)=plot(datenum(wavetime(idx))-8/24,Hs(idx),'k-','DisplayName','Hs(m)');datetick;
load TP5mTotalFlux.mat
p(4)=plot(datenum(xt),FhwTS(:,501),'k-','linewidth',1,'DisplayName','Total Bottom Energy Flux, 5m Depth');datetick;
hold on
load TP5mSwellFlux.mat
p(5)=plot(datenum(xt),FhwTS(:,501),'k:','linewidth',1,'DisplayName','Swell Bottom Energy Flux, 5m Depth');datetick;
set(gca,'xlim',xl,'ycol','k');ylabel('Energy Flux (m^{3}/s)')
yyaxis left
v5g=v5;v5g([6 9])=NaN;
v6g=v6;v6g([6 9])=NaN;
v7g=v7;v7g([6 9])=NaN;
plot(dv([6 9]),v5([6 9])*100,'ro','linewidth',3,'markersize',8);hold on;
plot(dv([6 9]),v6([6 9])*100,'o','color',[0 .8 0],'linewidth',3,'markersize',8);hold on;
plot(dv([6 9]),v7([6 9])*100,'bo','linewidth',3,'markersize',8);hold on;
p(1)=plot([datenum(2023,4,6) dv]+.5,[0 v7g]*100,'b.-','linewidth',3,'markersize',35,...
    'DisplayName','Elev Change in 6-7m Depth');hold on;
p(3)=plot([datenum(2023,4,6) dv]+.5,[0 v5g]*100,'r.-','linewidth',3,'markersize',35,...
    'DisplayName','Elev Change in 4-5m Depth');
p(2)=plot([datenum(2023,4,6) dv]+.5,[0 v6g]*100,'.-','color',[0 .8 0],'linewidth',3,'markersize',35,...
    'DisplayName','Elev Change in 5-6m Depth');datetick
grid on;
ylabel('Mean Elev Change (cm)')
xl=get(gca,'xlim');set(gca,'fontsize',14);
title('Torrey Pines Outer Subaqueous Profile Depth Change since 6 Apr 2023 (Mop 580-589 Average)')

legend(p,'location','southoutside','fontsize',14)
yyaxis left
load TP5mTotalFlux.mat;
%figure('position',[454   427   825   336]);
FhwTS=FhwTS;
FhwTS(FhwTS < .1)=0;
esum=cumsum(-(FhwTS(:,501).^3));C=-23/esum(end);
plot(datenum(xt),C*esum,'r:','linewidth',2,....
    'DisplayName','0.85*cumsum(TotalEflux^{3}) ; TotalEflux < 0.1 set = 0 No Motion');datetick
set(gca,'xlim',[datenum(xt(1)) datenum(xt(end))])
yyaxis right
set(gca,'xlim',[datenum(xt(1)) datenum(xt(end))])
makepng('TBR23MeanElevChange.png')