%% Main script.
clearvars; clc;

global net_in targets features_norm feat_corr targ_corr;
% features coloumns indices
cyl_col = 1;
disp_col = 2;
hp_col = 3;
wgt_col = 4;
acc_col = 5;
year_col = 6;
orig_col = 7;
name_col = 8;

%% Extract all the features except the car names.
extract_allfeatures;

% Input features matrix sizes
f_col = size(features,2);
f_row = size(features,1);

%% Extract the MPG.
extract_mpg;

%% Handle NaNs
% We substitute all the NaNs with the mean value of that feature.
% We already now that there are 8 missing values in the horsepower
% column.

% Compute the mean of the numeric values.
notNaN = features(~isnan(features(:,3)),hp_col);
notNaN_mean = mean(notNaN);

% Substitute all the NaNs with the mean value.
features(isnan(features(:,3)), hp_col) = notNaN_mean;

%% Normalize the features
% For each feature we compute the mean value and the standard
% deviation.
feat_m = zeros(1, f_col);
feat_d = zeros(1, f_col);

for i=1:f_col
    feat_m(i) = mean(features(:,i));
    feat_d(i) = std(features(:,i));
end;

% Now subtract the mean value from each feature value and divide
% by its standard deviation.
features_norm = zeros(size(features,1),size(features,2));
for i=1:f_col
    features_norm(:,i) = (features(:,i) - feat_m(i)) / feat_d(i);
end;

%% Normalize the targets
target_m = mean(mpg);
target_d = std(mpg);

target_norm = (mpg - target_m) / target_d;

%% Extract the correlation matrices

% Correlation between the input features
feat_corr = corr(features_norm);

% Correlation between input features and targets
targ_corr = corr(features_norm, target_norm);

% A = [1 -1 0; -1 1 0; 0 1 -1; 0 -1 1; 1 0 -1; -1 0 1];
% b = [1 -1 1 -1 1 -1]';

fitnessFcn = @feat_fitness;
nvar = 3;

options = gaoptimset;

options = gaoptimset(options,'TolFun', 1e-8, 'Display', 'iter', ...
    'Generations', 300, 'PlotFcns', @gaplotbestf);

[x, fval] = ga(fitnessFcn, nvar, [], [], [], [], [1; 1; 1], [7; 7; 7], ...
    [], [1 2 3], options);



%% This section is just a test!

% Select 3 features
net_in = [features_norm(:,2) features_norm(:,6) features_norm(:,7)]';

targets = target_norm';

% net = feedforwardnet(10);
% 
% net = configure(net, net_in, targets);
% 
% [perf, regr] = try_fit(10);

%% Set up the Genetic Algorithm

fitnessFcn = @my_fitness;
nvar = 51;

% Initial set of wights, computed by Matlab.
IW = [2.2228  1.9433   -0.6168 -0.9164   -2.3342    1.6761 ...
   -1.5058    1.9284    1.7639  1.8134    2.1976    0.9896 ...
    0.9134   -0.5695   -2.8176 -1.7910   -1.6760    1.7552 ...
   -2.1581   -1.5753    1.3994 -2.1137   -1.9468   -0.9163 ...
   -2.4845   -1.2125    1.2061 1.5166    2.1356   -1.4955];
LW = [-0.0792    0.9831   -0.3792   -0.6987 ...
    0.6068    0.9273   -0.4589    0.6252 -0.9740   -0.6555];

b = [3.0162 2.3459 1.6757 -1.0054 -0.3351 -0.3351 -1.0054 -1.6757 ...
   -2.3459 3.0162 0.3273];

Population = zeros(200, nvar);

gen = [IW LW b];

for i=1:200
    Population(i,:) = -gen + (gen + gen).*rand();
end

options = gaoptimset;

options = gaoptimset(options,'TolFun', 1e-8, 'Display', 'iter', ...
    'SelectionFcn', @selectionroulette, ...
    'CrossoverFcn', @crossoversinglepoint, ...
    'MutationFcn', @mutationgaussian, ...
    'Generations', 10, 'PlotFcns', @gaplotbestf, ...
    'InitialPopulation', Population);

[x, fval] = ga(fitnessFcn, nvar, [], [], [], [], [], [], [], [], options);