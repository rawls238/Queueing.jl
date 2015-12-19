This package provides tools for analysis of birth and death based Markovian Queueing Models

Queueing Systems currently implemented:

G/G/1
G/G/1/K
G/G/c
G/G/c/K

The ultimate goal of this package is to enable the ability to run simulations on arbitrary queueing topologies as well as be able to estimate the performance characteristics of different queueing structures conditional on historical data and with already known distributions. While it can also be utilized for the analysis of various queueing systems from an academic perspective, its ultimate purpose will to be able to assist in simulating the performance implications of various scheduling algorithms.

## Documentation

This package exports a core ```simulate``` function which takes two types as inputs:

```julia
type SimulationArgs
  max_time::Float64
  max_customers::Float64
end
```

```julia
type QueueProperties
  interarrival::Distribution
  service::Distribution
  num_servers::Integer
  max_capacity::Integer
end
```

The ```Distribution``` type here refers to a Distribution type from [Distributions.jl](https://github.com/JuliaStats/Distributions.jl).

The simulate function returns an object of ```QueueStats``` which contain the statistics collected during simulation

```julia
type QueueStats
  num_in_system::Integer
  total_num_waiting::Integer
  total_departures::Integer
  total_wait_time::Float64
  total_system_time::Float64
  num_monitors::Integer
  average_wait_time::Float64
  average_system_time::Float64
end
```

License: MIT
