function [best_fitness_history, last_nz_index, opt_prompt] = Ballast_Distribution_Func(g0, ballastFunargs)
global Param_B
%% Start Elapsed Time Counter
tic

%% Initialization
% Get ballast parameters
Param_B = Ballast_Param();

% Ballast configuration parameters
max_f = ballastFunargs{1};
max_w = ballastFunargs{2};
penalty = 1e50;     % If the ballasts usage reached the allowed amount

% Population parameters
pop_size = ballastFunargs{3};
num_hook_floater= Param_B.num_hook_floater;
num_hook_weight= Param_B.num_hook_weight;
num_floater = num_hook_floater * 3;
num_weight = num_hook_weight;
num_genes = num_floater + num_weight;
num_prompt = num_hook_floater + num_hook_weight;

% Create function argument
funargs = {max_f max_w};
ofunargs = [{g0} {penalty} {funargs}];

% Genetic algorithm containers
num_generations = ballastFunargs{4};
crossover_rate = ballastFunargs{5};
mutation_rate = ballastFunargs{6};
fitness = zeros(pop_size,1);

% Parameters for stall generations criteria
stall_generations_limit = ballastFunargs{7}; % Number of generations without improvement to tolerate
fitness_tolerance = ballastFunargs{8};
divergence_generations_limit = ballastFunargs{9}';
stall_counter = 0; % Initialize stall counter
divergence_counter = 0; % Initialize divergence counter
best_fitness_stall = inf; % Initialize with a very high value

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
        prompt = Decoded_Gene(gene, num_hook_floater, num_hook_weight);
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

%% Finalization <<<<<<<<< TO CHECK
% Final Evaluation
    for i = 1:pop_size
        new_gene = new_population(i,:);
        new_prompt = Decoded_Gene(new_gene, num_hook_floater, num_hook_weight);
        fitness(i, :) = Ballast_Objective(new_prompt, ofunargs);
    end
% Find and store the best fitness and corresponding the prompt, track
% fitness history
    [best_fitness, idx] = min(fitness);
    best_fitness_history(gen) = best_fitness;
    best_prompt = Decoded_Gene(new_population(idx,:), num_hook_floater, num_hook_weight);
    best_prompt_history(gen,:) = best_prompt;
    fitness_history{gen} = fitness;

% Set altered population as the initial population for next generation,
% track the population history
    population = new_population;
    population_history{gen} = population;
    
%% Display progress    
% disp(['Generation ', num2str(gen), ': Best Fitness = ', num2str(maxFitness), ', Best Ballast Configuration = ', bestBallastConfigStr]);
    disp(['Generation ', num2str(gen), ': Best Fitness = ', num2str(best_fitness)]);

%% Convergence check (Stall check)
    % Check for fitness tolerance
    if best_fitness < fitness_tolerance
        disp('Reach the fitness tolerance.');
        break
    end

    % Check for stall
    if best_fitness < best_fitness_stall
        best_fitness_stall = best_fitness;
        best_generation = gen;
        % best_prompt_stall = best_prompt;
        stall_counter = 0; % Reset stall counter
    elseif best_fitness == best_fitness_stall
        stall_counter = stall_counter + 1;
    elseif best_fitness > best_fitness_stall
        divergence_counter = divergence_counter + 1;
    end

    stall = stall_counter >= stall_generations_limit;
    diverge = divergence_counter >= divergence_generations_limit;

    if stall
        disp(['No improvement for ', num2str(stall_generations_limit), ' generations.']);
        disp(['The last minimum value is at generation ', num2str(best_generation),'.']);
        break; % Exit the loop
    end

    if diverge
        disp(['Fitness value diverges for ', num2str(divergence_generations_limit), ' generations.']);
        disp(['The last minimum value is at generation ', num2str(best_generation),'.']);
        break; % Exit the loop
    end

    % Check if the algorithm diverge from the latest minimum fitness value

end

