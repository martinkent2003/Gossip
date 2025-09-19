import gleam/erlang/process.{type Subject}

pub type ParentMessage {
  Received(id: Int)
  Converged(id: Int)
  //message from child to parent to indicate convergence
}

//actor logic here
pub type Message {
  //used to seed the 
  AddNeighbors(neighbors: List(Subject(Message)))
  //implement the inter-actor messages received
  Shutdown
}
