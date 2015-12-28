isdefined(Base, :__precompile__) && __precompile__()

module Queueing

using Distributions, DataStructures

import Base: <, <=, ==, >=, >, isequal

export
  QueueEdge,
  QueueNode,
  QueueStats,
  QueueProperties,
  MM1,
  MMN,
  SimulationArgs,
  simulate

include("single_queue.jl")

end
