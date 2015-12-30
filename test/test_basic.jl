using Queueing
using Base.Test
using Distributions
using DataStructures

λ = 3
μ = 4
ρ = λ / μ
expected_total_time = ρ / (λ*(1 - ρ))
expected_wait_time = expected_total_time - 1 /μ
results = MM1(λ, μ, 100000)
@test_approx_eq_eps expected_wait_time results.average_wait_time 0.05
@test_approx_eq_eps expected_total_time results.average_system_time 0.05

K = 10
props = QueueProperties(Exponential(1/λ), Exponential(1/μ), 1, K)
a = SimulationArgs(100000, 0, [QueueNode(1, props, true, [])])
λ_1 = 1 - ((1-ρ)*ρ^K)/(1-ρ^(K+1))
N = (ρ*(1-(K+1)*ρ^K + K*ρ^(K+1))) / ((1-ρ)*(1-ρ^(K+1)))
expected_total_time = N / (λ*λ_1)
results = simulate(a)
@test_approx_eq_eps expected_total_time results.average_system_time 0.05
agg_results = aggregate_simulate(a, 5)
@test_approx_eq_eps expected_total_time agg_results.average_system_time 0.05

props = QueueProperties(Exponential(1/λ), Exponential(1/μ), 1, -1)
prob = 0.5
a = QueueNode(1, props, false, [])
b = QueueNode(2, props, true, [QueueEdge(a.queue_id, prob)])
jackson_network_args = SimulationArgs(100000, 0, [a, b])
λ_1 = λ * prob
expected_total_time = (1/λ) * ((λ / (μ - λ)) + (λ_1 / (μ - λ_1)))
results = simulate(jackson_network_args)
@test_approx_eq_eps expected_total_time results.average_system_time 0.05
