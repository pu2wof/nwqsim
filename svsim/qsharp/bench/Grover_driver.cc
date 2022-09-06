// ---------------------------------------------------------------------------
// NWQSim: Northwest Quantum Simulation Environment 
// ---------------------------------------------------------------------------
// Ang Li, Senior Computer Scientist
// Pacific Northwest National Laboratory(PNNL), U.S.
// Homepage: http://www.angliphd.com
// GitHub repo: http://www.github.com/pnnl/NWQ-Sim
// PNNL-IPID: 32166, ECCN: EAR99, IR: PNNL-SA-161181
// BSD Lincese.
// ---------------------------------------------------------------------------
#include <cassert> 
#include <iostream> 
#include <memory> 
#include <mpi.h>
#include "QirRuntimeApi_I.hpp" 
#include "QirContext.hpp"
//#include "config.h"

class DMSimSimulator;

extern "C" void Microsoft__Quantum__Samples__SearchForMarkedInput(long nQubits, long idxMarked);
extern "C" Microsoft::Quantum::IRuntimeDriver* GetDMSim(); 

int main(int argc, char *argv[])
{
    MPI_Init(&argc, &argv);
    if (argc != 3)
    {
        printf("./Grover nQubits idxMarked\n");
        exit(0);
    }
    long nQubits = atoi(argv[1]);
    long idxMarked = atoi(argv[2]);
    Microsoft::Quantum::IRuntimeDriver* dmsim = GetDMSim();
    Microsoft::Quantum::InitializeQirContext(dmsim, false);
    Microsoft__Quantum__Samples__SearchForMarkedInput(nQubits, idxMarked);
    MPI_Finalize();
    return 0;
}
