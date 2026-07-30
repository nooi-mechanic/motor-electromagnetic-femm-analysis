%% generate_spm_model.m - FEMM 모델 생성 및 저장
% FEMM 초기 설정
openfemm(1);
newdocument(0);
depth = 150;
mi_probdef(0,'millimeters','planar',1E-8,depth,30,0);
% 규소강판(Silicon Steel) 코어 재료 정의
mi_addmaterial('SiSteel', 4000, 4000, 0, 1.8e6, 0.0, 0.35, 1.5, 0.95, 0, 0, 0, 0, 0);
bh_core = [
    0, 0;
    100, 0.005;
    500, 0.05;
    1000, 0.15;
    2000, 0.30;
    3000, 0.45;
    5000, 0.70;
    8000, 1.00;
    12000, 1.25;
    16000, 1.40;
    20000, 1.45;
    25000, 1.47;
    30000, 1.48;
    35000, 1.49;
    40000, 1.50
];
for i = 1:size(bh_core,1)
    mi_addbhpoint('SiSteel', bh_core(i,2), bh_core(i,1));
end
bh_core = [0, 0; 100, 0.01; 500, 0.1; 1500, 0.3; 3000, 0.6; 6000, 1.0; 10000, 1.3; 20000, 1.5; 30000, 1.6];
for i = 1:size(bh_core,1)
    mi_addbhpoint('SiSteel', bh_core(i,2), bh_core(i,1));
end
% SmCo17 Grade 17 자석 재료 정의 (비선형 포함)
mi_addmaterial('SmCo17_Grade17', 1.0, 1.05, 0, -750e3, 6.7e5);  % mu_x, mu_y, H_cx, H_cy, conductivity
bh_data = [
    0,       0.0;
    20e3,    0.10;
    100e3,   0.30;
    300e3,   0.60;
    500e3,   0.78;
    650e3,   0.87;
    750e3,   0.95;    % Br
    850e3,   1.00;
    950e3,   1.03;
    1100e3,  1.05;
    1300e3,  1.07;
    1500e3,  1.08
];
for i = 1:size(bh_data,1)
    mi_addbhpoint('SmCo17_Grade17', bh_data(i,2), bh_data(i,1));  % B, H 순서
