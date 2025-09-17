import gleam/erlang/process
import gleam/float
import gleam/list
import argv
//import gleam/erlang/process
import gleam/int
import gleam/io
//import gleam/list
import gleam/time/timestamp
import gleam/time/duration

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
          io.println ("Number of nodes: " <> int.to_string(num_nodes))
          let valid_topology = list.contains(topologies, topology)
          let valid_algorithm = list.contains(algorithms, algorithm)
          case valid_topology, valid_algorithm {
            True, True -> {
              io.println ("Topology: " <> topology)
              io.println ("Algorithm: " <> algorithm)
              logic(num_nodes, topology, algorithm)
            }
            False, _ -> io.println("Invalid topology. Valid topologies are: full, line, 3D, imp3D")
            _, False -> io.println("Invalid algorithm. Valid algorithms are: gossip, push-sum")
          }
        }
        Error(_) -> io.println(arg1 <> " is not a valid integer")
      }
      

    }
    _ -> io.println("Please provide two string arguments, e.g. gleam run Joe 42")
  }

}

fn logic(num_nodes: Int, topology: String, alogrithm: String) -> Nil {
  //here we create the topology
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