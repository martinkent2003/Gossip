import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import message_types.{
  type Message, type ParentMessage, AddNeighbors, Converged, Gossip, PushSum,
  Shutdown, StartPushSum,
}

pub type Node {
  Node(
    id: Int,
    parent: Subject(ParentMessage),
    neighbors: List(Subject(Message)),
    rumor_count: Int,
    //algorithm: String,
    //ratio: Float,
    s: Float,
    w: Float,
    stable_count: Int,
  )
}

pub fn handle_message(node: Node, message: Message) -> actor.Next(Node, Message) {
  case message {
    Shutdown -> actor.stop()
    AddNeighbors(neighbors) -> {
      //io.println("Previous neighbors: " <> int.to_string(list.length(node.neighbors)))
      let new_node = Node(..node, neighbors: neighbors)
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
          let new_node = Node(..node, rumor_count: node.rumor_count + 1)
          // io.println(
          //   "Node "
          //   <> int.to_string(node.id)
          //   <> " has received a total of "
          //   <> int.to_string(node.rumor_count),
          // )
          actor.continue(new_node)
        }
      }
    }
    StartPushSum -> {
      io.println("Push-Sum started")

      let half_s = node.s /. 2.0
      let half_w = node.w /. 2.0
      let new_node = Node(..node, s: half_s, w: half_w)

      let random_neighbor = list.first(list.sample(node.neighbors, 1))
      case random_neighbor {
        Ok(random_neighbor) -> {
          process.send(random_neighbor, PushSum(half_s, half_w))
        }
        _ -> io.println("what? does this node have no neighbor?")
      }

      actor.continue(new_node)
    }
    PushSum(s, w) -> {
      let current_ratio = node.s /. node.w
      let new_s = node.s +. s
      let new_w = node.w +. w

      let half_s = new_s /. 2.0
      let half_w = new_w /. 2.0
      let new_ratio = half_s /. half_w

      let difference = float.absolute_value(current_ratio -. new_ratio)
      let new_stable_count = case difference <. 10.0e-10 {
        True -> node.stable_count + 1
        False -> 0
      }

      case new_stable_count >= 3 {
        True -> {
          io.println(
            "Node "
            <> int.to_string(node.id)
            <> " has converged with ratio "
            <> float.to_string(new_ratio)
            <> " and difference "
            <> float.to_string(difference),
          )
          process.send(node.parent, Converged)
          actor.stop()
        }
        False -> {
          // io.println(
          //   "Node "
          //   <> int.to_string(node.id)
          //   <> " has a ratio s/w of "
          //   <> float.to_string(new_ratio),
          // )
          let new_node =
            Node(..node, s: half_s, w: half_w, stable_count: new_stable_count)
          let random_neighbor = list.first(list.sample(node.neighbors, 1))
          case random_neighbor {
            Ok(random_neighbor) -> {
              process.send(random_neighbor, PushSum(half_s, half_w))
            }
            _ -> io.println("what? does this node have no neighbor?")
          }

          actor.continue(new_node)
        }
      }
    }
  }
  //neighbor message from parent to populat neihbor set
  //message from other actor to update gossip/push-sum
}
