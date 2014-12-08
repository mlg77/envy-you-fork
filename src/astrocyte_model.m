function [f_rhs, u0, idx, p, misc] = astrocyte_model(varargin)
%ASTROCYTE_MODEL Collect all of the pieces needed for the astrocyte model
%in one place

% Collect all parameters
p = parse_inputs(varargin{:});
idx = indices();
f_rhs = @rhs;
u0 = initial_conditions(idx);

misc.input_f = @input_f;
misc.input_rho = @input_rho;
misc.flux_ft = @flux_ft;

    
    function du = rhs(t, u, J_KIR_i)
        R_k = u(idx.R_k, :);
        K_p = u(idx.K_p, :);
                
        N_Na_k = u(idx.N_Na_k, :);
        N_K_k = u(idx.N_K_k, :);
        N_Cl_k = u(idx.N_Cl_k, :);
        N_HCO3_k = u(idx.N_HCO3_k, :);
        
        N_Na_s = u(idx.N_Na_s, :);
        N_K_s = u(idx.N_K_s, :);
        N_HCO3_s = u(idx.N_HCO3_s, :);
                
        % Electroneutrality condition
        N_Cl_s = N_Na_s + N_K_s - N_HCO3_s;
        
        w_k = u(idx.w_k, :);
        i_k = u(idx.i_k, :);
        c_k = u(idx.c_k, :);
        h_k = u(idx.h_k, :);
        s_k = u(idx.s_k, :);                
        eet_k = u(idx.eet_k, :);
        du = zeros(size(u));
        
        % Scaling
        R_s = p.R_tot - R_k;
                      
        % First scale concentrations to get proper concentrations,
        fix = @(x) max(1e-180, x);
        K_s = fix(N_K_s ./ R_s);
        Na_s = fix(N_Na_s ./ R_s);
        Cl_s = fix(N_Cl_s ./ R_s);
        HCO3_s = fix(N_HCO3_s ./ R_s);
        
        Na_k = fix(N_Na_k ./ R_k);
        K_k = fix(N_K_k ./ R_k);
        Cl_k = fix(N_Cl_k ./ R_k);
        HCO3_k = fix(N_HCO3_k ./ R_k);
        
        assert(all(K_s >= 0))
        assert(all(Na_s >= 0))
        assert(all(Cl_s >= 0))
        assert(all(HCO3_s >= 0))
        assert(all(Na_k >= 0))
        assert(all(K_k >= 0))
        assert(all(Cl_k >= 0))
        assert(all(HCO3_k >= 0))
        
        
        
        % Scaling ODE
        du(idx.R_k, :) = p.L_p * ( ...
            Na_k + K_k + Cl_k + HCO3_k - ...
            Na_s - Cl_s - K_s - HCO3_s + p.X_k / R_k);
                
        % Nernst potentials
        E_K_k = p.R_g * p.T / (p.z_K * p.F) * log(K_s ./ K_k);
        E_Na_k = p.R_g * p.T / (p.z_Na * p.F) * log(Na_s ./ Na_k);
        E_Cl_k = p.R_g * p.T / (p.z_Cl * p.F) * log(Cl_s ./ Cl_k);
        E_NBC_k = p.R_g * p.T / (p.z_NBC * p.F) * ...
            log((Na_s .* HCO3_s.^2) ./ (Na_k .* HCO3_k.^2));
        E_BK_k = p.R_g * p.T / (p.z_K * p.F) * log(K_p ./ K_k);
        
        % Membrane potential
        J_NaK_k = p.J_NaK_max * Na_k.^1.5 ./ ...
            (Na_k.^1.5 + p.K_Na_k^1.5) .* ...
            K_s ./ (K_s + p.K_K_s);
        
        
        v_k = (p.g_Na_k * E_Na_k + p.g_K_k * E_K_k + ...
            p.g_Cl_k * E_Cl_k + p.g_NBC_k * E_NBC_k + ...
            p.g_BK_k * w_k * E_BK_k - J_NaK_k * p.F / p.C_correction) ./ ...
            (p.g_Na_k + p.g_K_k + p.g_Cl_k + p.g_NBC_k + p.g_BK_k * w_k);
        
        
        J_BK_k = p.g_BK_k / p.F * w_k .* (v_k - E_BK_k) * p.C_correction;
        J_K_k = p.g_K_k / p.F * (v_k - E_K_k) * p.C_correction;
        
        J_Na_k = p.g_Na_k / p.F * (v_k - E_Na_k) * p.C_correction;
        J_NBC_k = p.g_NBC_k / p.F * (v_k - E_NBC_k) * p.C_correction;
        J_KCC1_k = flux_ft(t) * p.g_KCC1_k / p.F * p.R_g * p.T / p.F * ...
            log((K_s .* Cl_s) ./ (K_k .* Cl_k)) * p.C_correction;
        J_NKCC1_k = flux_ft(t) * p.g_NKCC1_k / p.F * p.R_g * p.T / p.F * ...
            log((Na_s .* K_s .* Cl_s.^2) ./ (Na_k .* K_k .* Cl_k.^2)) * ...
            p.C_correction;
        
        
        
        J_IP3 = p.J_max * (...
            i_k ./ (i_k + p.K_I) .* ...
            c_k ./ (c_k + p.K_act) .* h_k).^3 .* (1 - c_k ./ s_k);
        J_ER_leak = p.P_L * (1 - c_k ./ s_k);
        
        J_pump = p.V_max * c_k.^2 ./ (c_k.^2 + p.k_pump^2);
        
        % Other equations
        B_cyt = 1 ./ (1 + p.BK_end + p.K_ex * p.B_ex ./ (p.K_ex + c_k).^2);
        G = (input_rho(t) + p.delta) ./ (p.K_G + input_rho(t) + p.delta);
             
        v_3 = p.v_5 / 2 * tanh((c_k - p.Ca_3) / p.Ca_4);
   
        
        w_inf = 0.5 * ...
            (1 + tanh((v_k + p.eet_shift * eet_k - v_3) / p.v_4));
        
        phi_w = p.psi_w * cosh((v_k - v_3) / (2*p.v_4));
       
        
        % Right-hand sides
        % Astrocyte
        du(idx.N_K_k, :) = -J_K_k + 2*J_NaK_k + J_NKCC1_k + J_KCC1_k - ...
            J_BK_k;
        du(idx.N_Na_k, :) = -J_Na_k - 3*J_NaK_k + J_NKCC1_k + J_NBC_k;

        du(idx.N_HCO3_k, :) = 2*J_NBC_k;
        du(idx.N_Cl_k, :) = du(idx.N_Na_k, :) + du(idx.N_K_k, :) - ...
            du(idx.N_HCO3_k, :);
        
        du(idx.c_k, :) = B_cyt .* (J_IP3 - J_pump + J_ER_leak);
        du(idx.s_k, :) = -1 / p.VR_ER_cyt * du(idx.c_k, :);
        du(idx.h_k, :) = p.k_on * (p.K_inh - (c_k + p.K_inh) * h_k);
        du(idx.i_k, :) = p.r_h * G - p.k_deg * i_k;
        
        du(idx.eet_k, :) = p.V_eet * max(c_k - p.c_k_min, 0) - p.k_eet * eet_k;
        du(idx.w_k, :) = phi_w .* (w_inf - w_k);
       
        du(idx.K_p, :) = J_BK_k ./ (R_k * p.VR_pa) + J_KIR_i ./ p.VR_ps;
        du(idx.N_K_s, :) = p.k_C * input_f(t) - du(idx.N_K_k, :) + J_BK_k;
        du(idx.N_Na_s, :) = -p.k_C * input_f(t) - du(idx.N_Na_k, :);
        du(idx.N_HCO3_s, :) = -du(idx.N_HCO3_k, :);
    end

    function f = input_f(t)
        f = zeros(size(t));
        ii = p.t_0 <= t & t < p.t_1;
        f(ii) = ...
            p.F_input * factorial(p.alpha + p.beta - 1) / ...
            (factorial(p.alpha - 1) * factorial(p.beta - 1)) * ...
            (1 - (t(ii) - p.t_0) / p.delta_t).^(p.beta - 1) .* ...
            ((t(ii) - p.t_0) / p.delta_t).^(p.alpha - 1);
        f(p.t_2 <= t & t <= p.t_3) = -p.F_input;
    end

    function rho = input_rho(t)
        rho = (p.Amp - p.base) * ( ...
            0.5 * tanh((t - p.t_0) / p.theta_L) - ...
            0.5 * tanh((t - p.t_2) / p.theta_R)) + p.base;
    end

    function out = flux_ft(t)
        out = ( ...
            0.5 * tanh((t - p.t_0) / 0.0005) - ...
            0.5 * tanh((t - p.t_1 - p.lengthpulse) / 0.0005));
    end
