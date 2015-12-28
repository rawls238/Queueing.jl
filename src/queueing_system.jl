# Exported types

type QueueProperties
  queue_id::Integer
  interarrival::Distribution
  service::Distribution
  num_servers::Integer
  max_capacity::Integer
  function QueueProperties(i::Distribution, s::Distribution, servers::Integer, cap::Integer)
    new(-1, i, s, servers, cap)
  end
end

type QueueNode
  props::QueueProperties
  is_entering::Bool
  edges::AbstractArray
end

type QueueEdge
  to::QueueNode
  weight::Float64
  function QueueEdge(to, weight::Float64)
    if weight < 0 || weight > 1
      throw(ArgumentError("weight must be between 0 and 1"))
    end
    new(to, weight)
  end
end

==(a::QueueProperties, b::QueueProperties) = a.interarrival == b.interarrival &&
                   a.service == b.service && a.num_servers == b.num_servers && a.max_capacity == b.max_capacity
hash(a::QueueProperties, h::UInt) = hash(a.interarrival, hash(a.service, hash(a.num_servers, hash(a.max_capacity, h))))

==(a::QueueNode, b::QueueNode) = a.props == b.props && a.is_entering == b.is_entering && a.edges == b.edges
hash(a::QueueNode, h::UInt) = hash(a.props, hash(a.is_entering, hash(a.edges, h)))

==(a::QueueEdge, b::QueueEdge) = a.to == b.to && a.weight == b.weight
hash(a::QueueEdge, h::UInt) = hash(a.to, hash(weight, h))

type SimulationArgs
  max_time::Float64
  max_customers::Float64
  topology::AbstractArray{QueueNode}
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

# Implementation types

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

type SingleQueueState
  queue_id::Integer
  server_state::Dict{Server, Any}
  props::QueueProperties
  edges::AbstractArray{QueueEdge}
  waiting::Queue
  num_currently_being_served::Integer
end

type SimulationState
  calendar::MutableBinaryHeap{Event}
  current_event::Event
  system_time::Float64
  entering_queue_ids::AbstractArray{Integer}
  queue_states::AbstractArray{SingleQueueState}
end

<=(a::Event, b::Event) = a.scheduled_time <= b.scheduled_time
==(a::Event, b::Event) = isequal(a.scheduled_time, b.scheduled_time)
>=(a::Event, b::Event) = a.scheduled_time >= b.scheduled_time
<(a::Event, b::Event) = a.scheduled_time < b.scheduled_time
>(a::Event, b::Event) =  a.scheduled_time > b.scheduled_time

# Initialization functions

function initialize_system(args::SimulationArgs)
  queue_states = []
  queue_systems = Dict{QueueNode, QueueNode}()
  entering_queue_ids = []
  for i in 1:length(args.topology)
    cur = args.topology[i]
    if cur.is_entering
      push!(entering_queue_ids, i)
    end
    cur.props.queue_id = i
    queue_systems[cur] = cur
  end

  for queue in queue_systems
    for j in 1:length(queue.first.edges)
      queue.first.edges[j].to = queue_systems[queue.first.edges[j].to]
    end
    push!(queue_states, SingleQueueState(queue.first.props.queue_id, Dict{Server, Any}(), queue.first.props, queue.first.edges, Queue(Event), 0))
  end

  state = SimulationState(mutable_binary_minheap(Event), Event(1, "", 0, 0, Server(0)), 0, entering_queue_ids, queue_states)
  initialize_servers(state)
  return state
end

function schedule_initial_events(state::SimulationState)
  for queue_id in state.entering_queue_ids
    next_birth(state, queue_id)
  end
  next_monitoring(state)
end

# Execution functions

function should_continue_simulation(state::SimulationState, args::SimulationArgs, qs::QueueStats)
  stop_from_time = args.max_time > 0 && state.system_time < args.max_time
  stop_from_customers = args.max_customers > 0 && qs.num_departures < args.max_customers
  return stop_from_time || stop_from_customers
end

