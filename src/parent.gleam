import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import message_types.{
  type Message, type ParentMessage, AddNeighbors, Converged, Gossip, ParentInit,
  Received, StartPushSum,
}
import node.{Node, handle_message}

@external(erlang, "math", "pow")
fn pow(base: Float, exp: Float) -> Float

@external(erlang, "math", "ceil")
fn ceil(x: Float) -> Float

pub fn start_parent(
  num_nodes: Int,
  topology: String,
  algorithm: String,
  main_process: Subject(String),
) {
  actor.new_with_initialiser(1000, fn(self_subject) {
    actor.send(self_subject, ParentInit)
    let state =
      ParentState(
        num_nodes,
        0,
        topology,
        algorithm,
        self_subject,
        main_process,
        dict.new(),
      )
    let _result =
      Ok(
        actor.initialised(state)
        |> actor.returning(self_subject),
      )
  })
  |> actor.on_message(handle_message_parent)
  |> actor.start
}

fn handle_message_parent(
  state: ParentState,
  message: ParentMessage,
) -> actor.Next(ParentState, ParentMessage) {
  case message {
    ParentInit -> {
      let new_state = ParentState(..state, nodes: logic(state))
      actor.continue(new_state)
    }
    Received -> {
      let empty = dict.is_empty(state.nodes)
      let new_state = ParentState(..state, nodes_ready: state.nodes_ready + 1)
      case new_state.nodes_ready == new_state.num_nodes, empty {
        True, False -> {
          process.send(state.main_process, "Starting Algorithm")
          let assert Ok(node) = dict.get(state.nodes, 1)
          case state.algorithm {
            "gossip" -> process.send(node, Gossip)
            "push-sum" -> process.send(node, StartPushSum)
            _ -> Nil
          }
          Nil
        }
        True, True -> process.send(state.self, Received)
        False, _ -> Nil
      }
      actor.continue(new_state)
    }
    Converged -> {
      process.send(state.main_process, "Done")
      actor.continue(state)
    }
  }
}

pub type ParentState {
  ParentState(
    num_nodes: Int,
    nodes_ready: Int,
    topology: String,
    algorithm: String,
    self: process.Subject(ParentMessage),
    main_process: process.Subject(String),
    nodes: Dict(Int, Subject(Message)),
  )
}

pub fn logic(state: ParentState) -> Dict(Int, Subject(Message)) {
  //first we spawn num_nodes amount of actors, get back the subject, and store them in a hashmap
  //id: subject of actor, value: list of neighbors subjects

  let actors: Dict(Int, Subject(Message)) = dict.new()
  let actors = seed_actors(state.num_nodes, state.self, actors)

  io.println(
    "Created all actors, now testing for length of actors: "
    <> int.to_string(dict.size(actors)),
  )

  //constant
  case state.topology {
    "full" -> {
      io.println("Creating full topology")
      full_topology(state.num_nodes, actors)
    }
    "line" -> {
      io.println("Creating line topology")
      line_topology(state.num_nodes, actors)
    }
    "3D" -> {
      io.println("Creating 3D topology")
      td_topology(state.num_nodes, actors, False)
    }
    "imp3D" -> {
      io.println("Creating imp3D topology")
      td_topology(state.num_nodes, actors, True)
    }
    _ -> io.println("Invalid topology")
  }

  //here we would run the algorithm on the created topology
  //start timer here 

  case state.algorithm {
    "gossip" -> {
      io.println("Running gossip algorithm")
    }
    "push-sum" -> {
      io.println("Running push-sum algorithm")
    }
    _ -> io.println("Invalid algorithm")
  }

  actors
}

//seeding actors recursive loop:
pub fn seed_actors(
  num_nodes: Int,
  parent_process: Subject(ParentMessage),
  actors: Dict(Int, Subject(Message)),
) -> Dict(Int, Subject(Message)) {
  case num_nodes {
    0 -> {
      io.println("Created all nodes")
      actors
    }
    _ -> {
      let init_node =
        Node(
          id: num_nodes,
          parent: parent_process,
          neighbors: [],
          rumor_count: 0,
          s: int.to_float(num_nodes),
          w: 1.0,
          stable_count: 0,
        )
      let assert Ok(actor) =
        actor.new(init_node) |> actor.on_message(handle_message) |> actor.start
      let subject = actor.data
      let actors = dict.insert(actors, num_nodes, subject)
      seed_actors(num_nodes - 1, parent_process, actors)
    }
  }
}