end

function idx = indices()
idx.R_k = 1;
idx.K_p = 2;
idx.N_Na_k = 3;
idx.N_K_k = 4;
idx.N_Cl_k = 5;
idx.N_HCO3_k = 6;
idx.N_Na_s = 7;
idx.N_K_s = 8;
idx.N_HCO3_s = 9;
idx.w_k = 10;
idx.i_k = 11;
idx.c_k = 12;
idx.h_k = 13;
idx.s_k = 14;
idx.eet_k = 15;
end

function params = parse_inputs(varargin)
parser = inputParser();
% Scaling parameters
parser.addParameter('L_p', 2.1e-9); % m uM^-1 s^-1
parser.addParameter('X_k', 12.41e-3); % uM m
parser.addParameter('R_tot', 8.79e-8); % m

% Input signal
parser.addParameter('startpulse', 200);
parser.addParameter('lengthpulse', 200);
parser.addParameter('lengtht1', 10);
parser.addParameter('F_input', 2.5); %s
parser.addParameter('alpha', 2);
parser.addParameter('beta', 5);
parser.addParameter('delta_t', 10); %s
parser.addParameter('Amp', 0.7);
parser.addParameter('base', 0.1);
parser.addParameter('theta_L', 1);
parser.addParameter('theta_R', 1);