end
% Inconel 718 material 정의
mi_addmaterial('Inconel 718', ...
    1.02, ...   % mu_x
    1.02, ...   % mu_y
    0,    ...   % Hc (coercivity)
    0,    ...   % J (applied current density)
    0.8,  ...   % Cduct (electrical conductivity in MS/m)
    0,    ...   % Lam_d (lamination thickness, mm)
    0,    ...   % Phi_hmax (hysteresis lag angle, deg)
    1,    ...   % Lam_fill (lamination fill factor)
    0,    ...   % LamType (0 = non‐laminated)
    0,    ...   % Phi_hx (hysteresis lag x, deg)
    0,    ...   % Phi_hy (hysteresis lag y, deg)
    1,    ...   % nstr (number of strands)
    0     ...   % dwire (strand diameter, mm)
);
% 재료 정의
PM = 'SmCo18(1:5)';
Core = 'M-22 Steel';
Sealing = 'Inconel 718';
Coil = '18 AWG';
Coilname = {'Coil_A','Coil_B','Coil_C'};
% 재료 로딩
mi_getmaterial('Air');
mi_getmaterial(Coil);
mi_getmaterial('SmCo18(1:5)')
mi_getmaterial('N35')
mi_getmaterial('M-22 Steel')
% 파라미터
PM_r = 53/2;
Seal = 5;
Airgap = 64/2;
Core_ri = 64/2;
Core_ro = 150/2;
Slot_l = 20;
turns = 200;
max_segment=10;
slot_angle = 180;
Core_angle = 5;
num_slots = 36;
Teeth_angle = pi/66.95;
Teeth_length = 1;
Teeth_length2 = 1;
Arc_offset= 0.01*pi;
% 회전자 (PM)
% 안쪽 자석 경계 arc
mi_drawarc(PM_r,0,-PM_r,0,180,max_segment);
mi_selectarcsegment(0,PM_r);  % 대략 중심 근처
mi_setarcsegmentprop(max_segment, 'None', 0, 1);
mi_clearselected;
mi_addarc(-PM_r,0,PM_r,0,180,max_segment);
mi_selectarcsegment(0,-PM_r);
mi_setarcsegmentprop(max_segment, 'None', 0, 1);
mi_clearselected;
% 바깥쪽 자석 경계 arc
mi_drawarc(PM_r+Seal,0,-PM_r-Seal,0,180,max_segment);
mi_selectarcsegment(0,PM_r+Seal/2);
mi_setarcsegmentprop(max_segment, 'None', 0, 1);
mi_clearselected;
mi_drawarc(-PM_r-Seal,0,PM_r+Seal,0,180,max_segment);
mi_selectarcsegment(0,-PM_r-Seal/2);
mi_setarcsegmentprop(max_segment, 'None', 0, 1);
mi_clearselected;
% 사이드 라인
mi_clearselected;
%라벨링
mi_addblocklabel(0,0);
mi_selectlabel(0,0);
mi_setblockprop(PM,1,0,0,90,1,0);
mi_clearselected;
mi_addblocklabel(0,PM_r+Seal/2);
mi_selectlabel(0,PM_r+Seal/2);
mi_setblockprop(Sealing,1,0,0,90,1,0);
mi_clearselected;
% 고정자 외곽
mi_drawarc(Core_ro,0,-Core_ro,0,180,max_segment);
mi_addarc(-Core_ro,0,Core_ro,0,180,max_segment);
% 슬롯 및 이(Teeth)
for i = 0:num_slots
    g=(i-2)*2*pi/180; h=(i-1)*2*pi/180; j=i*2*pi/180; k=(i+1)*2*pi/180; L=(i+2)*2*pi/180;
    if mod(i,2) == 1
        mi_drawarc(Core_ri*cos(h*Core_angle-Teeth_angle),Core_ri*sin(h*Core_angle-Teeth_angle),Core_ri*cos(j*Core_angle+Teeth_angle),Core_ri*sin(j*Core_angle+Teeth_angle),Core_angle+Teeth_angle*2,max_segment);
        mi_drawline(Core_ri*cos(h*Core_angle-Teeth_angle),Core_ri*sin(h*Core_angle-Teeth_angle),(Core_ri+Teeth_length)*cos(h*Core_angle-Teeth_angle),(Core_ri+Teeth_length)*sin(h*Core_angle-Teeth_angle));
        mi_drawline(Core_ri*cos(j*Core_angle+Teeth_angle),Core_ri*sin(j*Core_angle+Teeth_angle),(Core_ri+Teeth_length)*cos(j*Core_angle+Teeth_angle),(Core_ri+Teeth_length)*sin(j*Core_angle+Teeth_angle));
        mi_drawline((Core_ri+Teeth_length)*cos(h*Core_angle-Teeth_angle),(Core_ri+Teeth_length)*sin(h*Core_angle-Teeth_angle),(Core_ri+Teeth_length+Teeth_length2)*cos(h*Core_angle),(Core_ri+Teeth_length+Teeth_length2)*sin(h*Core_angle));
        mi_drawline((Core_ri+Teeth_length)*cos(j*Core_angle+Teeth_angle),(Core_ri+Teeth_length)*sin(j*Core_angle+Teeth_angle),(Core_ri+Teeth_length+Teeth_length2)*cos(j*Core_angle),(Core_ri+Teeth_length+Teeth_length2)*sin(j*Core_angle));
        mi_drawline((Core_ri+Teeth_length+Teeth_length2)*cos(j*Core_angle),(Core_ri+Teeth_length+Teeth_length2)*sin(j*Core_angle),(Core_ri+Teeth_length+Teeth_length2+Slot_l)*cos(j*Core_angle-Arc_offset),(Core_ri+Teeth_length+Teeth_length2+Slot_l)*sin(j*Core_angle-Arc_offset));
    else
        mi_drawarc((Core_ri+Teeth_length+Teeth_length2+Slot_l)*cos(k*Core_angle-Arc_offset),(Core_ri+Teeth_length+Teeth_length2+Slot_l)*sin(k*Core_angle-Arc_offset),(Core_ri+Teeth_length+Teeth_length2+Slot_l)*cos(L*Core_angle+Arc_offset),(Core_ri+Teeth_length+Teeth_length2+Slot_l)*sin(L*Core_angle+Arc_offset),180,max_segment);
        mi_drawarc(Core_ri*cos(h*Core_angle+Teeth_angle),Core_ri*sin(h*Core_angle+Teeth_angle),Core_ri*cos(j*Core_angle-Teeth_angle),Core_ri*sin(j*Core_angle-Teeth_angle),Core_angle-Teeth_angle*2,max_segment);
        mi_drawline((Core_ri+Teeth_length+Teeth_length2)*cos(j*Core_angle),(Core_ri+Teeth_length+Teeth_length2)*sin(j*Core_angle),(Core_ri+Teeth_length+Teeth_length2+Slot_l)*cos(j*Core_angle+Arc_offset),(Core_ri+Teeth_length+Teeth_length2+Slot_l)*sin(j*Core_angle+Arc_offset));
            end
