isdefined(Base, :__precompile__) && __precompile__()

module Queueing

using Distributions, DataStructures

import Base: <, <=, ==, >=, >, /, +, isequal, ArgumentError

export
  QueueEdge,
  QueueNode,
  QueueStats,
  QueueProperties,
  MM1,
  MMN,
  SimulationArgs,
  aggregate_simulate,
  simulate

include("queueing_system.jl")

end
