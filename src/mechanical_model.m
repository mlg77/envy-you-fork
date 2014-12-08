function [f_rhs, u0, idx, p] = mechanical_model(varargin)

p = parse_inputs(varargin{:});
idx = indices();
u0 = initial_conditions(idx);
f_rhs = @rhs;

    function [du, R, h] = rhs(~, u, Ca_i)
        Mp = u(idx.Mp, :);
        AMp = u(idx.AMp, :);
        AM = u(idx.AM, :);
        R = u(idx.R, :);
        
        K_1 = p.gamma_cross * Ca_i.^3;
        K_6 = K_1;
        
        M = 1 - AM - AMp - Mp;
        du(idx.Mp, :) = p.K_4 * AMp + K_1 .* M - (p.K_2 + p.K_3) * Mp;
        du(idx.AMp, :) = p.K_3 * Mp + K_6 .* AM - (p.K_4 + p.K_5) * AMp;
        du(idx.AM, :) = p.K_5 * AMp - (p.K_7 + K_6) .* AM;
        
        
        h = 0.1*R;
        F_r = AMp + AM;
        
        E = p.E_passive + F_r * (p.E_active - p.E_passive);
        R_0 = p.R_0_passive + F_r * (p.alpha - 1) * p.R_0_passive;
        
        du(idx.R, :) = p.R_0_passive / p.eta * ( R * p.P_T ./ h - ...
            E .* (R - R_0) ./ R_0); 
    end



end

function idx = indices()
idx.Mp = 1;
idx.AMp = 2;
idx.AM = 3;
idx.R = 4;
end

function params = parse_inputs(varargin)
parser = inputParser();
parser.addParameter('K_2', 0.5);
parser.addParameter('K_3', 0.4);
parser.addParameter('K_4', 0.1);
parser.addParameter('K_5', 0.5);
parser.addParameter('K_7', 0.1);
parser.addParameter('gamma_cross', 17); %uM^-3 s^-1

parser.addParameter('eta', 1e4); %Pa s
parser.addParameter('R_0_passive', 20e-6); % m
parser.addParameter('h_0_passive', 3e-6); % m
parser.addParameter('P_T', 4000); % Pa
parser.addParameter('E_passive', 66e3); % Pa
parser.addParameter('E_active', 233e3); % Pa
parser.addParameter('alpha', 0.6);

parser.parse(varargin{:});
params = parser.Results;

end
function u0 = initial_conditions(idx)
u0 = zeros(length(fieldnames(idx)), 1);
u0(idx.Mp) = .25;
u0(idx.AMp) = .25;
u0(idx.AM) = .25;
u0(idx.R) = 15e-6;
end
        