end
% 고정자 코어 블록
mi_addblocklabel(Core_ro-0.1,0);
mi_selectlabel(Core_ro-0.1,0);
mi_setblockprop(Core,1,0,0,0,2,0);
mi_clearselected;
% 에어갭 및 외부 공기
mi_addblocklabel((PM_r+Seal+Core_ri)/2,0);
mi_selectlabel((PM_r+Seal+Core_ri)/2,0);
mi_setblockprop('Air',1,0,0,0,2,0);
mi_clearselected;
mi_addblocklabel(PM_r*5,0);
mi_selectlabel(PM_r*5,0);
mi_setblockprop('Air',1,0,0,0,2,0);
mi_clearselected;
%% Coil Winding
%분포 권선(?인거 같은데 가장 많이 쓴다고함)
%AAABBBCCCA'A'A'B'B'B'C'C'C'
for i=1:3
    g=(i-2)*2*pi/180;
    h=(i-1)*2*pi/180;
    j= i*2*pi/180;
    k=(i+1)*2*pi/180;
    L=(i+2)*2*pi/180;
% Add Circuit property
  mi_addcircprop(Coilname{i},0,1)
  % Draw coil : C'
  P=-3*pi/9;
  mi_addblocklabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle+P)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle+P))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle+P)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle+P))/2);
  mi_selectlabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle+P)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle+P))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle+P)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle+P))/2);
  mi_setblockprop(Coil,1,0,Coilname{3},0,2,-turns);
  mi_clearselected;
% Draw coil : A
  mi_addblocklabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle))/2);
  mi_selectlabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle))/2);
  mi_setblockprop(Coil,1,0,Coilname{1},0,2,turns);
  mi_clearselected;
  % Draw coil : B
  P=3*pi/9;
  mi_addblocklabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle+P)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle+P))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle+P)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle+P))/2);
  mi_selectlabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle+P)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle+P))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle+P)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle+P))/2);
  mi_setblockprop(Coil,1,0,Coilname{2},0,2,turns);
  mi_clearselected;
  %copying coil C
  copy_angle = pi-P;
  mi_addblocklabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle+copy_angle))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle+copy_angle))/2);
  mi_selectlabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle+copy_angle))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle+copy_angle))/2);
  mi_setblockprop(Coil,1,0,Coilname{3},0,2,turns);
  mi_clearselected;
  %copying coil A'
  copy_angle = pi;
  mi_addblocklabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle+copy_angle))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle+copy_angle))/2);
  mi_selectlabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle+copy_angle))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle+copy_angle))/2);
  mi_setblockprop(Coil,1,0,Coilname{1},0,2,-turns);
  mi_clearselected;
  %copying coil B'
  copy_angle = pi+P;
  mi_addblocklabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle+copy_angle))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle+copy_angle))/2);
  mi_selectlabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle+copy_angle))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle+copy_angle))/2);
  mi_setblockprop(Coil,1,0,Coilname{2},0,2,-turns);
  mi_clearselected;
  end
% 경계조건 및 저장
mi_makeABC(7,PM_r*20,0,0,0);
mi_saveas('spm.fem');