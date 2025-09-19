import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import message_types.{
  type Message, type ParentMessage, AddNeighbors, Converged, Gossip, Shutdown,
  StartPushSum,
}

pub type Node {
  Node(
    id: Int,
    parent: Subject(ParentMessage),
    neighbors: List(Subject(Message)),
    rumor_count: Int,
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
      let new_node =
        Node(
          id: node.id,
          parent: node.parent,
          neighbors: neighbors,
          rumor_count: node.rumor_count,
        )
      //io.println("Neighbors added: " <> int.to_string(list.length(neighbors)))
      actor.send(node.parent, message_types.Received)
      actor.continue(new_node)
    }
    Gossip -> {
      //Inintial message received from parent to inialize gossip
      //also the same as receiving a gossip message from another node
      //gets a random "sample" of 1 neighbor from the list (weird ass gleam syntax can't do list[i] but can do this)
      case node.rumor_count >= 10 {
        True -> {
          //let parent know we're done here
          //and stop actor
          io.println(
            "Node "
            <> int.to_string(node.id)
            <> " has received a total of "
            <> int.to_string(node.rumor_count),
          )
          process.send(node.parent, Converged)
          actor.stop()
        }
        False -> {
          let random_neighbor = list.first(list.sample(node.neighbors, 1))
          case random_neighbor {
            Ok(random_neighbor) -> {
              let _ = process.send(random_neighbor, Gossip)
            }
            _ -> io.println("what? does this node have no neighbor?")
          }
          let new_node =
            Node(
              id: node.id,
              parent: node.parent,
              neighbors: node.neighbors,
              rumor_count: node.rumor_count + 1,
            )
          io.println(
            "Node "
            <> int.to_string(node.id)
            <> " has received a total of "
            <> int.to_string(node.rumor_count),
          )
          actor.continue(new_node)
        }
      }
    }
    StartPushSum -> {
      io.println("Push-Sum started")
      actor.continue(node)
    }
  }
  //neighbor message from parent to populat neihbor set
  //message from other actor to update gossip/push-sum
}