function system_at_capacity(s::SimulationState, id::Integer)
  c = s.queue_states[id]
  return c.props.max_capacity <= 0 || ((length(c.waiting) + c.num_currently_being_served) < c.props.max_capacity)
end

function handle_event(e::Event, s::SimulationState, qs::QueueStats)
  s.system_time = e.scheduled_time
  if e.event_type == "birth"
    if system_at_capacity(s, e.queue_id)
      return birth(e, s, qs)
    else
      return next_birth(s, e.queue_id)
    end
  elseif e.event_type == "death"
    return death(e, s, qs)
  elseif e.event_type == "monitoring"
    return monitoring(s, qs)
  end
end

# Server related functions

function initialize_servers(s::SimulationState)
  for queue in s.queue_states
    for j in 1:queue.props.num_servers
      queue.server_state[Server(j)] = null
    end
  end
end

function find_server(s::SimulationState, queue_id::Integer)
  for (k, v) in s.queue_states[queue_id].server_state
    if v == null
      return k
    end
  end
  return null
end


function free_server(e::Event, s::SimulationState)
  s.queue_states[e.queue_id].server_state[e.server] = null
  s.queue_states[e.queue_id].num_currently_being_served -= 1
end

function allocate_server(e::Event, server::Server, state::SimulationState)
  state.queue_states[e.queue_id].server_state[server] = true
  state.queue_states[e.queue_id].num_currently_being_served += 1
end

# birth related functions

function birth(e::Event, s::SimulationState, qs::QueueStats)
    enqueue!(s.queue_states[e.queue_id].waiting, e)
    queue_id = e.queue_id
    if find_server(s, queue_id) != null
      next_death(s, queue_id, qs)
    end
    next_birth(s, queue_id)
end

function next_birth(s::SimulationState, id::Integer)
  if id ∈ s.entering_queue_ids
    next_time = s.system_time + rand(s.queue_states[id].props.interarrival)
    push!(s.calendar, Event(id, "birth", next_time, next_time, Server(-1)))
  end
end

# death related functions
function possibly_exit_system(e::Event, s::SimulationState, qs::QueueStats)
  current_queue_id = e.queue_id
  current_queue_state = s.queue_states[current_queue_id]
  sum = 0.0
  r = rand()

  for edge in current_queue_state.edges
    sum += edge.weight
    if r <= sum
      push!(s.calendar, Event(edge.to.props.queue_id, "birth", e.enter_time, s.system_time, Server(-1)))
      return
    end
  end

  #assume here that if we find no outgoing edge in the system, then we exit the system
  qs.total_departures = qs.total_departures + 1
end


function death(e::Event, s::SimulationState, qs::QueueStats)
  free_server(e, s)
  if length(s.queue_states[e.queue_id].waiting) > 0
    next_death(s, e.queue_id, qs)
  end
  possibly_exit_system(e, s, qs)
end

function next_death(s::SimulationState, queue_id::Integer, qs::QueueStats)
  current_queue_state = s.queue_states[queue_id]
  e = dequeue!(current_queue_state.waiting)
  server = find_server(s, queue_id)
  next_time = s.system_time + rand(current_queue_state.props.service)
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
  next_time = s.system_time + rand(Exponential(10))
  push!(s.calendar, Event(1, "monitoring", next_time, next_time, Server(-1)))
end

function monitoring(s::SimulationState, qs::QueueStats)
  for queue in s.queue_states
    num_waiting = length(queue.waiting)
    qs.total_num_waiting += num_waiting
    qs.num_in_system += num_waiting + queue.num_currently_being_served
  end
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

MM1(λ::Integer, μ::Integer, time::Integer) = simulate(SimulationArgs(time, 0, [QueueNode(QueueProperties(Exponential(1/λ), Exponential(1/μ), 1, -1), true, [])]))
MMN(λ::Integer, μ::Integer, servers::Integer, time::Integer) = simulate(SimulationArgs(time, 0, [QueueNode(QueueProperties(Exponential(1/λ), Exponential(1/μ), servers, -1), true, [])]))
