clear
clc
global Param_B
%% Initialization
% Get ballast parameters
Param_B = Ballast_Param();

% Get the input
g0 = [0; 0; -7; 2; 1; 0];

% Ballast configuration parameters
max_f_s = 30;
max_f_m = 30;
max_f_l = 30;
max_w = 8;
penalty = 1e50;     % If the ballasts usage reached the allowed amount

% Population parameters
pop_size = 5000;
num_floater= Param_B.num_floater;
num_weight= Param_B.num_weight;
num_genes = (num_floater * 2) + num_weight;
num_prompt = num_floater + num_weight;

% Create function argument
funargs = {max_f_s, max_f_m, max_f_l, max_w};
ofunargs = [{g0} {penalty} {funargs}];

% Genetic algorithm parameters
num_generations = 150;
crossover_rate = 0.7;
mutation_rate = 0.01;
fitness = zeros(pop_size,1);

% Initialize population - encoded
population = randi([0 1], pop_size, num_genes);
% population = generate_feasible_population(popSize, numGenes, num_flo, num_wei);

% Array to store best fitness in each generation
best_fitness_history = zeros(num_generations, 1);
best_prompt_history = cell(num_generations, num_prompt);

% Initialize containers to store evolution data
population_history = cell(num_generations, 1);
fitness_history = cell(num_generations, 1);

for gen = 1:num_generations
%% Evaluation
    for i = 1:pop_size
        gene = population(i,:);
        prompt = Decoded_Gene(gene, num_floater, num_weight);
        % fitness(i, :) = 1 / (objectiveFunction(prompt) + epsilon);
        fitness(i, :) = Ballast_Objective(prompt, ofunargs);
    end
%% Selection (Tournament)
% Tournament selection parameters
    tournament_size = 2; 

% New generation
    new_population = zeros(size(population));
    for i = 1:pop_size
    % Select several genes via tournament selection and choose the best
    % gene. The best gene are the one with smallest fitness value
        winner_index = Tournament_Selection(fitness, tournament_size);
        new_population(i,:) = population(winner_index,:);
    end

%% Crossover
    for i = 1:2:pop_size
        if rand <= crossover_rate
            crossover_point = randi(num_genes-1);
            new_population(i,:) = [new_population(i,1:crossover_point), new_population(i+1,crossover_point+1:end)];
            new_population(i+1,:) = [new_population(i+1,1:crossover_point), new_population(i,crossover_point+1:end)];
        end
    end

%% Mutation
    for i = 1:pop_size
        for j = 1:num_genes
            if rand <= mutation_rate
                new_population(i,j) = 1 - new_population(i,j);
            end
        end
    end

%% Finalization
% Final Evaluation
    for i = 1:pop_size
        new_gene = new_population(i,:);
        new_prompt = Decoded_Gene(new_gene, num_floater, num_weight);
        fitness(i, :) = Ballast_Objective(prompt, ofunargs);
    end
% Find and store the best fitness and corresponding the prompt, track
% fitness history
    [opt_fitness, idx] = min(fitness);
    best_fitness_history(gen) = opt_fitness;
    best_prompt_history(gen,:) = Decoded_Gene(new_population(idx,:), num_floater, num_weight);
    fitness_history{gen} = fitness;

% Set altered population as the initial population for next generation,
% track the population history
    population = new_population;
    population_history{gen} = population;
    
%% Display progress    
% disp(['Generation ', num2str(gen), ': Best Fitness = ', num2str(maxFitness), ', Best Ballast Configuration = ', bestBallastConfigStr]);
    disp(['Generation ', num2str(gen), ': Best Fitness = ', num2str(opt_fitness)]);

%% Convergence check (Stall check)
    % Parameters for stall generations criteria
    stall_generations_limit = 10; % Number of generations without improvement to tolerate
    best_fitness_stall = inf; % Initialize with a very high value
    stall_counter = 0; % Initialize stall counter

    if opt_fitness < best_fitness_stall
        best_fitness_stall = opt_fitness;
        stall_counter = 0; % Reset stall counter
    else
        stall_counter = stall_counter + 1;
    end

    % Check for stall
    if stall_counter >= stall_generations_limit
        disp(['No improvement for ', num2str(stall_generations_limit), ' generations.']);
        break; % Exit the loop
    end
end

%% Results
% Optimal prompt
% opt_obj_val = best_fitness_history(end,:)
% opt_prompt = best_prompt_history(end,:);
opt_obj_val = min(best_fitness_history)
opt_idx = find(best_fitness_history == opt_obj_val);
opt_prompt = best_prompt_history(opt_idx(1),:);

% Optimal ballast config
best_ballast_config = Ballast_Configuration(opt_prompt, funargs);
front_floaters_config = opt_prompt(1:10)
middle_floaters_config = opt_prompt(11:20)
aft_floaters_config = opt_prompt(21:30)
weights_config = opt_prompt(31:end)

% Check final ballast term and the residual
g_opt = Ballast_Compute(best_ballast_config);
residual = (g0 - g_opt);

% Header
disp('        g0       g_opt    residual');

% Data rows
disp(['Z    ', sprintf('%0.4f    %0.4f    %0.4f', g0(3), g_opt(3), residual(3))]);
disp(['K    ', sprintf('%0.4f    %0.4f    %0.4f', g0(4), g_opt(4), residual(4))]);
disp(['M    ', sprintf('%0.4f    %0.4f    %0.4f', g0(5), g_opt(5), residual(5))]);