% Synpatic cleft
parser.addParameter('k_C', 7.35e-5); %uM m s^-1

% Astrocyte
parser.addParameter('VR_ER_cyt', 0.185)
parser.addParameter('k_on', 2); %uM s^-1
parser.addParameter('K_inh', 0.1); %uM
parser.addParameter('r_h', 4.8); % uM
parser.addParameter('k_deg', 1.25); % s^-1
parser.addParameter('V_eet', 72); % uM
parser.addParameter('k_eet', 7.2); % uM
parser.addParameter('c_k_min', 0.1); % uM

% Perivascular space
parser.addParameter('VR_pa', 0.001);
parser.addParameter('VR_ps', 0.001);

% Other parameters
parser.addParameter('F', 9.65e4); %C mol^-1
parser.addParameter('R_g', 8.315); %J mol^-1 K^-1
parser.addParameter('T', 300); % K
parser.addParameter('g_K_k', 40); %mho m^-2
parser.addParameter('g_Na_k', 1.314); % ..
parser.addParameter('g_NBC_k', 7.57e-1); % ..
parser.addParameter('g_KCC1_k', 1e-2); % ..
parser.addParameter('g_NKCC1_k', 5.54e-2); % ..
parser.addParameter('J_NaK_max', 1.42e-3); % uM m s^-1
parser.addParameter('K_Na_k', 10000);
parser.addParameter('K_K_s', 1500);
parser.addParameter('G_BK_k', 4.3e3); % pS
parser.addParameter('A_ef_k', 3.7e-9); % m2
parser.addParameter('C_correction', 1e3);
parser.addParameter('C_input', 0);
parser.addParameter('J_max', 2880); %uM S^-1
parser.addParameter('K_I', 0.03); % uM
parser.addParameter('K_act', 0.17); %uM
parser.addParameter('P_L', 5.2); %uM
parser.addParameter('V_max', 20); %uM s^-1
parser.addParameter('k_pump', 0.24); %uM





parser.addParameter('g_Cl_k', 8.797e-1); % mho m^-2
parser.addParameter('z_K', 1);
parser.addParameter('z_Na', 1);
parser.addParameter('z_Cl', -1);
parser.addParameter('z_NBC', -1);
parser.addParameter('BK_end', 40);
parser.addParameter('K_ex', 0.26); %uM
parser.addParameter('B_ex', 11.35); %uM
parser.addParameter('delta', 1.235e-2); %THIS MAY BE WRONG
parser.addParameter('K_G', 8.82); %uM
parser.addParameter('v_4', 14.5e-3); %V
parser.addParameter('v_5', 8e-3); %V
parser.addParameter('v_6', -15e-3); %V
parser.addParameter('psi_w', 2.664); %s^-1
parser.addParameter('Ca_3', 0.4);
parser.addParameter('Ca_4', 0.15);
parser.addParameter('eet_shift', 2e-3);


parser.parse(varargin{:})
params = parser.Results;
params.g_BK_k = params.G_BK_k*1e-12 / params.A_ef_k;
params.t_0 = params.startpulse;
params.t_1 = params.t_0 + params.lengtht1;
params.t_2 = params.t_0 + params.lengthpulse;
params.t_3 = params.t_1 + params.lengthpulse;
end

function u0 = initial_conditions(idx)
u0 = zeros(length(fieldnames(idx)), 1);

u0(idx.R_k) = 0.061e-6;
u0(idx.N_Na_k) = 0.99796e-3;
u0(idx.N_K_k) = 5.52782e-3;
u0(idx.N_HCO3_k) = 0.58804e-3;
u0(idx.N_Cl_k) = 0.32879e-3;
u0(idx.N_Na_s) = 4.301041e-3;
u0(idx.N_K_s) = 0.0807e-3;
u0(idx.N_HCO3_s) = 0.432552e-3;
u0(idx.K_p) = 3e3;
u0(idx.w_k) = 0.1815e-3;

u0(idx.c_k) = 0.05e-3;
u0(idx.s_k) = 0.1e-3;
u0(idx.h_k) = 0.1e-3;
u0(idx.i_k) = 0.01e-3;
u0(idx.eet_k) = 0.1e-3;
end