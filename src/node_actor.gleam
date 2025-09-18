import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/time/duration
import gleam/time/timestamp

@external(erlang, "math", "pow")
fn pow(base: Float, exp: Float) -> Float

@external(erlang, "math", "ceil")
fn ceil(x: Float) -> Float

pub fn main() -> Nil {
  logic(1000, "full", "gossip")
  Nil
}

pub fn logic(num_nodes: Int, topology: String, alogrithm: String) -> Nil {
  //first we spawn num_nodes amount of actors, get back the subject, and store them in a hashmap
  //id: subject of actor, value: list of neighbors subjects
  let parent_process = process.new_subject()

  let init_node =
    Node(
      parent: parent_process,
      // will be replaced when actor starts
      neighbors: [],
    )
  let actors: Dict(Int, Subject(Message)) = dict.new()
  let actors = seed_actors(num_nodes, init_node, actors)

  io.println(
    "Created all actors, now testing for length of actors: "
    <> int.to_string(dict.size(actors)),
  )

  //constant
  case topology {
    "full" -> {
      io.println("Creating full topology")
      full_topology(num_nodes, actors)
    }
    "line" -> {
      io.println("Creating line topology")
      line_topology(num_nodes, actors)
    }
    "3D" -> {
      io.println("Creating 3D topology")
      td_topology(num_nodes, actors, False)
    }
    "imp3D" -> {
      io.println("Creating imp3D topology")
      td_topology(num_nodes, actors, True)
    }
    _ -> io.println("Invalid topology")
  }

  //here we would run the algorithm on the created topology
  //start timer here 
  let start = timestamp.system_time()
  case alogrithm {
    "gossip" -> {
      io.println("Running gossip algorithm")
    }
    "push-sum" -> {
      io.println("Running push-sum algorithm")
    }
    _ -> io.println("Invalid algorithm")
  }
  process.sleep(1230)
  let time =
    duration.to_seconds(timestamp.difference(start, timestamp.system_time()))
  echo "Program took " <> float.to_string(time) <> " seconds"
  //here we will create the algorithm
  Nil
}

//seeding actors recursive loop:
pub fn seed_actors(
  num_nodes: Int,
  init_node: Node,
  actors: Dict(Int, Subject(Message)),
) -> Dict(Int, Subject(Message)) {
  case num_nodes {
    0 -> {
      io.println("Created all nodes")
      actors
    }
    _ -> {
      let assert Ok(actor) =
        actor.new(init_node) |> actor.on_message(handle_message) |> actor.start
      let subject = actor.data
      let actors = dict.insert(actors, num_nodes, subject)
      io.print(" " <> int.to_string(num_nodes) <> " ")
      seed_actors(num_nodes - 1, init_node, actors)
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
    n if n >= num_nodes -> {
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
          io.println(
            "Node "
            <> int.to_string(current)
            <> " added "
            <> int.to_string(list.length(neighbors))
            <> " neighbors",
          )
          //io.println("Node " <> int.to_string(current) <> " added " <> int.to_string(list.length(neighbors)) <> " neighbors")
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
  let n = pow(int.to_float(num_nodes), 1.0 /. 3.0) |> ceil |> float.round
  td_topology_recursion(0, num_nodes, n, actors, imp)
}

fn td_topology_recursion(
  current: Int,
  num_nodes: Int,
  n: Int,
  actors: Dict(Int, Subject(Message)),
  imp: Bool,
) -> Nil {
  case current == num_nodes {
    True -> Nil
    False -> {
      let neighbors = []

      let cand = current - 1
      let neighbors = case cand >= 0 && same_row(current, cand, n) {
        True -> update_neighbors(cand, neighbors, actors)
        False -> neighbors
      }

      let cand = current + 1
      let neighbors = case cand < num_nodes && same_row(current, cand, n) {
        True -> update_neighbors(cand, neighbors, actors)
        False -> neighbors
      }

      let cand = current - n
      let neighbors = case cand >= 0 && same_slab(current, cand, n) {
        True -> update_neighbors(cand, neighbors, actors)
        False -> neighbors
      }

      let cand = current + n
      let neighbors = case cand < num_nodes && same_slab(current, cand, n) {
        True -> update_neighbors(cand, neighbors, actors)
        False -> neighbors
      }

      let cand = current - { n * n }
      let neighbors = case cand >= 0 {
        True -> update_neighbors(cand, neighbors, actors)
        False -> neighbors
      }

      let cand = current + { n * n }
      let neighbors = case cand < num_nodes {
        True -> update_neighbors(cand, neighbors, actors)
        False -> neighbors
      }

      // Only assign random neighbor if imp3D AND another available actor
      let neighbors = case imp && list.length(neighbors) < num_nodes - 1 {
        True -> choose_random_neighbor(current, num_nodes, neighbors, actors)
        False -> neighbors
      }

      io.println(
        "Node: "
        <> int.to_string(current + 1)
        <> " has "
        <> int.to_string(list.length(neighbors)),
      )
      case dict.get(actors, current + 1) {
        Ok(node) -> process.send(node, AddNeighbors(neighbors))
        Error(_) -> Nil
      }
      td_topology_recursion(current + 1, num_nodes, n, actors, imp)
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
      io.print(int.to_string(cand + 1) <> " ")
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

//actor logic here

pub type ParentMessage {
  Received(id: Int)
  Converged(id: Int)
  //message from child to parent to indicate convergence
}

pub type Message {
  //used to seed the 
  AddNeighbors(neighbors: List(Subject(Message)))
  //implement the inter-actor messages received
  Shutdown
}

pub type Node {
  Node(
    parent: Subject(ParentMessage),
    neighbors: List(Subject(Message)),
    //topology: String,
    //algorithm: String,
    //ratio: Float,
    //stable_count: Int,
  )
}

pub fn handle_message(node: Node, message: Message) -> actor.Next(Node, Message) {
  case message {
    Shutdown -> actor.stop()
    AddNeighbors(neighbors) -> {
      //io.println("Previous neighbors: " <> int.to_string(list.length(node.neighbors)))
      let new_node = Node(parent: node.parent, neighbors: neighbors)
      //io.println("Neighbors added: " <> int.to_string(list.length(neighbors)))
      actor.continue(new_node)
    }
  }
  //neighbor message from parent to populat neihbor set
  //message from other actor to update gossip/push-sum
}