//line topology creation:

pub fn line_topology(num_nodes: Int, actors: Dict(Int, Subject(Message))) -> Nil {
  //iterate through the dict and assign neighbors
  //first node only has one neighbor, second to last node only has one neighbor, all others have two neighbors
  //node 1 -> node 2
  //node n -> node n-1
  //node i -> node i-1, node i+1
  line_topology_recursion(1, num_nodes, actors)
  Nil
}

fn line_topology_recursion(
  current: Int,
  num_nodes: Int,
  actors: Dict(Int, Subject(Message)),
) -> Nil {
  case current {
    1 -> {
      //only has one neighbor
      let neighbor = dict.get(actors, 2)
      case neighbor {
        Ok(neighbor) -> {
          let node = dict.get(actors, 1)
          case node {
            Ok(node) -> {
              process.send(node, AddNeighbors([neighbor]))
              //io.println("Node 1 added neighbor 2")
              line_topology_recursion(current + 1, num_nodes, actors)
            }
            _ -> {
              io.println("Node 1 not found")
              Nil
            }
          }
        }
        _ -> {
          io.println("Neighbor 2 not found")
          Nil
        }
      }
    }
    n if n == num_nodes -> {
      //only has one neighbor
      let neighbor = dict.get(actors, num_nodes - 1)
      case neighbor {
        Ok(neighbor) -> {
          let node = dict.get(actors, num_nodes)
          case node {
            Ok(node) -> {
              process.send(node, AddNeighbors([neighbor]))
              //io.println("Node " <> int.to_string(num_nodes) <> " added neighbor " <> int.to_string(num_nodes - 1))
              Nil
            }
            _ -> {
              io.println("Node " <> int.to_string(num_nodes) <> " not found")
              Nil
            }
          }
        }
        _ -> {
          io.println(
            "Neighbor " <> int.to_string(num_nodes - 1) <> " not found",
          )
          Nil
        }
      }
    }
    _ -> {
      //has two neighbors
      let neighbor1 = dict.get(actors, current - 1)
      let neighbor2 = dict.get(actors, current + 1)
      case neighbor1, neighbor2 {
        Ok(neighbor1), Ok(neighbor2) -> {
          let node = dict.get(actors, current)
          case node {
            Ok(node) -> {
              process.send(node, AddNeighbors([neighbor1, neighbor2]))
              //io.println("Node " <> int.to_string(current) <> " added neighbors " <> int.to_string(current - 1) <> " and " <> int.to_string(current + 1))
              line_topology_recursion(current + 1, num_nodes, actors)
            }
            _ -> {
              io.println("Node " <> int.to_string(current) <> " not found")
            }
          }
        }
        _, _ -> {
          io.println(
            "Neighbors for node " <> int.to_string(current) <> " not found",
          )
          Nil
        }
      }
    }
  }
  Nil
}

//full topology creation:

pub fn full_topology(num_nodes: Int, actors: Dict(Int, Subject(Message))) -> Nil {
  //iterate through the dict and assign all other nodes as neighbors
  let all_actor_subjects = dict.values(actors)
  let current = 1
  full_topology_recursion(current, num_nodes, all_actor_subjects, actors)
  Nil
}

pub fn full_topology_recursion(
  current: Int,
  num_nodes: Int,
  all_actor_subjects: List(Subject(Message)),
  actors: Dict(Int, Subject(Message)),
) -> Nil {
  case current {
    n if n > num_nodes -> {
      //finished
      io.println("Finished creating full topology")
      Nil
    }
    _ -> {
      let node = dict.get(actors, current)
      case node {
        Ok(node) -> {
          //remove self from neighbor list
          let neighbors =
            list.filter(all_actor_subjects, fn(subject) { subject != node })
          process.send(node, AddNeighbors(neighbors))
          full_topology_recursion(
            current + 1,
            num_nodes,
            all_actor_subjects,
            actors,
          )
        }
        _ -> {
          io.println("Node " <> int.to_string(current) <> " not found")
          Nil
        }
      }
    }
  }
  Nil
}

