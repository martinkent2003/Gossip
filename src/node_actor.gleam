import gleam/io
import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import gleam/list
import gleam/int
import gleam/time/timestamp
import gleam/time/duration
import gleam/dict.{type Dict}

pub fn main() -> Nil {
    logic(1000, "full", "gossip")
    Nil
}



pub fn logic(num_nodes: Int, topology: String, alogrithm: String) -> Nil {
    //first we spawn num_nodes amount of actors, get back the subject, and store them in a hashmap
    //id: subject of actor, value: list of neighbors subjects
    let parent_process = process.new_subject()


    let init_node = Node(
        parent: parent_process,// will be replaced when actor starts
        neighbors: [],
    )
    let actors : Dict(Int, Subject(Message)) = dict.new()
    let actors = seed_actors(num_nodes, init_node, actors)

    io.print("Created all actors, now testing for length of actors: " <> int.to_string(dict.size(actors)))





    //constant
    case topology {
    "full" -> {
        io.println("Creating full topology")
        }
    "line" -> {
        io.println("Creating line topology")
    }
    "3D" -> {
        io.println("Creating 3D topology") 
    }
    "imp3D" -> {
        io.println("Creating imp3D topology")
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
    let time = duration.to_seconds_and_nanoseconds(timestamp.difference(start, timestamp.system_time()))
    echo time
    //here we will create the algorithm
    Nil
}

//seeding actors recursive loop:
pub fn seed_actors(num_nodes: Int, init_node: Node,  actors: Dict(Int, Subject(Message))) -> Dict(Int, Subject(Message)) {
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
        seed_actors(num_nodes-1, init_node, actors)
    }
  }
}


//actor logic here




pub type ParentMessage{
    Received(id: Int)
    Converged(id: Int)
    //message from child to parent to indicate convergence
}



pub type Message{
    //used to seed the 
    AddNeighbors(neighbors: List(Subject(Message)))
    //implement the inter-actor messages received
    Shutdown
}

pub type Node{
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
            io.println("Previous neighbors: " <> int.to_string(list.length(node.neighbors)))
            let new_node = Node(
                parent: node.parent,
                neighbors: neighbors,
            )
            io.println("Neighbors added: " <> int.to_string(list.length(neighbors)))
            actor.continue(new_node)
        }
    }
    //neighbor message from parent to populat neihbor set
    //message from other actor to update gossip/push-sum
}