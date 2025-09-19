import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import message_types.{type Message, type ParentMessage, AddNeighbors, Shutdown}

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
