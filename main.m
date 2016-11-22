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

%% Extract the correlation matrices and find the best features set

% Correlation between the input features.
feat_corr = corr(features_norm);

% Correlation between input features and targets.
targ_corr = corr(features_norm, target_norm);

% Setup the GA to find the set of features which maximizes the output
% correlation and minimizes the input correlation.
fitnessFcn = @feat_fitness;
nvar = 3;

options = gaoptimset;

options = gaoptimset(options,'TolFun', 1e-8, 'Display', 'iter', ...
    'Generations', 300, 'PlotFcns', @gaplotbestf);

%[x, fval] = ga(fitnessFcn, nvar, [], [], [], [], [1; 1; 1], [7; 7; 7], ...
%    [], [1 2 3], options);



%% Setup the NN inputs and targets

% Select 3 features
net_in = [features_norm(:,2) features_norm(:,6) features_norm(:,7)]';

targets = target_norm';

%% Multi-Layer Perceptron
%We use the GA to find the best weights and biases. 

global mlp_net

mlpFitness = @mlp_fitness;

for i=10:20
    
    mlp_net = feedforwardnet(i);
    mlp_net = configure(mlp_net, net_in, targets);
    mlp_net.divideParam.trainRatio = 70/100;
    mlp_net.divideParam.valRatio = 15/100;
    mlp_net.divideParam.testRatio = 15/100;
    
    mlp_nvar = mlp_net.numWeightElements;

    % Initial set of weights, computed by Matlab.
    
    mlp_trained = train(mlp_net, net_in, targets);
    trained_wb = compresswb(mlp_trained.IW, mlp_trained.LW, mlp_trained.b);
    
    %load('mlp_init_wb.mat');

% Generate the initial population from by randomly perturbating the weights
% computed by Matlab.
%     Population = zeros(200, mlp_nvar);
% 
%     for j=1:200
%         Population(i,:) = -trained_wb + (trained_wb + trained_wb).*rand();
%     end;

    mlp_options = gaoptimset;

    mlp_options = gaoptimset(mlp_options,'TolFun', 1e-8, 'Display', 'iter', ...
        'SelectionFcn', @selectionroulette, ...
        'CrossoverFcn', @crossoversinglepoint, ...
        'MutationFcn', @mutationgaussian, ...
        'Generations', 10, 'PlotFcns', @gaplotbestf, ...
        'InitialPopulation', trained_wb);

    [mlp_weights, mlp_fval] = ga(mlpFitness, mlp_nvar, [], [], [], [], [], [], [], [], mlp_options);
end;

%% Radial Basis Function Network
% With the GA we want to find the best spread and centers for the
% RBF neurons.

% Create the RBF network.
global rbf_net
rbf_net = network(1,2,[1;1],[1;0],[0 0;1 0],[0 1]);
rbf_net.inputs{1}.size = 3;
rbf_net.layers{1}.size = 398;
rbf_net.inputWeights{1,1}.weightFcn = 'dist';
rbf_net.layers{1}.netInputFcn = 'netprod';
rbf_net.layers{1}.transferFcn = 'radbas';
rbf_net.layers{2}.size = 1;

load('rbf_best_wb.mat');
rbf_init_b = cell(2, 1);
rbf_init_b{1} = brbf_b{1}(1);
rbf_init_b{2} = brbf_b{2};
rbf_init_wb = compresswb(brbf_IW, brbf_LW, rbf_init_b);

rbfFitness = @rbf_fitness;
rbf_nvar = 1594;
% 
% Population = zeros(200, rbf_nvar);
% for i=1:200
%     Population(i,:) = -rbf_init_wb + (rbf_init_wb + rbf_init_wb).*rand();
% end

rbf_options = gaoptimset;
rbf_options = gaoptimset(rbf_options,'TolFun', 1e-8, 'Display', 'iter', ...
    'SelectionFcn', @selectionroulette, ...
    'CrossoverFcn', @crossoversinglepoint, ...
    'MutationFcn', @mutationadaptfeasible, ...
    'Generations', 10, 'PlotFcns', @gaplotbestf, ...
    'CreationFcn', @gacreationlinearfeasible, ...
    'InitialPopulation', rbf_init_wb);

% [rbf_spread, rbf_fval] = ga(rbfFitness, rbf_nvar, [], [], [], [], 0.01, [], [], [], rbf_options);

[rbf_weights, rbf_fval] = ga(rbfFitness, rbf_nvar, [zeros(1592, 1594); ...
    zeros(1, 1592) -1 0; zeros(1, 1594)], [zeros(1592,1); 0.001; 0], ...
    [], [], [], [], [], [], rbf_options);