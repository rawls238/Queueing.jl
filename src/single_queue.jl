type QueueProperties
  queue_id::Integer
  interarrival::Distribution
  service::Distribution
  num_servers::Integer
  max_capacity::Integer
end

type QueueStats
  num_in_system::Integer
  total_num_waiting::Integer
  total_departures::Integer
  total_wait_time::Float64
  total_system_time::Float64
  num_monitors::Integer
  average_wait_time::Float64
  average_system_time::Float64
  function QueueStats()
    new(0, 0, 0, 0, 0, 0, 0, 0)
  end
end

type QueueEdge
  from::QueueProperties
  to::QueueProperties
  weight::Float64
end

type SimulationArgs
  max_time::Float64
  max_customers::Float64
  topology::AbstractArray{Any}
end

type Server
  id::Integer
end

type Event
  queue_id::Integer
  event_type::String
  enter_time::Float64
  scheduled_time::Float64
  server::Server
end

type SimulationState
  calendar::MutableBinaryHeap{Event}
  current_event::Event
  system_time::Float64
  server_state::Dict{Server, Any}
  topology::AbstractArray{Any}
  waiting::Queue
  num_currently_being_served::Integer
end

type SingleQueueState
  server_state::Dict{Server, Any}
  distributions::QueueProperties
  waiting::Queue
  num_currently_being_served::Integer
end

<=(a::Event, b::Event) = a.scheduled_time <= b.scheduled_time
==(a::Event, b::Event) = isequal(a.scheduled_time, b.scheduled_time)
>=(a::Event, b::Event) = a.scheduled_time >= b.scheduled_time
<(a::Event, b::Event) = a.scheduled_time < b.scheduled_time
>(a::Event, b::Event) =  a.scheduled_time > b.scheduled_time

# Initialization functions

function initialize_system(args::SimulationArgs)
  state = SimulationState(mutable_binary_minheap(Event), Event(1, "", 0, 0, Server(0)), 0, Dict{Server, Any}(), args.topology, Queue(Event), 0)
  initialize_servers(state)
  return state
end

function schedule_initial_events(state::SimulationState)
  next_birth(state)
  next_monitoring(state)
end

# Execution functions

function should_continue_simulation(state::SimulationState, args::SimulationArgs, qs::QueueStats)
  stop_from_time = args.max_time > 0 && state.system_time < args.max_time
  stop_from_customers = args.max_customers > 0 && qs.num_departures < args.max_customers
  return stop_from_time || stop_from_customers
end

function handle_event(e::Event, s::SimulationState, qs::QueueStats)
  s.system_time = e.scheduled_time
  if e.event_type == "birth"
    if head(s.topology[1]).from.max_capacity <= 0 || ((length(s.waiting) + s.num_currently_being_served) < head(s.topology[1]).from.max_capacity)
      return birth(e, s, qs)
    else
      return next_birth(s)
    end
  elseif e.event_type == "death"
    return death(e, s, qs)
  elseif e.event_type == "monitoring"
    return monitoring(s, qs)
  end
end

# Server related functions

function initialize_servers(s::SimulationState)
  for queue in s.topology
    for j in 1:length(head(queue).from.num_servers)
      s.server_state[Server(j)] = null
    end
  end
end

function find_server(s::SimulationState)
  for (k, v) in s.server_state
    if v == null
      return k
    end
  end
  return null
end


function free_server(e::Event, s::SimulationState)
  s.server_state[e.server] = null
  s.num_currently_being_served -= 1
end

function allocate_server(e::Event, server::Server, state::SimulationState)
  state.server_state[server] = true
  state.num_currently_being_served += 1
end

# birth related functions

function birth(e::Event, s::SimulationState, qs::QueueStats)
    enqueue!(s.waiting, e)
    if find_server(s) != null
      next_death(s, qs)
    end
    next_birth(s)
end

function next_birth(s::SimulationState)
  next_time = s.system_time + rand(head(s.topology[1]).from.interarrival)
  push!(s.calendar, Event(1, "birth", next_time, next_time, Server(-1)))
end

# death related functions

function death(e::Event, s::SimulationState, qs::QueueStats)
  free_server(e, s)
  qs.total_departures = qs.total_departures + 1
  if length(s.waiting) > 0
    next_death(s, qs)
  end
end

function next_death(s::SimulationState, qs::QueueStats)
  e = dequeue!(s.waiting)
  server = find_server(s)
  next_time = s.system_time + rand(head(s.topology[e.queue_id]).from.service)
  qs.total_wait_time = qs.total_wait_time + s.system_time - e.enter_time
  allocate_server(e, server, s)
  e.server = server
  e.scheduled_time = next_time
  e.event_type = "death"
  push!(s.calendar, e)
  system_time = next_time - e.enter_time
  qs.total_system_time = qs.total_system_time + system_time
end

# monitoring

function next_monitoring(s::SimulationState)
  next_time = s.system_time + rand(Exponential(1))
  push!(s.calendar, Event(1, "monitoring", next_time, next_time, Server(-1)))
end

function monitoring(s::SimulationState, qs::QueueStats)
  num_waiting = length(s.waiting)
  qs.total_num_waiting = num_waiting
  qs.num_in_system = num_waiting + s.num_currently_being_served
  qs.num_monitors = qs.num_monitors + 1
  next_monitoring(s)
end

function simulate(args::SimulationArgs)
  state = initialize_system(args)
  qs = QueueStats()
  schedule_initial_events(state)
  while (should_continue_simulation(state, args, qs))
    e = pop!(state.calendar)
    handle_event(e, state, qs)
  end
  qs.average_wait_time = qs.total_wait_time / qs.total_departures
  qs.average_system_time = qs.total_system_time / qs.total_departures
  return qs
end

# convenience functions

MM1(λ::Integer, μ::Integer, time::Integer) = simulate(SimulationArgs(time, 0, [list(QueueEdge(QueueProperties(0, Exponential(1/λ), Exponential(1/μ), 1, -1), QueueProperties(0, Exponential(1/λ), Exponential(1/μ), 1, -1), 0))]))
MMN(λ::Integer, μ::Integer, servers::Integer, time::Integer) = simulate(SimulationArgs(time, 0, [list(QueueEdge(QueueProperties(0, Exponential(1/λ), Exponential(1/μ), servers, -1), QueueProperties(0, Exponential(1/λ), Exponential(1/μ), servers, -1), 1, -1))]))
