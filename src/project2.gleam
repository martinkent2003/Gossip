import argv
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/time/duration
import gleam/time/timestamp
import parent

const topologies = ["full", "line", "3D", "imp3D"]

const algorithms = ["gossip", "push-sum"]

pub fn main() -> Nil {
  //take in the argumennts
  let args = argv.load().arguments
  //check that we have three arguments
  case args {
    [arg1, arg2, arg3] -> {
      let num_nodes = int.parse(arg1)
      let topology = arg2
      let algorithm = arg3
      //check the number of nodes is an integer
      case num_nodes {
        Ok(num_nodes) -> {
          io.println("Number of nodes: " <> int.to_string(num_nodes))
          let valid_topology = list.contains(topologies, topology)
          let valid_algorithm = list.contains(algorithms, algorithm)
          case valid_topology, valid_algorithm {
            True, True -> {
              io.println("Topology: " <> topology)
              io.println("Algorithm: " <> algorithm)
              let main_process = process.new_subject()
              let assert Ok(_parent) =
                parent.start_parent(
                  num_nodes,
                  topology,
                  algorithm,
                  main_process,
                )
              // Receive message to start timer
              let response = process.receive_forever(main_process)
              io.println(response)
              let start = timestamp.system_time()
              let response = process.receive_forever(main_process)
              io.println(response)
              // Receive message to end timer
              let time =
                duration.to_seconds(timestamp.difference(
                  start,
                  timestamp.system_time(),
                ))
              echo "Program took " <> float.to_string(time) <> " seconds"
              Nil
            }
            False, _ ->
              io.println(
                "Invalid topology. Valid topologies are: full, line, 3D, imp3D",
              )
            _, False ->
              io.println(
                "Invalid algorithm. Valid algorithms are: gossip, push-sum",
              )
          }
        }
        Error(_) -> io.println(arg1 <> " is not a valid integer")
      }
    }
    _ ->
      io.println("Please provide two string arguments, e.g. gleam run Joe 42")
  }
}
