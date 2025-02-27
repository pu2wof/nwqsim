#include <stdio.h>
#include <mpi.h>
#include "../../src/util.h"
#include "../../src/dmsim_nvgpu_mpi.cuh"
//Use the NWQSim namespace to enable C++/CUDA APIs
using namespace NWQSim;

void prepare_circuit(Simulation &sim)
{
	sim.RZ(1.57079632679, 0);
	sim.SX(0);
	sim.RZ(1.57079632679, 0);
	sim.RZ(1.57079632679, 1);
	sim.SX(1);
	sim.RZ(1.57079632679, 1);
	sim.RZ(1.57079632679, 2);
	sim.SX(2);
	sim.RZ(1.57079632679, 2);
	sim.RZ(1.57079632679, 3);
	sim.SX(3);
	sim.RZ(1.57079632679, 3);
	sim.RZ(1.57079632679, 4);
	sim.SX(4);
	sim.RZ(1.57079632679, 4);
	sim.RZ(1.57079632679, 5);
	sim.SX(5);
	sim.RZ(1.57079632679, 5);
	sim.X(6);
	sim.X(7);
	sim.X(8);
	sim.CX(3, 5);
	sim.CX(5, 3);
	sim.CX(3, 5);
	sim.CX(2, 3);
	sim.CX(3, 2);
	sim.CX(2, 3);
	sim.CX(5, 8);
	sim.RZ(1.57079632679, 7);
	sim.SX(7);
	sim.RZ(1.57079632679, 7);
	sim.CX(6, 7);
	sim.RZ(-0.785398163397, 7);
	sim.CX(4, 7);
	sim.CX(7, 4);
	sim.CX(4, 7);
	sim.CX(1, 4);
	sim.CX(4, 1);
	sim.CX(1, 4);
	sim.CX(2, 1);
	sim.RZ(0.785398163397, 1);
	sim.CX(1, 4);
	sim.CX(4, 1);
	sim.CX(1, 4);
	sim.CX(6, 7);
	sim.CX(7, 6);
	sim.CX(6, 7);
	sim.CX(7, 4);
	sim.RZ(-0.785398163397, 4);
	sim.CX(1, 4);
	sim.CX(4, 1);
	sim.CX(1, 4);
	sim.CX(2, 1);
	sim.CX(1, 2);
	sim.CX(2, 1);
	sim.CX(1, 2);
	sim.RZ(0.785398163397, 2);
	sim.RZ(1.57079632679, 2);
	sim.SX(2);
	sim.RZ(1.57079632679, 2);
	sim.CX(2, 3);
	sim.CX(3, 2);
	sim.CX(2, 3);
	sim.RZ(0.785398163397, 7);
	sim.CX(4, 7);
	sim.CX(7, 4);
	sim.CX(4, 7);
	sim.CX(1, 4);
	sim.RZ(0.785398163397, 1);
	sim.RZ(-0.785398163397, 4);
	sim.CX(1, 4);
	sim.CX(1, 4);
	sim.CX(4, 1);
	sim.CX(1, 4);
	sim.CX(8, 5);
	sim.CX(5, 8);
	sim.RZ(1.57079632679, 5);
	sim.SX(5);
	sim.RZ(1.57079632679, 5);
	sim.CX(3, 5);
	sim.RZ(1.57079632679, 3);
	sim.SX(3);
	sim.RZ(1.57079632679, 3);
	sim.CX(2, 3);
	sim.CX(3, 2);
	sim.CX(2, 3);
	sim.CX(1, 2);
	sim.RZ(-0.785398163397, 2);
	sim.CX(1, 2);
	sim.CX(2, 1);
	sim.CX(1, 2);
	sim.CX(4, 1);
	sim.RZ(0.785398163397, 1);
	sim.CX(2, 1);
	sim.RZ(-0.785398163397, 1);
	sim.RZ(0.785398163397, 2);
	sim.CX(4, 1);
	sim.CX(1, 4);
	sim.CX(4, 1);
	sim.CX(1, 4);
	sim.CX(1, 2);
	sim.RZ(0.785398163397, 1);
	sim.RZ(-0.785398163397, 2);
	sim.CX(1, 2);
	sim.RZ(0.785398163397, 4);
	sim.RZ(1.57079632679, 4);
	sim.SX(4);
	sim.RZ(1.57079632679, 4);
	sim.RZ(1.57079632679, 5);
	sim.SX(5);
	sim.RZ(1.57079632679, 5);
	sim.RZ(-0.0490873852123, 1);
	sim.CX(1, 0);
	sim.RZ(0.0490873852123, 0);
	sim.CX(1, 0);
	sim.RZ(-0.0490873852123, 0);
	sim.CX(1, 4);
	sim.CX(2, 3);
	sim.CX(3, 2);
	sim.CX(2, 3);
	sim.CX(4, 1);
	sim.CX(1, 4);
	sim.RZ(-0.0981747704247, 4);
	sim.CX(4, 7);
	sim.CX(5, 8);
	sim.RZ(0.0981747704247, 7);
	sim.CX(4, 7);
	sim.CX(1, 4);
	sim.CX(4, 1);
	sim.CX(1, 4);
	sim.RZ(-0.196349540849, 1);
	sim.CX(1, 2);
	sim.RZ(0.196349540849, 2);
	sim.CX(1, 2);
	sim.RZ(-0.196349540849, 2);
	sim.CX(1, 2);
	sim.CX(2, 1);
	sim.CX(1, 2);
	sim.CX(2, 3);
	sim.CX(3, 2);
	sim.CX(2, 3);
	sim.RZ(-0.392699081699, 3);
	sim.RZ(-0.0981747704247, 7);
	sim.CX(6, 7);
	sim.CX(7, 6);
	sim.CX(6, 7);
	sim.CX(4, 7);
	sim.CX(7, 4);
	sim.CX(4, 7);
	sim.CX(6, 7);
	sim.CX(7, 6);
	sim.CX(6, 7);
	sim.CX(8, 5);
	sim.CX(5, 8);
	sim.CX(3, 5);
	sim.RZ(0.392699081699, 5);
	sim.CX(3, 5);
	sim.CX(2, 3);
	sim.CX(3, 2);
	sim.CX(2, 3);
	sim.CX(1, 2);
	sim.CX(2, 1);
	sim.CX(1, 2);
	sim.RZ(-0.785398163397, 1);
	sim.CX(1, 4);
	sim.RZ(0.785398163397, 4);
	sim.CX(1, 4);
	sim.RZ(-0.785398163397, 4);
	sim.CX(1, 4);
	sim.CX(4, 1);
	sim.CX(1, 4);
	sim.RZ(-0.0981747704247, 1);
	sim.CX(1, 0);
	sim.RZ(0.0981747704247, 0);
	sim.CX(1, 0);
	sim.RZ(-0.0981747704247, 0);
	sim.CX(1, 4);
	sim.CX(4, 1);
	sim.CX(1, 4);
	sim.RZ(-0.196349540849, 4);
	sim.CX(4, 7);
	sim.RZ(-0.392699081699, 5);
	sim.CX(3, 5);
	sim.CX(5, 3);
	sim.CX(3, 5);
	sim.RZ(0.196349540849, 7);
	sim.CX(4, 7);
	sim.CX(1, 4);
	sim.CX(4, 1);
	sim.CX(1, 4);
	sim.RZ(-0.392699081699, 1);
	sim.CX(1, 2);
	sim.RZ(0.392699081699, 2);
	sim.CX(1, 2);
	sim.RZ(-0.392699081699, 2);
	sim.CX(1, 2);
	sim.CX(2, 1);
	sim.CX(1, 2);
	sim.CX(0, 1);
	sim.CX(1, 0);
	sim.CX(0, 1);
	sim.RZ(-0.785398163397, 2);
	sim.CX(2, 3);
	sim.RZ(0.785398163397, 3);
	sim.CX(2, 3);
	sim.RZ(-0.785398163397, 3);
	sim.CX(2, 3);
	sim.CX(3, 2);
	sim.CX(2, 3);
	sim.RZ(-0.196349540849, 2);
	sim.CX(2, 1);
	sim.RZ(0.196349540849, 1);
	sim.CX(2, 1);
	sim.RZ(-0.196349540849, 1);
	sim.CX(1, 2);
	sim.CX(2, 1);
	sim.CX(1, 2);
	sim.RZ(-0.392699081699, 1);
	sim.RZ(-0.196349540849, 7);
	sim.CX(4, 7);
	sim.CX(7, 4);
	sim.CX(4, 7);
	sim.CX(1, 4);
	sim.RZ(0.392699081699, 4);
	sim.CX(1, 4);
	sim.RZ(-0.785398163397, 1);
	sim.CX(1, 0);
	sim.RZ(0.785398163397, 0);
	sim.CX(1, 0);
	sim.RZ(-0.785398163397, 0);
	sim.CX(0, 1);
	sim.CX(1, 0);
	sim.CX(0, 1);
	sim.RZ(-0.392699081699, 1);
	sim.CX(1, 2);
	sim.RZ(0.392699081699, 2);
	sim.CX(1, 2);
	sim.RZ(-0.785398163397, 1);
	sim.RZ(-0.392699081699, 2);
	sim.RZ(-0.392699081699, 4);
	sim.CX(1, 4);
	sim.RZ(0.785398163397, 4);
	sim.CX(1, 4);
	sim.RZ(-0.785398163397, 4);
	sim.CX(1, 4);
	sim.CX(4, 1);
	sim.CX(1, 4);
	sim.RZ(-0.785398163397, 1);
	sim.CX(1, 2);
	sim.RZ(0.785398163397, 2);
	sim.CX(1, 2);
	sim.RZ(-0.785398163397, 2);
	sim.RZ(1.57079632679, 0);
	sim.SX(0);
	sim.RZ(1.57079632679, 0);
	sim.RZ(1.57079632679, 1);
	sim.SX(1);
	sim.RZ(1.57079632679, 1);
	sim.RZ(1.57079632679, 2);
	sim.SX(2);
	sim.RZ(1.57079632679, 2);
	sim.RZ(1.57079632679, 3);
	sim.SX(3);
	sim.RZ(1.57079632679, 3);
	sim.RZ(1.57079632679, 4);
	sim.SX(4);
	sim.RZ(1.57079632679, 4);
	sim.RZ(1.57079632679, 7);
	sim.SX(7);
	sim.RZ(1.57079632679, 7);
}

int main(int argc, char *argv[])
{
	MPI_Init(&argc, &argv);
	Simulation sim;
	prepare_circuit(sim);
	sim.sim();
	MPI_Finalize();
	return 0;
}
