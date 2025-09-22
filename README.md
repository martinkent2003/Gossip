# Gossip Protocol Project

[![Package Version](https://img.shields.io/hexpm/v/gossip)](https://hex.pm/packages/gossip)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gossip/)

### Team Members

Alex Vargas  
Martin Kent

### What's Working

Our project works under the following flow:
- The main process interprets the command-line arguments and starts a parent actor
- The parent actor creates the number of nodes specified
- The parent actor sends each node their neighbors as a list of subjects according to the specified topology
- The parent actor sends a message to a node depending on the algorithm specified, also sends a message to the main process to start the timer
- Nodes continue to send messages until one reaches the termination condition and stops transmitting
- The node sends a converged message to the parent actor, who notifies the main process to stop the timer and print the runtime

This works for all algorithms and topologies. As a node only passes a message when it receives one, the program will terminate once any one node reaches the termination condition.

### Largest Network Sizes

We tested network sizes on orders of 10. The following is a list of the largest network size for each topology-algorithm, along with the limiting factor that prevented us from reaching the next order of 10.

**Line Gossip:** 1,000,000 (Max # of Processes)  
**Line Push-Sum:** 1,000 (Time)

**3D Gossip:** 1,000,000 (Max # of Processes)  
**3D Push-Sum:** 10,000 (Time)

**Imperfect 3D Gossip:** 1,000,000 (Max # of Processes)  
**Imperfect 3D Push-Sum:** 100,000 (Time)

**Full Gossip:** 10,000 (Memory Space)  
**Full Push-Sum:** 10,000 (Memory Space)

