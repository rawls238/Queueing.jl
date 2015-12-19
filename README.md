This package provides tools for analysis of birth and death based Markovian Queueing Models

Queueing Systems currently implemented:

G/G/1
G/G/1/K
G/G/c
G/G/c/K

The ultimate goal of this package is to enable the ability to run simulations on arbitrary queueing network topologies. Mostly it may gravitate towards enabling the analysis of the performance of complex scheduling algorithms in distributed systems, but it aims to be useful for academic purposes as well.

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
