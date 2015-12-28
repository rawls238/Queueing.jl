type QueueProperties
  interarrival::Distribution
  service::Distribution
  num_servers::Integer
  max_capacity::Integer
end

type QueueEdge
  to::QueueProperties
  weight::Float64
end

type QueueNode
  props::QueueProperties
  is_entering::Bool
  edges::AbstractArray{QueueEdge}
  function QueueNode(properties::QueueProperties)
    new(properties, true, [])
  end
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

type SimulationArgs
  max_time::Float64
  max_customers::Float64
  topology::AbstractArray{QueueNode}
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
  entering_queue_ids = []
  for i in 1:length(args.topology)
    cur = args.topology[i]
    if cur.is_entering
      push!(entering_queue_ids, i)
    end
    push!(queue_states, SingleQueueState(i, Dict{Server, Any}(), cur.props, cur.edges, Queue(Event), 0))
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

function death(e::Event, s::SimulationState, qs::QueueStats)
  free_server(e, s)
  if length(s.queue_states[e.queue_id].waiting) > 0
    next_death(s, e.queue_id, qs)
  end
  qs.total_departures = qs.total_departures + 1
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
  next_time = s.system_time + rand(Exponential(1))
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

MM1(λ::Integer, μ::Integer, time::Integer) = simulate(SimulationArgs(time, 0, [QueueNode(QueueProperties(Exponential(1/λ), Exponential(1/μ), 1, -1))]))
MMN(λ::Integer, μ::Integer, servers::Integer, time::Integer) = simulate(SimulationArgs(time, 0, [QueueNode(QueueProperties(Exponential(1/λ), Exponential(1/μ), servers, -1))]))