%% Results
% Get all the non-zero elements (if algorithm converges before the maximum number of generation)
nz_best_fitness_history = best_fitness_history(best_fitness_history ~= 0);

% Find the minimum of the non zero best fitness history
min_nz_best_fitness_history = min(nz_best_fitness_history);

% Get the index of the minimum value
last_nz_index = find(best_fitness_history == min_nz_best_fitness_history, ...
    1, 'last'); % Finds the last minimum and non-zero fitness's index

% Evaluate the best value
if ~isempty(last_nz_index)
    % Retrieves the value (the best prompt throughout the generations)
    opt_obj_val = best_fitness_history(last_nz_index)
    opt_prompt = best_prompt_history(last_nz_index,:);
else
    % In case best_fitness_history is all zeros, handle accordingly
    opt_obj_val = []  
    opt_prompt = [];
end

% Optimal ballast config
best_ballast_config = Ballast_Configuration(opt_prompt, funargs);
floaters_config = opt_prompt(1:8);
weights_config = opt_prompt(9:end);

% Print Floater Configuration
disp('Floater housing configuration from top view:')
disp(['    ', '     ','     ','  Front','     ','     ', '    '])
disp(['    ', '    ', '|FL |', '   ','   ','     ', '|FR |','   ', '    '])
disp(['    ', '    |', floaters_config{2}, '|   ','   ','     |', floaters_config{1},'|   ', '    '])
disp(['Left' ,'|OML|', '   ', '|IML|','   ','|IMR|', '   ','|OMR|', 'Right'])
disp(['    ', '|', floaters_config{8}, '|   |', floaters_config{6},'|   |',floaters_config{5}, '|   |',floaters_config{7},'|', '    '])
disp(['    ', '    ', '|AL |', '   ','   ','     ', '|AR |','   ', '    '])
disp(['    ', '    |', floaters_config{4}, '|   ','   ','     |', floaters_config{3},'|   ', '    '])
disp(['    ', '     ','     ','   Aft ','     ','     ', '    '])
disp(' ');

% Print Weight Configuration
disp('Weight configuration from top view:')
disp(['    ', '     ','     ','Front','     ','     ', '    '])
disp(['    ', '|W03|','|W04|','|W05|','|W02|','|W01|', '    '])
disp(['    ', '|', weights_config{3}, ' ||', weights_config{4}, ' ||', weights_config{5}, ' ||', weights_config{2}, ' ||', weights_config{1}, ' |', '    '])
disp(['    ', '     ','     ','|W06|','     ','     ', '    '])
disp(['Left', '     ','     |', weights_config{6},' |     ','     ', 'Right'])
disp(['    ', '     ','     ','|W07|','     ','     ', '    '])
disp(['    ', '     ','     |', weights_config{7},' |     ','     ', '    '])
disp(['    ', '|W011|','|W12|','|W08|','|W10|','|W09|', '    '])
disp(['    ', '|', weights_config{11}, ' ||', weights_config{12}, ' ||', weights_config{8}, ' ||', weights_config{10}, ' ||', weights_config{9}, ' |', '    '])
disp(['    ', '     ','     ',' Aft ','     ','     ', '    '])
disp(' ')

% Check final ballast term and the residual
g_opt = Ballast_Compute(best_ballast_config);
residual = (g_opt - [0; 0; g0(3:5); 0]);

% Header
disp('        g0_maintain       g0(zeta)    residual');

% Data rows
disp(['Z    ', sprintf('    %0.4f         %0.4f       %0.4f', g0(3), g_opt(3), residual(3))]);
disp(['K    ', sprintf('    %0.4f         %0.4f       %0.4f', g0(4), g_opt(4), residual(4))]);
disp(['M    ', sprintf('    %0.4f         %0.4f       %0.4f', g0(5), g_opt(5), residual(5))]);

%% Display Elapsed Time
Elapsed_Time = toc;
fprintf('Elapsed time is %f seconds.\n', Elapsed_Time);

end