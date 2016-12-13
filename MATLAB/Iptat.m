k = 1.38e-23;
q = 1.602e-19;
R = 470;
M = 3;
N = 2;
beta = 200;

ABS_ZERO = -273.15;

T = linspace(25-ABS_ZERO,100-ABS_ZERO,16);
% Iptat_calc = 0.95*k*log(0.96*N)/(q*R)*T*beta/(beta+1);
% Iptat_calc = k*T/q/R*log(M/(1 + (M+1)/beta) * N/(1 + (2*M + 1)/beta))*M/(1 + (M+1)/beta/(1 + (2*M + 1)/beta));
Iptat_calc = k*T/q/R*log(6/(1.04*1.0233))*3/(1.04*1.0233)*100/101;
Iptat_spice = [2.637726e-004 2.681961e-004 2.726196e-004 2.770431e-004 2.814666e-004 2.858901e-004 2.903136e-004 2.947371e-004 2.991606e-004 3.035842e-004 3.080080e-004 3.124315e-004 3.168552e-004 3.212792e-004 3.257035e-004 3.301283e-004];

plot(T,Iptat_calc)
hold on
plot(T, Iptat_spice, '--');
hold off
legend('Calculated', 'Simulated');
xlabel('Temperature (K)');
ylabel('Iptat (A)');