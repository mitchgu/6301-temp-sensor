x = linspace(25,71,24);
data = [26.52 26.94 30.44 32.68 34.92 38.84 39.96 41.5 42.9 42.34 43.6 46.26 47.1 52 56.48 54.52 55.08 61.1 62.64 63.2 64.88 68.66 67.96 68.8];
R = corrcoef(x, data)

scatter(x, data, 'filled');
xlabel('Thermocouple Temperature');
ylabel('Actual Temperature');