/// 3D Topology Creation
pub fn td_topology(
  num_nodes: Int,
  actors: Dict(Int, Subject(Message)),
  imp: Bool,
) -> Nil {
  let dimension_size =
    pow(int.to_float(num_nodes), 1.0 /. 3.0) |> ceil |> float.round
  td_topology_recursion(0, num_nodes, dimension_size, actors, imp)
}

fn td_topology_recursion(
  current: Int,
  num_nodes: Int,
  dimension_size: Int,
  actors: Dict(Int, Subject(Message)),
  imp: Bool,
) -> Nil {
  case current == num_nodes {
    True -> Nil
    False -> {
      let neighbors = []
      //x-axis neigbhors
      let cand = current - 1
      let neighbors = case
        cand >= 0 && same_row(current, cand, dimension_size)
      {
        True -> update_neighbors(cand, neighbors, actors)
        False -> neighbors
      }

      let cand = current + 1
      let neighbors = case
        cand < num_nodes && same_row(current, cand, dimension_size)
      {
        True -> update_neighbors(cand, neighbors, actors)
        False -> neighbors
      }
      //y-axis neighbors
      let cand = current - dimension_size
      let neighbors = case
        cand >= 0 && same_slab(current, cand, dimension_size)
      {
        True -> update_neighbors(cand, neighbors, actors)
        False -> neighbors
      }

      let cand = current + dimension_size
      let neighbors = case
        cand < num_nodes && same_slab(current, cand, dimension_size)
      {
        True -> update_neighbors(cand, neighbors, actors)
        False -> neighbors
      }
      //z-axis neighbors
      let cand = current - { dimension_size * dimension_size }
      let neighbors = case cand >= 0 {
        True -> update_neighbors(cand, neighbors, actors)
        False -> neighbors
      }

      let cand = current + { dimension_size * dimension_size }
      let neighbors = case cand < num_nodes {
        True -> update_neighbors(cand, neighbors, actors)
        False -> neighbors
      }

      // Only assign random neighbor if imp3D AND another available actor
      let neighbors = case imp && list.length(neighbors) < num_nodes - 1 {
        True -> choose_random_neighbor(current, num_nodes, neighbors, actors)
        False -> neighbors
      }

      case dict.get(actors, current + 1) {
        Ok(node) -> process.send(node, AddNeighbors(neighbors))
        Error(_) -> Nil
      }
      td_topology_recursion(current + 1, num_nodes, dimension_size, actors, imp)
    }
  }
}

/// 3D Topology Helper Functions
fn same_row(i: Int, j: Int, n: Int) -> Bool {
  { i / n } == { j / n }
}

fn same_slab(i: Int, j: Int, n: Int) -> Bool {
  { i / { n * n } } == { j / { n * n } }
}

fn update_neighbors(
  cand: Int,
  neighbors: List(Subject(Message)),
  actors: Dict(Int, Subject(Message)),
) -> List(Subject(Message)) {
  case dict.get(actors, cand + 1) {
    Ok(value) -> {
      list.append(neighbors, [value])
    }
    Error(_) -> neighbors
  }
}

fn choose_random_neighbor(
  current: Int,
  num_nodes: Int,
  neighbors: List(Subject(Message)),
  actors: Dict(Int, Subject(Message)),
) -> List(Subject(Message)) {
  let cand = int.random(num_nodes)

  let neighbor_exists: Bool = {
    let assert Ok(subject) = dict.get(actors, cand + 1)
    case list.find(neighbors, fn(x) { x == subject }) {
      Ok(_) -> True
      Error(_) -> False
    }
  }

  case cand == current, neighbor_exists {
    True, _ | False, True ->
      choose_random_neighbor(current, num_nodes, neighbors, actors)
    False, False -> {
      update_neighbors(cand, neighbors, actors)
    }
  }
}
