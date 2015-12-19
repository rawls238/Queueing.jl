using Queueing
using Base.Test
using Distributions

λ = 3
μ = 4
ρ = λ / μ
expected_total_time = ρ / (λ*(1 - ρ))
expected_wait_time = expected_total_time - 1 /μ
results = MM1(λ, μ, 100000)
@test_approx_eq_eps expected_wait_time results.average_wait_time 0.05
@test_approx_eq_eps expected_total_time results.average_system_time 0.05

a = SimulationArgs(100000, 0)
K = 10
props = QueueProperties(Exponential(1/λ), Exponential(1/μ), 1, K)
λ_1 = 1 - ((1-ρ)*ρ^K)/(1-ρ^(K+1))
N = (ρ*(1-(K+1)*ρ^K + K*ρ^(K+1))) / ((1-ρ)*(1-ρ^(K+1)))
expected_total_time = N / (λ*λ_1)
results = simulate(a, props)
@test_approx_eq_eps expected_total_time results.average_system_time 0.05

N = 10
props = QueueProperties(Exponential(1/λ), Exponential(1/μ), N, -1)
