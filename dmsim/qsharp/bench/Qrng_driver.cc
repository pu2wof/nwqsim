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

class DMSimSimulator;

extern "C" void Qrng__SampleRandomNumber();
extern "C" Microsoft::Quantum::IRuntimeDriver* GetDMSim(); 

int main(int argc, char *argv[])
{
    MPI_Init(&argc, &argv);
    Microsoft::Quantum::IRuntimeDriver* dmsim = GetDMSim();
    Microsoft::Quantum::InitializeQirContext(dmsim, false);
    Qrng__SampleRandomNumber();
    MPI_Finalize();
    return 0;
}
