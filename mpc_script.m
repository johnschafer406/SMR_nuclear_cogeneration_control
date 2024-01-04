clear all;
clc;
close all;

A=[-4 0 0;
  .125 -.125 0;
  0 4 -4];

B=[ -4 0 4;
    0 -.125 0;
    0 0 0];
C=[.2274 0 .5308]; % eta=.7583801, scales plant to 50MWe (Fhp=.3, Flp=.7)

D=[];

x0=[0 0 0];

sys_continuous = ss(A, B, C, D);
Ts = 1; 
sys_discrete = c2d(sys_continuous, Ts, 'zoh'); % Discretize using Zero-Order Hold

sys_discrete = setmpcsignals(sys_discrete,'MV',1,'MV',2, 'MD', 3); % Specify manipulated variables and Measured Distrbance
mpcobj = mpc(sys_discrete,Ts,20,3);


mpcobj.ManipulatedVariables = struct('Min',0,'Max',65.93,'RateMin', -.6593,'RateMax', .6593);
mpcobj.ManipulatedVariables(2).Min = 0;          % Set minimum value
mpcobj.ManipulatedVariables(2).Max = 65.93;      % Set maximum value
mpcobj.ManipulatedVariables(2).RateMin = -.6593; % Set minimum rate
mpcobj.ManipulatedVariables(2).RateMax = .6593;  % Set maximum rate

mpcobj.Weights.ManipulatedVariables = [.8,0];  % Penalize using u1 control
mpcobj.Weights.ManipulatedVariablesRate=[1 1]; % Allow big rate changes (on 15 min increments)

%Load Data
data = readtable('load_9_23_2019_UCSC.csv');
loadDemand = data.TotalCampusLoad;
loadDemand=repelem(loadDemand, 900);
loadDemand=loadDemand*1.4;

wind_data=readtable('wind_sample.csv');
wind_data=wind_data.Var2;
wind_data=repelem(wind_data, 900);
loadDemand_wind=loadDemand -(wind_data);
loadDemand=loadDemand_wind;
loadDemand=loadDemand;

total_seconds = 24 * 60 * 60;  % 2 hours in seconds
timeVector = 0:1:(total_seconds-1);
timeVector=timeVector';


simin=timeseries(loadDemand, timeVector);

DC = cloffset(mpcobj);
fprintf('DC gain from output disturbance to output = %5.8f (=%g) \n',DC,DC);


Tstop = total_seconds;                               % simulation time
Nf = round(Tstop/Ts);                     % number of simulation steps
r = loadDemand/1000;
 

disturbance=65.93*ones(total_seconds,1);

[y,t,u] = sim(mpcobj,Nf,r,disturbance);

figure                                  % create new figure

subplot(3,1,1)                          % create upper subplot
plot(0:Nf-1,y,0:Nf-1,r)                 % plot plant output and reference
title('Power Generated')                         % add title so upper subplot
ylabel('MO1')                           % add a label to the upper y axis
legend('SMR Output', 'Actual Load')
grid                                    % add a grid to upper subplot

subplot(3,1,2)                          % create lower subplot
plot(0:Nf-1,(u(:,1)))                          % plot manipulated variable
title('Steam through Bypass Valve');                         % add title so lower subplot
xlabel('Simulation Steps')              % add a label to the lower x axis
ylabel('MV1')

subplot(3,1,3)                          % create lower subplot
plot(0:Nf-1,(u(:,2)))                          % plot manipulated variable
title('Steam through Extraction Valve');                         % add title so lower subplot
xlabel('Simulation Steps')              % add a label to the lower x axis
ylabel('MV2')    
grid                                    % add a grid to lower subplot

figure
plot(0:Nf-1,y,0:Nf-1,r)                 % plot plant output and reference
title('Power Generated')                         % add title so upper subplot
ylabel('MO1')
legend('SMR Output', 'Actual Load')% add a label to the upper y axis


u1 = u(:, 1);
u2 = u(:, 2);

% Time intervals (assuming uniform intervals)
dt = diff(t);
dt = [dt; dt(end)];  % Assuming the last interval is same as the second last

% Compute the cumulative integral using the trapezoidal rule
integral_u1 = cumtrapz(t, u1);
integral_u2 = cumtrapz(t, u2);

% Plotting
figure
subplot(2,1,1) 
plot(t, integral_u1, 'b', 'LineWidth', 1);  % Plot integral of u1
xlabel('Time');
ylabel('Total Steam');
title('Total Steam Wasted through Bypass Valve');
grid

subplot(2,1,2)
plot(t, integral_u2, 'r', 'LineWidth', 1);  % Plot integral of u2
xlabel('Time');
ylabel('Total Steam');
title('Total Steam Extracted for Cogeneration');
grid


%Error Analysis
% Calculate the squared difference
squared_diff = (y - r).^2;

% Calculate the mean of these squared differences
mse = mean(squared_diff);
rmse = sqrt(mse);

% Display the result
disp(['Root Mean Squared Error (RMSE): ', num2str(rmse)]);






