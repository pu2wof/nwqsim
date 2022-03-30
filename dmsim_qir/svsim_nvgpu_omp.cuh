// ---------------------------------------------------------------------------
// NWQsim: Northwest Quantum Circuit Simulation Environment
// ---------------------------------------------------------------------------
// Ang Li, Senior Computer Scientist
// Pacific Northwest National Laboratory(PNNL), U.S.
// Homepage: http://www.angliphd.com
// GitHub repo: http://www.github.com/pnnl/NWQ-Sim
// PNNL-IPID: 32166, ECCN: EAR99, IR: PNNL-SA-161181
// BSD Lincese.
// ---------------------------------------------------------------------------
// File: svsim_nvgpu_sin.cuh
// Single GPU state-vector simulation with NVIDIA GPU backend.
// ---------------------------------------------------------------------------

#ifndef SVSIM_NVGPU_OMP_CUH
#define SVSIM_NVGPU_OMP_CUH

#include <assert.h>
#include <cooperative_groups.h>
#include <vector>
#include <omp.h>
#include <sstream>
#include <string>
#include <iostream>
#include <cuda.h>

//#include "noise_gate_AD_0.98.cuh"
//#include "noise_gate_AD_0.99.cuh"
//#include "noise_gate_DP_0.98.cuh"
//#include "noise_gate_DP_0.99.cuh"
//#include "noise_gate_BCSZ_0.98.cuh"
//#include "noise_gate_BCSZ_0.99.cuh"

#include "noise_gate_BCSZ_1_array.cuh"

#include "config.hpp"

namespace SVSim
{
using namespace cooperative_groups;
using namespace std;
class Gate;
class Simulation;
using func_t = void (*)(const Gate*, const Simulation*, ValType**, ValType**);

//Simulation runtime
__global__ void simulation_kernel(Simulation*, unsigned i_gpu);

//SVSim-QSharp supported gates
enum OP  //32 gates + measure
{
    X, Y, Z, H, S, T,  //6
    RI, RX, RY, RZ, EI, EX, EY, EZ,  // 8
    ControlledX, ControlledY, ControlledZ, //3
    ControlledH, ControlledS, ControlledT, //3
    ControlledRI, ControlledRX, //2
    ControlledRY, ControlledRZ, //2
    ControlledEI, ControlledEX, //2
    ControlledEY, ControlledEZ, //2
    AdjointS, AdjointT, //2
    ControlledAdjointS, ControlledAdjointT, //2
    Swap, //1
    Measure //1
};

//Name of the gate for tracing purpose
const char *OP_NAMES[] = {
    "X", "Y", "Z", "H", "S", "T", 
    "RI", "RX", "RY", "RZ", "EI", "EX", "EY", "EZ", 
    "ControlledX", "ControlledY", "ControlledZ",
    "ControlledH", "ControlledS", "ControlledT",
    "ControlledRI", "ControlledRX", 
    "ControlledRY", "ControlledRZ", 
    "ControlledEI", "ControlledEX",
    "ControlledEY", "ControlledEZ", 
    "AdjointS", "AdjointT", 
    "ControlledAdjointS", "ControlledAdjointT", 
    "Swap", "Measure"
};

//Define gate function pointers
extern __device__ func_t pX;
extern __device__ func_t pY;
extern __device__ func_t pZ;
extern __device__ func_t pH;
extern __device__ func_t pS;
extern __device__ func_t pT;
extern __device__ func_t pRI;
extern __device__ func_t pRX;
extern __device__ func_t pRY;
extern __device__ func_t pRZ;
extern __device__ func_t pEI;
extern __device__ func_t pEX;
extern __device__ func_t pEY;
extern __device__ func_t pEZ;
extern __device__ func_t pControlledX;
extern __device__ func_t pControlledY;
extern __device__ func_t pControlledZ;
extern __device__ func_t pControlledH;
extern __device__ func_t pControlledS;
extern __device__ func_t pControlledT;
extern __device__ func_t pControlledRI;
extern __device__ func_t pControlledRX;
extern __device__ func_t pControlledRY;
extern __device__ func_t pControlledRZ;
extern __device__ func_t pControlledEI;
extern __device__ func_t pControlledEX;
extern __device__ func_t pControlledEY;
extern __device__ func_t pControlledEZ;
extern __device__ func_t pAdjointS;
extern __device__ func_t pAdjointT;
extern __device__ func_t pControlledAdjointS;
extern __device__ func_t pControlledAdjointT;
extern __device__ func_t pSwap;
extern __device__ func_t pMeasure;

   

//Gate definition
class Gate
{
public:
    Gate(enum OP _op_name, func_t _op, IdxType _qubit, ValType _theta=0,
            IdxType _mask=0) : 
        op_name(_op_name), qubit(_qubit), theta(_theta),
        mask(_mask), op(_op) {}
    ~Gate() {}

    //applying the embedded gate operation on GPU side
    __device__ void exe_op(Simulation* sim, ValType** sv_real, ValType** sv_imag)
    {
        (*(this->op))(this, sim, sv_real, sv_imag);
    }
    //for dumping the gate
    void gateToString(std::stringstream& ss)
    {
        ss << OP_NAMES[op_name] << "(" << qubit << "," << theta << "," 
            << mask << ","
            << op << ");" << std::endl;
    }
    //Gate operation
    func_t op;
    //Gate name
    enum OP op_name;
    //Qubit 
    IdxType qubit;
    //Qubit rotation parameters
    ValType theta;
    //Multicontrolled Mask
    IdxType mask;

}; //end of Gate definition


class Circuit
{
public:
    Circuit(IdxType _n_qubits=0, IdxType _i_gpu=0):
        n_qubits(_n_qubits), i_gpu(_i_gpu), n_gates(0), circuit_gpu(NULL) {}
    ~Circuit() { clear(); }
    void append(Gate& g)
    {
        //printf("%s(theta:%lf,q:%llu,mask:%llu)\n",OP_NAMES[g.op_name], g.theta, g.qubit, g.mask);
        if (g.qubit >= n_qubits) 
        {
            printf("%s(theta:%lf,q:%llu,mask:%llu)\n",OP_NAMES[g.op_name], g.theta, g.qubit, g.mask);
            throw std::logic_error("Gate uses qubit out of range!");
        }
        circuit.push_back(g);
        n_gates++;
    }
    void AllocateQubit() 
    { 
        n_qubits++; 
        //printf("allocate 1 qubit, now in total: %lu\n",n_qubits);
    }
    void ReleaseQubit()
    {
        --n_qubits;
        //printf("release 1 qubit, now in total: %lu\n", n_qubits);
    }
    void clear()
    {
        circuit.clear();
        //n_qubits = 0;
        n_gates = 0;
        cudaSafeCall(cudaSetDevice(i_gpu));
        SAFE_FREE_GPU(circuit_gpu);
    }
    Gate* upload()
    {
        cudaSafeCall(cudaSetDevice(i_gpu));
        SAFE_FREE_GPU(circuit_gpu);
        SAFE_ALOC_GPU(circuit_gpu, n_gates*sizeof(Gate));
        cudaSafeCall(cudaMemcpy(circuit_gpu, circuit.data(), 
                    n_gates*sizeof(Gate), cudaMemcpyHostToDevice));
        return circuit_gpu;
    }
    std::string circuitToString()
    {
        stringstream ss;
        for (IdxType t=0; t<n_gates; t++)
            circuit[t].gateToString(ss);
        return ss.str();
    }
public:
    // number of qubits
    IdxType n_qubits;
    // number of gates
    IdxType n_gates;
    // which gpu this circuit is for
    IdxType i_gpu;
    vector<Gate> circuit;
    Gate* circuit_gpu;
};


class Simulation
{
public:
    Simulation(IdxType _n_gpus=N_PE, IdxType _n_qubits=N_QUBIT_SLOT) : 
        n_qubits(_n_qubits), n_gpus_org(_n_gpus), n_gpus(_n_gpus),
        dim((IdxType)1<<(n_qubits)), 
        half_dim((IdxType)1<<(n_qubits-1)),
        sv_size(dim*(IdxType)sizeof(ValType)),
        gpu_scale(floor(log((double)_n_gpus+0.5)/log(2.0))),
        lg2_m_gpu(n_qubits-gpu_scale),
        m_gpu((IdxType)1<<(lg2_m_gpu)),
        sv_size_per_gpu(sv_size/n_gpus),
        n_gates(0), 
        gpu_mem(0),
        sim_gpu(NULL),
        sv_real(NULL),
        sv_imag(NULL),
        m_real(NULL),
        circuit_handle_gpu(NULL)
    {
        if (!is_power_of_2(n_gpus))
        {
            std::cerr << "Error: Number of GPUs should be an exponential of 2." << std::endl;
            exit(1);
        }
        if (dim % n_gpus != 0)
        {
            std::cerr << "Error: Number of GPUs is too large or too small." << std::endl;
            exit(1);
        }
        //CPU side initialization
        SAFE_ALOC_HOST(sv_real_cpu, sv_size);
        SAFE_ALOC_HOST(sv_imag_cpu, sv_size);

        memset(sv_real_cpu, 0, sv_size);
        memset(sv_imag_cpu, 0, sv_size);
        //State-vector initial state [0..0] = 1
        sv_real_cpu[0] = 1.;
 
        SAFE_ALOC_HOST(circuit_handle, sizeof(Circuit*)*n_gpus);
        SAFE_ALOC_HOST(sv_real, sizeof(ValType*)*n_gpus);
        SAFE_ALOC_HOST(sv_imag, sizeof(ValType*)*n_gpus);
        SAFE_ALOC_HOST(m_real, sizeof(ValType*)*n_gpus);
        SAFE_ALOC_HOST(sim_gpu, sizeof(Simulation*)*n_gpus);
        SAFE_ALOC_HOST(circuit_handle_gpu, sizeof(Gate*)*n_gpus);

        //GPU side initialization
        for (unsigned d=0; d<n_gpus; d++)
        {
            circuit_handle[d] = new Circuit(0,d);
            cudaSafeCall(cudaSetDevice(d));
            //GPU memory allocation
            SAFE_ALOC_GPU(sv_real[d], sv_size_per_gpu);
            SAFE_ALOC_GPU(sv_imag[d], sv_size_per_gpu);
            SAFE_ALOC_GPU(m_real[d], sv_size_per_gpu);
            SAFE_ALOC_GPU(sim_gpu[d], sizeof(Simulation));
            gpu_mem += sv_size_per_gpu*3 + sizeof(Simulation);
            //GPU memory initilization
            cudaSafeCall(cudaMemcpy(sv_real[d], &sv_real_cpu[d*m_gpu], 
                        sv_size_per_gpu, cudaMemcpyHostToDevice));
            cudaSafeCall(cudaMemcpy(sv_imag[d], &sv_imag_cpu[d*m_gpu], 
                        sv_size_per_gpu, cudaMemcpyHostToDevice));
            cudaSafeCall(cudaMemset(m_real[d], 0, sv_size_per_gpu));
            //Enable direct interconnection
            for (unsigned g=0; g<n_gpus; g++)
            {
                if (g != d) cudaSafeCall(cudaDeviceEnablePeerAccess(g,0));
            }
        }
        //gate pointers
        SAFE_ALOC_HOST(gX, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gY, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gZ, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gH, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gS, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gT, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gRI, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gRX, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gRY, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gRZ, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gEI, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gEX, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gEY, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gEZ, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gControlledX, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gControlledY, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gControlledZ, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gControlledH, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gControlledS, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gControlledT, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gControlledRI, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gControlledRX, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gControlledRY, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gControlledRZ, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gControlledEI, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gControlledEX, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gControlledEY, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gControlledEZ, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gAdjointS, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gAdjointT, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gControlledAdjointS, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gControlledAdjointT, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gSwap, sizeof(func_t)*n_gpus);
        SAFE_ALOC_HOST(gMeasure, sizeof(func_t)*n_gpus);
        SetupGatePointers();

        //srand(RAND_SEED);
        srand(time(0));
    }

    ~Simulation()
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            cudaSafeCall(cudaSetDevice(d));
            if (circuit_handle[d] != NULL)
                delete circuit_handle[d];
            //GPU memory release
            SAFE_FREE_GPU(sv_real[d]);
            SAFE_FREE_GPU(sv_imag[d]);
            SAFE_FREE_GPU(sim_gpu[d]);
            for (unsigned g=0; g<n_gpus; g++)
            {
                if (g != d) cudaSafeCall(cudaDeviceDisablePeerAccess(g));
            }
        }
        //CPU side release
        SAFE_FREE_HOST(sv_real_cpu);
        SAFE_FREE_HOST(sv_imag_cpu);
        SAFE_FREE_HOST(circuit_handle);
        SAFE_FREE_HOST(sv_real);
        SAFE_FREE_HOST(sv_imag);
        SAFE_FREE_HOST(m_real);
        SAFE_FREE_HOST(sim_gpu);
        SAFE_FREE_HOST(circuit_handle_gpu);
        //Release gate func pointers
        SAFE_FREE_HOST(gX);
        SAFE_FREE_HOST(gY);
        SAFE_FREE_HOST(gZ);
        SAFE_FREE_HOST(gH);
        SAFE_FREE_HOST(gS);
        SAFE_FREE_HOST(gT);
        SAFE_FREE_HOST(gRI);
        SAFE_FREE_HOST(gRX);
        SAFE_FREE_HOST(gRY);
        SAFE_FREE_HOST(gRZ);
        SAFE_FREE_HOST(gEI);
        SAFE_FREE_HOST(gEX);
        SAFE_FREE_HOST(gEY);
        SAFE_FREE_HOST(gEZ);
        SAFE_FREE_HOST(gControlledX);
        SAFE_FREE_HOST(gControlledY);
        SAFE_FREE_HOST(gControlledZ);
        SAFE_FREE_HOST(gControlledH);
        SAFE_FREE_HOST(gControlledS);
        SAFE_FREE_HOST(gControlledT);
        SAFE_FREE_HOST(gControlledRI);
        SAFE_FREE_HOST(gControlledRX);
        SAFE_FREE_HOST(gControlledRY);
        SAFE_FREE_HOST(gControlledRZ);
        SAFE_FREE_HOST(gControlledEI);
        SAFE_FREE_HOST(gControlledEX);
        SAFE_FREE_HOST(gControlledEY);
        SAFE_FREE_HOST(gControlledEZ);
        SAFE_FREE_HOST(gAdjointS);
        SAFE_FREE_HOST(gAdjointT);
        SAFE_FREE_HOST(gControlledAdjointS);
        SAFE_FREE_HOST(gControlledAdjointT);
        SAFE_FREE_HOST(gSwap);
        SAFE_FREE_HOST(gMeasure);
    }
    void AllocateQubit()
    {
        //printf("allocate 1 qubit, now in total: %lu\n",n_qubits);
        for (unsigned d=0; d<n_gpus; d++)
        {
            circuit_handle[d]->AllocateQubit();
        }
    }
    void ReleaseQubit()
    {
        //printf("release 1 qubit at: %lu\n", qubit);
        //for (unsigned d=0; d<n_gpus; d++)
        //{
        //circuit_handle[d]->ReleaseQubit();
        //}
    }
    void SetupGatePointers()
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            cudaSafeCall(cudaSetDevice(d));
            cudaSafeCall(cudaMemcpyFromSymbol(&gX[d], pX, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gY[d], pY, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gZ[d], pZ, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gH[d], pH, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gS[d], pS, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gT[d], pT, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gRI[d], pRI, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gRX[d], pRX, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gRY[d], pRY, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gRZ[d], pRZ, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gEI[d], pEI, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gEX[d], pEX, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gEY[d], pEY, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gEZ[d], pEZ, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gControlledX[d], pControlledX, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gControlledY[d], pControlledY, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gControlledZ[d], pControlledZ, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gControlledH[d], pControlledH, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gControlledS[d], pControlledS, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gControlledT[d], pControlledT, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gControlledRI[d], pControlledRI, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gControlledRX[d], pControlledRX, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gControlledRY[d], pControlledRY, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gControlledRZ[d], pControlledRZ, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gControlledEI[d], pControlledEI, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gControlledEX[d], pControlledEX, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gControlledEY[d], pControlledEY, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gControlledEZ[d], pControlledEZ, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gAdjointS[d], pAdjointS, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gAdjointT[d], pAdjointT, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gControlledAdjointS[d], pControlledAdjointS, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gControlledAdjointT[d], pControlledAdjointT, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gSwap[d], pSwap, sizeof(func_t))); 
            cudaSafeCall(cudaMemcpyFromSymbol(&gMeasure[d], pMeasure, sizeof(func_t))); 
        }
    }

    // =============================== Standard Gates ===================================
    void X(IdxType qubit)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::X,gX[d],qubit);
            circuit_handle[d]->append(*G);
        }
    }
    void Y(IdxType qubit)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::Y,gY[d],qubit);
            circuit_handle[d]->append(*G);
        }
    }
    void Z(IdxType qubit)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::Z,gZ[d],qubit);
            circuit_handle[d]->append(*G);
        }
    }
    void H(IdxType qubit)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::H,gH[d],qubit);
            circuit_handle[d]->append(*G);
        }
    }
    void S(IdxType qubit)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::S,gS[d],qubit);
            circuit_handle[d]->append(*G);
        }
    }
    void T(IdxType qubit)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::T,gT[d],qubit);
            circuit_handle[d]->append(*G);
        }
    }
    void RI(ValType theta, IdxType qubit)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::RI,gRI[d],qubit,theta);
            circuit_handle[d]->append(*G);
        }
    }
    void RX(ValType theta, IdxType qubit)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::RX,gRX[d],qubit,theta);
            circuit_handle[d]->append(*G);
        }
    }
    void RY(ValType theta, IdxType qubit)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::RY,gRY[d],qubit,theta);
            circuit_handle[d]->append(*G);
        }
    }
    void RZ(ValType theta, IdxType qubit)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::RZ,gRZ[d],qubit,theta);
            circuit_handle[d]->append(*G);
        }
    }
    void EI(ValType theta, IdxType qubit)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::EI,gEI[d],qubit,theta);
            circuit_handle[d]->append(*G);
        }
    }
    void EX(ValType theta, IdxType qubit)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::EX,gEX[d],qubit,theta);
            circuit_handle[d]->append(*G);
        }
    }
    void EY(ValType theta, IdxType qubit)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::EY,gEY[d],qubit,theta);
            circuit_handle[d]->append(*G);
        }
    }
    void EZ(ValType theta, IdxType qubit)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::EZ,gEZ[d],qubit,theta);
            circuit_handle[d]->append(*G);
        }
    }
    void ControlledX(IdxType qubit, IdxType mask)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::ControlledX,gControlledX[d],qubit,0,mask);
            circuit_handle[d]->append(*G);
        }
    }
    void ControlledY(IdxType qubit, IdxType mask)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::ControlledY,gControlledY[d],qubit,0,mask);
            circuit_handle[d]->append(*G);
        }
    }
    void ControlledZ(IdxType qubit, IdxType mask)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::ControlledZ,gControlledZ[d],qubit,0,mask);
            circuit_handle[d]->append(*G);
        }
    }
    void ControlledH(IdxType qubit, IdxType mask)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::ControlledH,gControlledH[d],qubit,0,mask);
            circuit_handle[d]->append(*G);
        }
    }
    void ControlledS(IdxType qubit, IdxType mask)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::ControlledS,gControlledS[d],qubit,0,mask);
            circuit_handle[d]->append(*G);
        }
    }
    void ControlledT(IdxType qubit, IdxType mask)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::ControlledT,gControlledT[d],qubit,0,mask);
            circuit_handle[d]->append(*G);
        }
    }

    void ControlledRI(ValType theta, IdxType qubit, IdxType mask)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::ControlledRI,gControlledRI[d],qubit,theta,mask);
            circuit_handle[d]->append(*G);
        }
    }
    void ControlledRX(ValType theta, IdxType qubit, IdxType mask)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::ControlledRX,gControlledRX[d],qubit,theta,mask);
            circuit_handle[d]->append(*G);
        }
    }
    void ControlledRY(ValType theta, IdxType qubit, IdxType mask)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::ControlledRY,gControlledRY[d],qubit,theta,mask);
            circuit_handle[d]->append(*G);
        }
    }
    void ControlledRZ(ValType theta, IdxType qubit, IdxType mask)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::ControlledRZ,gControlledRZ[d],qubit,theta,mask);
            circuit_handle[d]->append(*G);
        }
    }
    void ControlledEI(ValType theta, IdxType qubit, IdxType mask)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::ControlledEI,gControlledEI[d],qubit,theta,mask);
            circuit_handle[d]->append(*G);
        }
    }
    void ControlledEX(ValType theta, IdxType qubit, IdxType mask)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::ControlledEX,gControlledEX[d],qubit,theta,mask);
            circuit_handle[d]->append(*G);
        }
    }
    void ControlledEY(ValType theta, IdxType qubit, IdxType mask)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::ControlledEY,gControlledEY[d],qubit,theta,mask);
            circuit_handle[d]->append(*G);
        }
    }
    void ControlledEZ(ValType theta, IdxType qubit, IdxType mask)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::ControlledEZ,gControlledEZ[d],qubit,theta,mask);
            circuit_handle[d]->append(*G);
        }
    }

    void AdjointS(IdxType qubit)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::AdjointS,gAdjointS[d],qubit);
            circuit_handle[d]->append(*G);
        }
    }
    void AdjointT(IdxType qubit)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::AdjointT,gAdjointT[d],qubit);
            circuit_handle[d]->append(*G);
        }
    }
    void ControlledAdjointS(IdxType qubit, IdxType mask)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::ControlledAdjointS,gControlledAdjointS[d],qubit,0,mask);
            circuit_handle[d]->append(*G);
        }
    }
    void ControlledAdjointT(IdxType qubit, IdxType mask)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::ControlledAdjointT,gControlledAdjointT[d],qubit,0,mask);
            circuit_handle[d]->append(*G);
        }
    }
    void Swap(IdxType qubit0, IdxType qubit1)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::Swap,gSwap[d],qubit0,0,qubit1);
            circuit_handle[d]->append(*G);
        }
    }
    void Measure(IdxType qubit, ValType rand, IdxType pauli)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            Gate* G = new Gate(OP::Measure,gMeasure[d],qubit,rand,pauli);
            circuit_handle[d]->append(*G);
        }
    }

    // =============================== End of Gate Define ===================================
    void reset()
    {
        //printf("%lu qubits are to be released in reset\n", circuit_handle->n_qubits);
        for (unsigned d=0; d<n_gpus; d++)
        {
            IdxType qubits_to_release = circuit_handle[d]->n_qubits;
            for (IdxType i=0; i<qubits_to_release; i++)
                circuit_handle[d]->ReleaseQubit();
        }
        //Reset CPU input & output
        memset(sv_real_cpu, 0, sv_size);
        memset(sv_imag_cpu, 0, sv_size);
        //State Vector initial state [0..0] = 1
        sv_real_cpu[0] = 1.;

        //Reset GPU number
        n_gpus = n_gpus_org;
        gpu_scale = floor(log((double)n_gpus_org+0.5)/log(2.0));
        
        //GPU side initialization
        for (unsigned d=0; d<n_gpus; d++)
        {
            cudaSafeCall(cudaMemcpy(sv_real[d], &sv_real_cpu[d*m_gpu], 
                        sv_size_per_gpu, cudaMemcpyHostToDevice));
            cudaSafeCall(cudaMemcpy(sv_imag[d], &sv_imag_cpu[d*m_gpu], 
                        sv_size_per_gpu, cudaMemcpyHostToDevice));
            cudaSafeCall(cudaMemset(m_real[d], 0, sv_size_per_gpu));
            reset_circuit(d);
        }
    }
    void reset_circuit(unsigned i_gpu)
    {
        circuit_handle[i_gpu]->clear();
        //printf("Circuit is reset!\n");
    }
    IdxType get_n_qubits()
    {
        //by default we return value at GPU-0
        return circuit_handle[0]->n_qubits;
    }
    IdxType get_n_gates()
    {
        //by default we return value at GPU-0
        return circuit_handle[0]->n_gates;
    }
    void update(const IdxType _n_qubits, const IdxType _n_gates)
    {
        assert(_n_qubits <= (N_QUBIT_SLOT/2));
        //For density matrix, we need double the qubits
        this->n_qubits = _n_qubits;
        this->n_gates = _n_gates;
        this->dim = ((IdxType)1<<(2*n_qubits));
        this->half_dim = (IdxType)1<<(2*n_qubits-1);
        this->sv_size = dim*(IdxType)sizeof(ValType);
        if (n_qubits < gpu_scale) 
        {
            gpu_scale = n_qubits;
            n_gpus = ((IdxType)1<<gpu_scale);
        }
        this->lg2_m_gpu = 2*n_qubits - gpu_scale;
        this->m_gpu = (IdxType)1<<(lg2_m_gpu);
        this->sv_size_per_gpu = sv_size/n_gpus;
        if (((IdxType)1<<(n_qubits)) % n_gpus != 0)
        {
            std::cerr << "Error: Number of GPUs is too large or too small." << std::endl;
            exit(1);
        }
    }
    std::string circuitToString()
    {
        assert(circuit_handle[0] != NULL);
        return circuit_handle[0]->circuitToString();
    }
    ValType sim()
    {
        //printf("before update is n_qubits: %lu, n_gates: %lu\n",n_qubits, n_gates);

        assert(circuit_handle[0] != NULL);
        update(circuit_handle[0]->n_qubits, circuit_handle[0]->n_gates);

        if (!is_power_of_2(n_gpus))
        {
            std::cerr << "Error: Number of GPUs should be an exponential of 2." << std::endl;
            exit(1);
        }
        if (dim % n_gpus != 0)
        {
            std::cerr << "Error: Number of GPUs is too large or too small." << std::endl;
            exit(1);
        }
        //printf("after update is n_qubits: %lu, n_gates: %lu\n",n_qubits, n_gates);

        //printf("\n======Before========\n");
        //print_res_sv();
        //printf("\n==============\n");

        double* sim_times = NULL;
        SAFE_ALOC_HOST(sim_times, sizeof(double)*n_gpus);
        cudaLaunchParams* params = NULL;
        SAFE_ALOC_HOST(params, sizeof(cudaLaunchParams)*n_gpus);

        ValType res_prob = 0;

#pragma omp parallel num_threads (n_gpus) shared(params, res_prob) 
        {
            unsigned d = omp_get_thread_num();
            cudaSafeCall(cudaSetDevice(d));
            circuit_handle_gpu[d] = circuit_handle[d]->upload();
            cudaSafeCall(cudaSetDevice(d));
            cudaSafeCall(cudaMemcpy(sim_gpu[d], this, 
                        sizeof(Simulation), cudaMemcpyHostToDevice));
            gpu_timer sim_timer;
            dim3 gridDim(1,1,1);
            cudaDeviceProp deviceProp;
            cudaSafeCall(cudaGetDeviceProperties(&deviceProp, d));
            int numBlocksPerSm;
            cudaSafeCall(cudaOccupancyMaxActiveBlocksPerMultiprocessor(&numBlocksPerSm, 
                        simulation_kernel, THREADS_PER_BLOCK, 0));
            gridDim.x = numBlocksPerSm * deviceProp.multiProcessorCount;
            void* args[] = {&sim_gpu[d], &d};

            //set cooperativekernelmultidevice
            params[d].func = (void*)simulation_kernel;
            params[d].gridDim = gridDim;
            params[d].blockDim = dim3(THREADS_PER_BLOCK);
            params[d].args = args;
            params[d].sharedMem = 0;
            cudaStreamCreate(&params[d].stream);
            cudaSafeCall(cudaDeviceSynchronize());
            cudaCheckError();
            #pragma omp barrier
            sim_timer.start_timer();

            if (d == 0)
                cudaLaunchCooperativeKernelMultiDevice(params, n_gpus);
            cudaCheckError();

            cudaSafeCall(cudaDeviceSynchronize());
            sim_timer.stop_timer();

            sim_times[d] = sim_timer.measure();
            #pragma omp barrier

            if (d == 0)
            {
                //Copy back
                cudaSafeCall(cudaMemcpy(&res_prob, m_real[d], sizeof(ValType), cudaMemcpyDeviceToHost));
                cudaSafeCall(cudaDeviceSynchronize());
            }
            reset_circuit(d);
        }

        double avg_sim_time = 0;
        for (unsigned d=0; d<n_gpus; d++)
        {
            avg_sim_time += sim_times[d];
        }
        avg_sim_time /= (double)n_gpus;

#ifdef PRINT_MEA_PER_CIRCUIT
        printf("\n============== SVsim ===============\n");
        printf("nqubits:%llu, ngates:%llu, ngpus:%llu, comp:%.3lf ms, comm:%.3lf ms, sim:%.3lf ms, mem:%.3lf MB, mem_per_gpu:%.3lf MB, prob: %.3f\n",
                n_qubits, n_gates, n_gpus, avg_sim_time, 0., 
                avg_sim_time, gpu_mem/1024/1024, gpu_mem/1024/1024, res_prob);
        printf("=====================================\n");
#endif

        SAFE_FREE_HOST(params);
        SAFE_FREE_HOST(sim_times);

        //cudaSafeCall(cudaMemcpy(sv_real_cpu, sv_real, sv_size, cudaMemcpyDeviceToHost));
        //cudaSafeCall(cudaMemcpy(sv_imag_cpu, sv_imag, sv_size, cudaMemcpyDeviceToHost));
        //print_res_sv();

        //printf("after kernel is n_qubits: %lu, n_gates: %lu\n",n_qubits, n_gates);
        return res_prob;
    }

    IdxType* measurement(unsigned repetition=10)
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            cudaSafeCall(cudaSetDevice(d));
            cudaSafeCall(cudaMemcpy(&sv_real_cpu[d*m_gpu], sv_real[d], 
                        sv_size_per_gpu, cudaMemcpyDeviceToHost));
            cudaSafeCall(cudaMemcpy(&sv_imag_cpu[d*m_gpu], sv_imag[d], 
                        sv_size_per_gpu, cudaMemcpyDeviceToHost));
        }
        //accumulate for sampling
        ValType* sv_scan = NULL;
        IdxType sv_num = ((IdxType)1<<n_qubits);
        SAFE_ALOC_HOST(sv_scan, (sv_num+1)*sizeof(ValType));
        sv_scan[0] = 0;
        for (IdxType i=1; i<sv_num+1; i++)
            sv_scan[i] = sv_scan[i-1]+(sv_real_cpu[i-1]*sv_real_cpu[i-1]);
        srand(RAND_SEED);
        IdxType* res_state = new IdxType[repetition];
        memset(res_state, 0, (repetition*sizeof(IdxType)));
        for (unsigned i=0; i<repetition; i++)
        {
            ValType r = (ValType)rand()/(ValType)RAND_MAX;
            for (IdxType j=0; j<sv_num; j++)
                if (sv_scan[j]<=r && r<sv_scan[j+1])
                    res_state[i] = j;
        }
        if ( abs(sv_scan[sv_num] - 1.0) > ERROR_BAR )
            printf("Sum of probability is far from 1.0 with %lf\n", sv_scan[sv_num]);
        SAFE_FREE_HOST(sv_scan);
        return res_state;
    }

    void print_res_sv()
    {
        for (unsigned d=0; d<n_gpus; d++)
        {
            cudaSafeCall(cudaSetDevice(d));
            cudaSafeCall(cudaMemcpy(&sv_real_cpu[d*m_gpu], sv_real[d], 
                        sv_size_per_gpu, cudaMemcpyDeviceToHost));
            cudaSafeCall(cudaMemcpy(&sv_imag_cpu[d*m_gpu], sv_imag[d], 
                        sv_size_per_gpu, cudaMemcpyDeviceToHost));
        }
        printf("----- Real SV ------\n");
        for (IdxType i=0; i<dim; i++) 
            printf("%lf ", sv_real_cpu[i]);
        printf("\n");
        printf("----- Imag SV ------\n");
        for (IdxType i=0; i<dim; i++) 
            printf("%lf ", sv_imag_cpu[i]);
        printf("\n");
    }
public:
    func_t *gX, *gY, *gZ, *gH, *gS, *gT;
    func_t *gRI, *gRX, *gRY, *gRZ, *gEI, *gEX, *gEY, *gEZ;
    func_t *gControlledX, *gControlledY, *gControlledZ;
    func_t *gControlledH, *gControlledS, *gControlledT;
    func_t *gControlledRI, *gControlledRX, *gControlledRY, *gControlledRZ;
    func_t *gControlledEI, *gControlledEX, *gControlledEY, *gControlledEZ;
    func_t *gAdjointS, *gAdjointT, *gControlledAdjointS, *gControlledAdjointT;
    func_t *gSwap, *gMeasure;

public:
    // n_qubits is the number of qubits
    IdxType n_qubits;
    // gpu_scale is 2^x of the number of GPUs, e.g., with 8 GPUs the gpu_scale is 3 (2^3=8)
    IdxType gpu_scale;
    IdxType n_gpus_org; //originally how many gpus
    IdxType n_gpus;
    IdxType lg2_m_gpu;
    IdxType m_gpu;
    IdxType dim;
    IdxType half_dim;
    IdxType sv_size;
    IdxType sv_size_per_gpu;
    IdxType n_gates;
    //CPU arrays
    ValType* sv_real_cpu;
    ValType* sv_imag_cpu;
    //GPU arrays
    ValType** sv_real;
    ValType** sv_imag;
    //For joint measurement
    ValType** m_real;
    //GPU memory usage
    ValType gpu_mem;
    //cricuit
    Circuit** circuit_handle;
    //circuit gpu
    Gate** circuit_handle_gpu;
    //hold the GPU-side simulator instances
    Simulation** sim_gpu;

};

__global__ void simulation_kernel(Simulation* sim, unsigned i_gpu)
{
    grid_group grid = this_grid(); 
    for (IdxType t=0; t<(sim->n_gates); t++)
    {
        ((sim->circuit_handle_gpu)[i_gpu][t]).exe_op(sim, sim->sv_real, sim->sv_imag);
    }
}


//================================= Gate Definition ========================================
//Define MG-BSP machine operation header (Optimized version)
#define OP_HEAD multi_grid_group grid = this_multi_grid(); \
        for (IdxType i=grid.thread_rank(); i<(sim->half_dim);\
                i+=grid.size()){ \
            IdxType outer = (i >> qubit); \
            IdxType inner =  (i & (((IdxType)1<<qubit)-1)); \
            IdxType offset = (outer << (qubit+1)); \
            IdxType pos0_gid = ((offset + inner)&(sim->n_gpus-1));\
            IdxType pos0 = ((offset + inner)>>(sim->gpu_scale)); \
            IdxType pos1_gid = ((offset + inner + ((IdxType)1<<qubit))&(sim->n_gpus-1)); \
            IdxType pos1 = ((offset + inner + ((IdxType)1<<qubit))>>(sim->gpu_scale));  

//Define MG-BSP machine operation header with a mask for multi-controlled gates
#define OP_HEAD_MASK multi_grid_group grid = this_multi_grid(); \
        for (IdxType i=grid.thread_rank(); i<(sim->half_dim);\
                i+=grid.size()){ \
            IdxType outer = (i >> qubit); \
            IdxType inner =  (i & (((IdxType)1<<qubit)-1)); \
            IdxType offset = (outer << (qubit+1)); \
            IdxType pos0_src = offset + inner; \
            if (((~(pos0_src&mask))&mask) != 0) continue; \
            IdxType pos0_gid = ((offset + inner)&(sim->n_gpus-1));\
            IdxType pos0 = ((offset + inner)>>(sim->gpu_scale)); \
            IdxType pos1_gid = ((offset + inner + ((IdxType)1<<qubit))&(sim->n_gpus-1)); \
            IdxType pos1 = ((offset + inner + ((IdxType)1<<qubit))>>(sim->gpu_scale));  


//Define MG-BSP machine operation footer
#define OP_TAIL  } grid.sync(); 

//============== X Gate ================
//Pauli gate: bit flip
/** X = [0 1]
        [1 0]
*/
__device__ __inline__ void X_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const IdxType qubit)
{
    OP_HEAD;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = el1_real; 
    sv_imag[pos0_gid][pos0] = el1_imag;
    sv_real[pos1_gid][pos1] = el0_real; 
    sv_imag[pos1_gid][pos1] = el0_imag;
    OP_TAIL;
}

//============== Y Gate ================
//Pauli gate: bit and phase flip
/** Y = [0 -i]
        [i  0]
*/
__device__ __inline__ void Y_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const IdxType qubit)
{
    OP_HEAD;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = el1_imag; 
    sv_imag[pos0_gid][pos0] = -el1_real;
    sv_real[pos1_gid][pos1] = -el0_imag;
    sv_imag[pos1_gid][pos1] = el0_real;
    OP_TAIL;
}


//============== ConjugateY Gate ================
/** ConjugateY = [0 i]
                 [-i  0]
*/
__device__ __inline__ void ConjugateY_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const IdxType qubit)
{
    OP_HEAD;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = -el1_imag; 
    sv_imag[pos0_gid][pos0] = el1_real;
    sv_real[pos1_gid][pos1] = el0_imag;
    sv_imag[pos1_gid][pos1] = -el0_real;
    OP_TAIL;
}


//============== Z Gate ================
//Pauli gate: phase flip
/** Z = [1  0]
        [0 -1]
*/
__device__ __inline__ void Z_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const IdxType qubit)
{
    OP_HEAD;
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos1_gid][pos1] = -el1_real;
    sv_imag[pos1_gid][pos1] = -el1_imag;
    OP_TAIL;
}

//============== H Gate ================
//Clifford gate: Hadamard
/** H = 1/sqrt(2) * [1  1]
                    [1 -1]
*/
__device__ __inline__ void H_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const IdxType qubit)
{
    OP_HEAD;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = S2I*(el0_real + el1_real); 
    sv_imag[pos0_gid][pos0] = S2I*(el0_imag + el1_imag);
    sv_real[pos1_gid][pos1] = S2I*(el0_real - el1_real);
    sv_imag[pos1_gid][pos1] = S2I*(el0_imag - el1_imag);
    OP_TAIL;
}

//============== S Gate ================
//Clifford gate: sqrt(Z) phase gate
/** S = [1 0]
        [0 i]
*/
__device__ __inline__ void S_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const IdxType qubit)
{
    OP_HEAD;
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos1_gid][pos1] = -el1_imag;
    sv_imag[pos1_gid][pos1] = el1_real;
    OP_TAIL;
}

//============== T Gate ================
//C3 gate: sqrt(S) phase gate
/** T = [1 0]
        [0 s2i+s2i*i]
*/
__device__ __inline__ void T_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const IdxType qubit)
{
    OP_HEAD;
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos1_gid][pos1] = S2I*(el1_real-el1_imag);
    sv_imag[pos1_gid][pos1] = S2I*(el1_real+el1_imag);
    OP_TAIL;
}

//============== RI Gate ================
//Rotate around the Pauli-I, it applies a global phase of theta/2.
//and maps 1 to e^{-i theta/2}|1>
/** RI = [cos(theta/2)-i*sin(theta/2) 0]
        [0 cos(theta/2)-i*sin(theta/2)]
*/
__device__ __inline__ void RI_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit)
{
    ValType ri_real = cos(theta/2.0);
    ValType ri_imag = -sin(theta/2.0);
    OP_HEAD;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (el0_real * ri_real) - (el0_imag * ri_imag);
    sv_imag[pos0_gid][pos0] = (el0_real * ri_imag) + (el0_imag * ri_real);
    sv_real[pos1_gid][pos1] = (el1_real * ri_real) - (el1_imag * ri_imag);
    sv_imag[pos1_gid][pos1] = (el1_real * ri_imag) + (el1_imag * ri_real);
    OP_TAIL;
}

//============== ConjugateRI Gate ================
/** ConjugateRI = [cos(theta/2)+i*sin(theta/2) 0]
                  [0 cos(theta/2)+i*sin(theta/2)]
*/
__device__ __inline__ void ConjugateRI_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit)
{
    ValType ri_real = cos(theta/2.0);
    ValType ri_imag = sin(theta/2.0);
    OP_HEAD;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (el0_real * ri_real) - (el0_imag * ri_imag);
    sv_imag[pos0_gid][pos0] = (el0_real * ri_imag) + (el0_imag * ri_real);
    sv_real[pos1_gid][pos1] = (el1_real * ri_real) - (el1_imag * ri_imag);
    sv_imag[pos1_gid][pos1] = (el1_real * ri_imag) + (el1_imag * ri_real);
    OP_TAIL;
}




//============== RX Gate ================
//Rotation around X-axis
/** RX = [cos(theta/2), -i*sin(theta/2)]
        [-i*sin(theta/2), cos(theta/2)]
*/
__device__ __inline__ void RX_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit)
{
    ValType rx_real = cos(theta/2.0);
    ValType rx_imag = -sin(theta/2.0);
    OP_HEAD;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (rx_real * el0_real) - (rx_imag * el1_imag);
    sv_imag[pos0_gid][pos0] = (rx_real * el0_imag) + (rx_imag * el1_real);
    sv_real[pos1_gid][pos1] =  - (rx_imag * el0_imag) +(rx_real * el1_real);
    sv_imag[pos1_gid][pos1] =  + (rx_imag * el0_real) +(rx_real * el1_imag);
    OP_TAIL;
}


//============== ConjugateRX Gate ================
/** ConjugateRX = [cos(theta/2), i*sin(theta/2)]
                  [i*sin(theta/2), cos(theta/2)]
*/
__device__ __inline__ void ConjugateRX_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit)
{
    ValType rx_real = cos(theta/2.0);
    ValType rx_imag = sin(theta/2.0);
    OP_HEAD;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (rx_real * el0_real) - (rx_imag * el1_imag);
    sv_imag[pos0_gid][pos0] = (rx_real * el0_imag) + (rx_imag * el1_real);
    sv_real[pos1_gid][pos1] =  - (rx_imag * el0_imag) +(rx_real * el1_real);
    sv_imag[pos1_gid][pos1] =  + (rx_imag * el0_real) +(rx_real * el1_imag);
    OP_TAIL;
}



//============== RY Gate ================
//Rotation around Y-axis
/** RX = [cos(theta/2), -sin(theta/2)]
        [sin(theta/2), cos(theta/2)]
*/
__device__ __inline__ void RY_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit)
{
    ValType e0_real = cos(theta/2.0);
    ValType e1_real = -sin(theta/2.0);
    ValType e2_real = sin(theta/2.0);
    ValType e3_real = cos(theta/2.0);
    OP_HEAD;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (e0_real * el0_real) +(e1_real * el1_real);
    sv_imag[pos0_gid][pos0] = (e0_real * el0_imag) +(e1_real * el1_imag);
    sv_real[pos1_gid][pos1] = (e2_real * el0_real) +(e3_real * el1_real);
    sv_imag[pos1_gid][pos1] = (e2_real * el0_imag) +(e3_real * el1_imag);
    OP_TAIL;
}

//============== RZ Gate ================
//Rotation around Z-axis
/** RZ = [cos(theta/2)-i*sin(theta/2) 0]
        [0 cos(theta/2)+i*sin(theta/2)]
**/

__device__ __inline__ void RZ_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit)
{
    ValType e0_real = cos(theta/2);
    ValType e0_imag = -sin(theta/2);
    ValType e3_real = cos(theta/2);
    ValType e3_imag = sin(theta/2);
    OP_HEAD;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (el0_real * e0_real) - (el0_imag * e0_imag);
    sv_imag[pos0_gid][pos0] = (el0_real * e0_imag) + (el0_imag * e0_real);
    sv_real[pos1_gid][pos1] = (el1_real * e3_real) - (el1_imag * e3_imag);
    sv_imag[pos1_gid][pos1] = (el1_real * e3_imag) + (el1_imag * e3_real);
    OP_TAIL;
}

//============== ConjugateRZ Gate ================
/** ConjugateRZ = [cos(theta/2)+i*sin(theta/2) 0]
                  [0 cos(theta/2)-i*sin(theta/2)]
**/

__device__ __inline__ void ConjugateRZ_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit)
{
    ValType e0_real = cos(theta/2);
    ValType e0_imag = sin(theta/2);
    ValType e3_real = cos(theta/2);
    ValType e3_imag = -sin(theta/2);
    OP_HEAD;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (el0_real * e0_real) - (el0_imag * e0_imag);
    sv_imag[pos0_gid][pos0] = (el0_real * e0_imag) + (el0_imag * e0_real);
    sv_real[pos1_gid][pos1] = (el1_real * e3_real) - (el1_imag * e3_imag);
    sv_imag[pos1_gid][pos1] = (el1_real * e3_imag) + (el1_imag * e3_real);
    OP_TAIL;
}



//============== EI Gate ================
//Exponential single qubit gate at Paulti-I, 
// [1,0] cos(theta) + i [1,0] sin(theta)
// [0,1]                [0,1]
// Exp-I = [cos(t)+i*sin(t),  0]
//       = [0, cos(t)+i*sin(t)  ]
__device__ __inline__ void EI_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit)
{
    const ValType e0_real = cos(theta);
    const ValType e0_imag = sin(theta);
    const ValType e3_real = cos(theta);
    const ValType e3_imag = sin(theta);
    OP_HEAD;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (e0_real * el0_real) - (e0_imag * el0_imag);
    sv_imag[pos0_gid][pos0] = (e0_real * el0_imag) + (e0_imag * el0_real);
    sv_real[pos1_gid][pos1] = (e3_real * el1_real) - (e3_imag * el1_imag);
    sv_imag[pos1_gid][pos1] = (e3_real * el1_imag) + (e3_imag * el1_real);
    OP_TAIL;
} 

//============== ConjugateEI Gate ================
// [1,0] cos(theta) - i [1,0] sin(theta)
// [0,1]                [0,1]
// Exp-I = [cos(t)-i*sin(t),  0]
//       = [0, cos(t)-i*sin(t)  ]
__device__ __inline__ void ConjugateEI_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit)
{
    const ValType e0_real = cos(theta);
    const ValType e0_imag = -sin(theta);
    const ValType e3_real = cos(theta);
    const ValType e3_imag = -sin(theta);
    OP_HEAD;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (e0_real * el0_real) - (e0_imag * el0_imag);
    sv_imag[pos0_gid][pos0] = (e0_real * el0_imag) + (e0_imag * el0_real);
    sv_real[pos1_gid][pos1] = (e3_real * el1_real) - (e3_imag * el1_imag);
    sv_imag[pos1_gid][pos1] = (e3_real * el1_imag) + (e3_imag * el1_real);
    OP_TAIL;
} 


//============== EX Gate ================
//Exponential single qubit gate at Paulti-X
// [1,0] cos(theta) + i [0,1] sin(theta)
// [0,1]                [1,0]
// Exp-X = [cos(t),  i*sin(t)]
//       = [i*sin(t), cos(t) ]
__device__ __inline__ void EX_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit)
{
    const ValType e0_real = cos(theta);
    const ValType e1_imag = sin(theta);
    const ValType e2_imag = sin(theta);
    const ValType e3_real = cos(theta);
    OP_HEAD;
    const ValType el0_real = sv_real[pos0_gid][pos0];
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1];
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] =  (e0_real * el0_real) - (e1_imag * el1_imag);
    sv_imag[pos0_gid][pos0] =  (e0_real * el0_imag) + (e1_imag * el1_real);
    sv_real[pos1_gid][pos1] = -(e2_imag * el0_imag) + (e3_real * el1_real);
    sv_imag[pos1_gid][pos1] =  (e2_imag * el0_real) + (e3_real * el1_imag);
    OP_TAIL;
}

//============== ConjugateEX Gate ================
// [1,0] cos(theta) - i [0,1] sin(theta)
// [0,1]                [1,0]
// Exp-X = [cos(t),  -i*sin(t)]
//       = [-i*sin(t), cos(t) ]
__device__ __inline__ void ConjugateEX_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit)
{
    const ValType e0_real = cos(theta);
    const ValType e1_imag = -sin(theta);
    const ValType e2_imag = -sin(theta);
    const ValType e3_real = cos(theta);
    OP_HEAD;
    const ValType el0_real = sv_real[pos0_gid][pos0];
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1];
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] =  (e0_real * el0_real) - (e1_imag * el1_imag);
    sv_imag[pos0_gid][pos0] =  (e0_real * el0_imag) + (e1_imag * el1_real);
    sv_real[pos1_gid][pos1] = -(e2_imag * el0_imag) + (e3_real * el1_real);
    sv_imag[pos1_gid][pos1] =  (e2_imag * el0_real) + (e3_real * el1_imag);
    OP_TAIL;
}



//============== EY Gate ================
//Exponential single qubit gate at Paulti-Y
// [1,0] cos(theta) + i [0,-i] sin(theta)
// [0,1]                [i,0]
// Exp-Y = [cos(t), sin(t)]
//       = [-sin(t), cos(t) ]
__device__ __inline__ void EY_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit)
{
    const ValType e0_real = cos(theta);
    const ValType e1_real = sin(theta);
    const ValType e2_real = -sin(theta);
    const ValType e3_real = cos(theta);
    OP_HEAD;
    const ValType el0_real = sv_real[pos0_gid][pos0];
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1];
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (e0_real * el0_real) +(e1_real * el1_real);
    sv_imag[pos0_gid][pos0] = (e0_real * el0_imag) +(e1_real * el1_imag);
    sv_real[pos1_gid][pos1] = (e2_real * el0_real) +(e3_real * el1_real);
    sv_imag[pos1_gid][pos1] = (e2_real * el0_imag) +(e3_real * el1_imag);
    OP_TAIL;
}

//============== EZ Gate ================
//Exponential single qubit gate at Paulti-Z
// [1,0] cos(theta) + i [1,0] sin(theta)
// [0,1]                [0,-1]
// Exp-Z = [cos(t)+i*sin(t), 0]
//       = [0, cos(t)-i*sin(t)]
__device__ __inline__ void EZ_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit)
{
    const ValType e0_real = cos(theta);
    const ValType e0_imag = sin(theta);
    const ValType e3_real = cos(theta);
    const ValType e3_imag = -sin(theta);
    OP_HEAD;
    const ValType el0_real = sv_real[pos0_gid][pos0];
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1];
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (e0_real * el0_real) - (e0_imag * el0_imag);
    sv_imag[pos0_gid][pos0] = (e0_real * el0_imag) + (e0_imag * el0_real);
    sv_real[pos1_gid][pos1] = (e3_real * el1_real) - (e3_imag * el1_imag);
    sv_imag[pos1_gid][pos1] = (e3_real * el1_imag) + (e3_imag * el1_real);
    OP_TAIL;
}

//============== ConjugateEZ Gate ================
// [1,0] cos(theta) - i [1,0] sin(theta)
// [0,1]                [0,-1]
// Exp-Z = [cos(t)-i*sin(t), 0]
//       = [0, cos(t)+i*sin(t)]
__device__ __inline__ void ConjugateEZ_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit)
{
    const ValType e0_real = cos(theta);
    const ValType e0_imag = -sin(theta);
    const ValType e3_real = cos(theta);
    const ValType e3_imag = sin(theta);
    OP_HEAD;
    const ValType el0_real = sv_real[pos0_gid][pos0];
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1];
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (e0_real * el0_real) - (e0_imag * el0_imag);
    sv_imag[pos0_gid][pos0] = (e0_real * el0_imag) + (e0_imag * el0_real);
    sv_real[pos1_gid][pos1] = (e3_real * el1_real) - (e3_imag * el1_imag);
    sv_imag[pos1_gid][pos1] = (e3_real * el1_imag) + (e3_imag * el1_real);
    OP_TAIL;
}


//============== Controlled X Gate ================
//Pauli gate: bit flip
/** X = [0 1]
        [1 0]
*/
__device__ __inline__ void ControlledX_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const IdxType qubit, const IdxType mask)
{
    OP_HEAD_MASK;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = el1_real; 
    sv_imag[pos0_gid][pos0] = el1_imag;
    sv_real[pos1_gid][pos1] = el0_real; 
    sv_imag[pos1_gid][pos1] = el0_imag;
    OP_TAIL;
}

//============== Controlled Y Gate ================
//Pauli gate: bit and phase flip
/** Y = [0 -i]
        [i  0]
*/
__device__ __inline__ void ControlledY_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const IdxType qubit, const IdxType mask)
{
    OP_HEAD_MASK;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = el1_imag; 
    sv_imag[pos0_gid][pos0] = -el1_real;
    sv_real[pos1_gid][pos1] = -el0_imag;
    sv_imag[pos1_gid][pos1] = el0_real;
    OP_TAIL;
}


//============== ControlledConjugateY Gate ================
/** ConjugateY = [0 i]
                 [-i  0]
*/
__device__ __inline__ void ControlledConjugateY_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const IdxType qubit, const IdxType mask)
{
    OP_HEAD_MASK;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = -el1_imag; 
    sv_imag[pos0_gid][pos0] = el1_real;
    sv_real[pos1_gid][pos1] = el0_imag;
    sv_imag[pos1_gid][pos1] = -el0_real;
    OP_TAIL;

}


//============== Controlled Z Gate ================
//Pauli gate: phase flip
/** Z = [1  0]
        [0 -1]
*/
__device__ __inline__ void ControlledZ_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const IdxType qubit, const IdxType mask)
{
    OP_HEAD_MASK;
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos1_gid][pos1] = -el1_real;
    sv_imag[pos1_gid][pos1] = -el1_imag;
    OP_TAIL;
}

//==============Controlled H Gate ================
//Clifford gate: Hadamard
/** H = 1/sqrt(2) * [1  1]
                    [1 -1]
*/
__device__ __inline__ void ControlledH_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const IdxType qubit, const IdxType mask)
{
    OP_HEAD_MASK;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = S2I*(el0_real + el1_real); 
    sv_imag[pos0_gid][pos0] = S2I*(el0_imag + el1_imag);
    sv_real[pos1_gid][pos1] = S2I*(el0_real - el1_real);
    sv_imag[pos1_gid][pos1] = S2I*(el0_imag - el1_imag);
    OP_TAIL;
}

//============== Controlled S Gate ================
//Clifford gate: sqrt(Z) phase gate
/** S = [1 0]
        [0 i]
*/
__device__ __inline__ void ControlledS_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const IdxType qubit, const IdxType mask)
{
    OP_HEAD_MASK;
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos1_gid][pos1] = -el1_imag;
    sv_imag[pos1_gid][pos1] = el1_real;
    OP_TAIL;
}

//============== Controlled T Gate ================
//C3 gate: sqrt(S) phase gate
/** T = [1 0]
        [0 s2i+s2i*i]
*/
__device__ __inline__ void ControlledT_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const IdxType qubit, const IdxType mask)
{
    OP_HEAD_MASK;
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos1_gid][pos1] = S2I*(el1_real-el1_imag);
    sv_imag[pos1_gid][pos1] = S2I*(el1_real+el1_imag);
    OP_TAIL;
}

//============== Controlled RI Gate ================
//Rotate around the Pauli-I, it applies a global phase of theta/2.
//and maps 1 to e^{-i theta/2}|1>
/** RI = [cos(theta/2)-i*sin(theta/2) 0]
        [0 cos(theta/2)-i*sin(theta/2)]
*/
__device__ __inline__ void ControlledRI_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit, const IdxType mask)
{
    ValType ri_real = cos(theta/2.0);
    ValType ri_imag = -sin(theta/2.0);
    OP_HEAD_MASK;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (el0_real * ri_real) - (el0_imag * ri_imag);
    sv_imag[pos0_gid][pos0] = (el0_real * ri_imag) + (el0_imag * ri_real);
    sv_real[pos1_gid][pos1] = (el1_real * ri_real) - (el1_imag * ri_imag);
    sv_imag[pos1_gid][pos1] = (el1_real * ri_imag) + (el1_imag * ri_real);
    OP_TAIL;
}


//============== ControlledConjugateRI Gate ================
/** ControlledConjugateRI = [cos(theta/2)+i*sin(theta/2) 0]
                            [0 cos(theta/2)+i*sin(theta/2)]
*/
__device__ __inline__ void ControlledConjugateRI_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit, const IdxType mask)
{
    ValType ri_real = cos(theta/2.0);
    ValType ri_imag = sin(theta/2.0);
    OP_HEAD_MASK;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (el0_real * ri_real) - (el0_imag * ri_imag);
    sv_imag[pos0_gid][pos0] = (el0_real * ri_imag) + (el0_imag * ri_real);
    sv_real[pos1_gid][pos1] = (el1_real * ri_real) - (el1_imag * ri_imag);
    sv_imag[pos1_gid][pos1] = (el1_real * ri_imag) + (el1_imag * ri_real);
    OP_TAIL;
}


//============== Controlled RX Gate ================
//Rotation around X-axis
__device__ __inline__ void ControlledRX_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit, const IdxType mask)
{
    ValType rx_real = cos(theta/2.0);
    ValType rx_imag = -sin(theta/2.0);
    OP_HEAD_MASK;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (rx_real * el0_real) - (rx_imag * el1_imag);
    sv_imag[pos0_gid][pos0] = (rx_real * el0_imag) + (rx_imag * el1_real);
    sv_real[pos1_gid][pos1] =  - (rx_imag * el0_imag) +(rx_real * el1_real);
    sv_imag[pos1_gid][pos1] =  + (rx_imag * el0_real) +(rx_real * el1_imag);
    OP_TAIL;
}

//============== ControlledConjugateRX Gate ================
//Rotation around X-axis
__device__ __inline__ void ControlledConjugateRX_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit, const IdxType mask)
{
    ValType rx_real = cos(theta/2.0);
    ValType rx_imag = sin(theta/2.0);
    OP_HEAD_MASK;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (rx_real * el0_real) - (rx_imag * el1_imag);
    sv_imag[pos0_gid][pos0] = (rx_real * el0_imag) + (rx_imag * el1_real);
    sv_real[pos1_gid][pos1] =  - (rx_imag * el0_imag) +(rx_real * el1_real);
    sv_imag[pos1_gid][pos1] =  + (rx_imag * el0_real) +(rx_real * el1_imag);
    OP_TAIL;
}



//============== Controlled RY Gate ================
//Rotation around Y-axis
__device__ __inline__ void ControlledRY_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit, const IdxType mask)
{
    ValType e0_real = cos(theta/2.0);
    ValType e1_real = -sin(theta/2.0);
    ValType e2_real = sin(theta/2.0);
    ValType e3_real = cos(theta/2.0);
    OP_HEAD_MASK;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (e0_real * el0_real) +(e1_real * el1_real);
    sv_imag[pos0_gid][pos0] = (e0_real * el0_imag) +(e1_real * el1_imag);
    sv_real[pos1_gid][pos1] = (e2_real * el0_real) +(e3_real * el1_real);
    sv_imag[pos1_gid][pos1] = (e2_real * el0_imag) +(e3_real * el1_imag);
    OP_TAIL;
}

//==============Controlled RZ Gate ================
//Rotation around Z-axis
__device__ __inline__ void ControlledRZ_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit, const IdxType mask)
{
    ValType e0_real = cos(theta/2.0);
    ValType e0_imag = -sin(theta/2.0);
    ValType e3_real = cos(theta/2.0);
    ValType e3_imag = sin(theta/2.0);
    OP_HEAD_MASK;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (el0_real * e0_real) - (el0_imag * e0_imag);
    sv_imag[pos0_gid][pos0] = (el0_real * e0_imag) + (el0_imag * e0_real);
    sv_real[pos1_gid][pos1] = (el1_real * e3_real) - (el1_imag * e3_imag);
    sv_imag[pos1_gid][pos1] = (el1_real * e3_imag) + (el1_imag * e3_real);
    OP_TAIL;
}

//==============ControlledConjugate RZ Gate ================
//Rotation around Z-axis
__device__ __inline__ void ControlledConjugateRZ_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit, const IdxType mask)
{
    ValType e0_real = cos(theta/2.0);
    ValType e0_imag = sin(theta/2.0);
    ValType e3_real = cos(theta/2.0);
    ValType e3_imag = -sin(theta/2.0);
    OP_HEAD_MASK;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (el0_real * e0_real) - (el0_imag * e0_imag);
    sv_imag[pos0_gid][pos0] = (el0_real * e0_imag) + (el0_imag * e0_real);
    sv_real[pos1_gid][pos1] = (el1_real * e3_real) - (el1_imag * e3_imag);
    sv_imag[pos1_gid][pos1] = (el1_real * e3_imag) + (el1_imag * e3_real);
    OP_TAIL;
}


//============== Controlled EI Gate ================
//Exponential single qubit gate at Paulti-I
// Exp-I = [cos(t)+i*sin(t),  0]
//       = [0, cos(t)+i*sin(t)  ]
__device__ __inline__ void ControlledEI_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit, const IdxType mask)
{
    const ValType e0_real = cos(theta);
    const ValType e0_imag = sin(theta);
    const ValType e3_real = cos(theta);
    const ValType e3_imag = sin(theta);
    OP_HEAD_MASK;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (e0_real * el0_real) - (e0_imag * el0_imag);
    sv_imag[pos0_gid][pos0] = (e0_real * el0_imag) + (e0_imag * el0_real);
    sv_real[pos1_gid][pos1] = (e3_real * el1_real) - (e3_imag * el1_imag);
    sv_imag[pos1_gid][pos1] = (e3_real * el1_imag) + (e3_imag * el1_real);
    OP_TAIL;
} 

//============== ControlledConjugate EI Gate ================
// Exp-I = [cos(t)-i*sin(t),  0]
//       = [0, cos(t)-i*sin(t)  ]
__device__ __inline__ void ControlledConjugateEI_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit, const IdxType mask)
{
    const ValType e0_real = cos(theta);
    const ValType e0_imag = -sin(theta);
    const ValType e3_real = cos(theta);
    const ValType e3_imag = -sin(theta);
    OP_HEAD_MASK;
    const ValType el0_real = sv_real[pos0_gid][pos0]; 
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (e0_real * el0_real) - (e0_imag * el0_imag);
    sv_imag[pos0_gid][pos0] = (e0_real * el0_imag) + (e0_imag * el0_real);
    sv_real[pos1_gid][pos1] = (e3_real * el1_real) - (e3_imag * el1_imag);
    sv_imag[pos1_gid][pos1] = (e3_real * el1_imag) + (e3_imag * el1_real);
    OP_TAIL;
} 


//============== Controlled EX Gate ================
//Exponential single qubit gate at Paulti-X
// Exp-X = [cos(t),  i*sin(t)]
//       = [i*sin(t), cos(t) ]
__device__ __inline__ void ControlledEX_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit, const IdxType mask)
{
    const ValType e0_real = cos(theta);
    const ValType e1_imag = sin(theta);
    const ValType e2_imag = sin(theta);
    const ValType e3_real = cos(theta);
    OP_HEAD_MASK;
    const ValType el0_real = sv_real[pos0_gid][pos0];
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1];
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] =  (e0_real * el0_real) - (e1_imag * el1_imag);
    sv_imag[pos0_gid][pos0] =  (e0_real * el0_imag) + (e1_imag * el1_real);
    sv_real[pos1_gid][pos1] = -(e2_imag * el0_imag) + (e3_real * el1_real);
    sv_imag[pos1_gid][pos1] =  (e2_imag * el0_real) + (e3_real * el1_imag);
    OP_TAIL;
}

//============== ControlledConjugate EX Gate ================
// Exp-X = [cos(t),  -i*sin(t)]
//       = [-i*sin(t), cos(t) ]
__device__ __inline__ void ControlledConjugateEX_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit, const IdxType mask)
{
    const ValType e0_real = cos(theta);
    const ValType e1_imag = -sin(theta);
    const ValType e2_imag = -sin(theta);
    const ValType e3_real = cos(theta);
    OP_HEAD_MASK;
    const ValType el0_real = sv_real[pos0_gid][pos0];
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1];
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] =  (e0_real * el0_real) - (e1_imag * el1_imag);
    sv_imag[pos0_gid][pos0] =  (e0_real * el0_imag) + (e1_imag * el1_real);
    sv_real[pos1_gid][pos1] = -(e2_imag * el0_imag) + (e3_real * el1_real);
    sv_imag[pos1_gid][pos1] =  (e2_imag * el0_real) + (e3_real * el1_imag);
    OP_TAIL;
}


//============== Controlled EY Gate ================
//Exponential single qubit gate at Paulti-Y
// Exp-Y = [cos(t), sin(t)]
//       = [-sin(t), cos(t) ]
__device__ __inline__ void ControlledEY_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit, const IdxType mask)
{
    const ValType e0_real = cos(theta);
    const ValType e1_real = sin(theta);
    const ValType e2_real = -sin(theta);
    const ValType e3_real = cos(theta);
    OP_HEAD_MASK;
    const ValType el0_real = sv_real[pos0_gid][pos0];
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1];
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (e0_real * el0_real) +(e1_real * el1_real);
    sv_imag[pos0_gid][pos0] = (e0_real * el0_imag) +(e1_real * el1_imag);
    sv_real[pos1_gid][pos1] = (e2_real * el0_real) +(e3_real * el1_real);
    sv_imag[pos1_gid][pos1] = (e2_real * el0_imag) +(e3_real * el1_imag);
    OP_TAIL;
}

//============== Controlled EZ Gate ================
//Exponential single qubit gate at Paulti-Z
// Exp-Z = [cos(t)+i*sin(t), 0]
//       = [0, cos(t)-i*sin(t)]
__device__ __inline__ void ControlledEZ_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit, const IdxType mask)
{
    const ValType e0_real = cos(theta);
    const ValType e0_imag = sin(theta);
    const ValType e3_real = cos(theta);
    const ValType e3_imag = -sin(theta);
    OP_HEAD_MASK;
    const ValType el0_real = sv_real[pos0_gid][pos0];
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1];
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (e0_real * el0_real) - (e0_imag * el0_imag);
    sv_imag[pos0_gid][pos0] = (e0_real * el0_imag) + (e0_imag * el0_real);
    sv_real[pos1_gid][pos1] = (e3_real * el1_real) - (e3_imag * el1_imag);
    sv_imag[pos1_gid][pos1] = (e3_real * el1_imag) + (e3_imag * el1_real);
    OP_TAIL;
}

//============== ControlledConjugate EZ Gate ================
// Exp-Z = [cos(t)-i*sin(t), 0]
//       = [0, cos(t)+i*sin(t)]
__device__ __inline__ void ControlledConjugateEZ_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const ValType theta, const IdxType qubit, const IdxType mask)
{
    const ValType e0_real = cos(theta);
    const ValType e0_imag = -sin(theta);
    const ValType e3_real = cos(theta);
    const ValType e3_imag = sin(theta);
    OP_HEAD_MASK;
    const ValType el0_real = sv_real[pos0_gid][pos0];
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1];
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos0_gid][pos0] = (e0_real * el0_real) - (e0_imag * el0_imag);
    sv_imag[pos0_gid][pos0] = (e0_real * el0_imag) + (e0_imag * el0_real);
    sv_real[pos1_gid][pos1] = (e3_real * el1_real) - (e3_imag * el1_imag);
    sv_imag[pos1_gid][pos1] = (e3_real * el1_imag) + (e3_imag * el1_real);
    OP_TAIL;
}






//============== AdjointS Gate ================
//Clifford gate: conjugate of sqrt(Z) phase gate
/** SDG = [1  0]
          [0 -i]
*/
__device__ __inline__ void AdjointS_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const IdxType qubit)
{
    OP_HEAD;
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos1_gid][pos1] = el1_imag;
    sv_imag[pos1_gid][pos1] = -el1_real;
    OP_TAIL;
}

//============== AdjointT Gate ================
//C3 gate: conjugate of sqrt(S) phase gate
/** TDG = [1 0]
          [0 s2i-s2i*i]
*/
__device__ __inline__ void AdjointT_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const IdxType qubit)
{
    OP_HEAD;
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos1_gid][pos1] = S2I*( el1_real+el1_imag);
    sv_imag[pos1_gid][pos1] = S2I*(-el1_real+el1_imag);
    OP_TAIL;
}

//============== ControlledAdjointS Gate ================
//Clifford gate: conjugate of sqrt(Z) phase gate
/** SDG = [1  0]
          [0 -i]
*/
__device__ __inline__ void ControlledAdjointS_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const IdxType qubit, const IdxType mask)
{
    OP_HEAD_MASK;
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos1_gid][pos1] = el1_imag;
    sv_imag[pos1_gid][pos1] = -el1_real;
    OP_TAIL;
}

//============== ControlledAdjointT Gate ================
//C3 gate: conjugate of sqrt(S) phase gate
/** TDG = [1 0]
          [0 s2i-s2i*i]
*/
__device__ __inline__ void ControlledAdjointT_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const IdxType qubit, const IdxType mask)
{
    OP_HEAD_MASK;
    const ValType el1_real = sv_real[pos1_gid][pos1]; 
    const ValType el1_imag = sv_imag[pos1_gid][pos1];
    sv_real[pos1_gid][pos1] = S2I*( el1_real+el1_imag);
    sv_imag[pos1_gid][pos1] = S2I*(-el1_real+el1_imag);
    OP_TAIL;
}

//============== Swap Gate ================
//Swap the position of two qubits
// [1,0,0,0]
// [0,0,1,0]
// [0,1,0,0]
// [0,0,0,1]
//This is for qubit refinement when release or rearrange
__device__ __inline__ void SWAP_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, const IdxType qubit, const IdxType mask)
{
    const IdxType qubit1 = qubit;
    const IdxType qubit2 = mask;
    assert (qubit1 != qubit2); //Non-cloning
    multi_grid_group grid = this_multi_grid(); 
    const IdxType q0dim = ((IdxType)1 << max(qubit1, qubit2) );
    const IdxType q1dim = ((IdxType)1 << min(qubit1, qubit2) );
    const IdxType outer_factor = ((sim->dim) + q0dim + q0dim - 1) >> (max(qubit1,qubit2)+1);
    const IdxType mider_factor = (q0dim + q1dim + q1dim - 1) >> (min(qubit1,qubit2)+1);
    const IdxType inner_factor = q1dim;
    const IdxType qubit1_dim = ((IdxType)1 << qubit1);
    const IdxType qubit2_dim = ((IdxType)1 << qubit2);

    for (IdxType i = grid.thread_rank(); i < outer_factor * mider_factor * inner_factor; 
            i+=grid.size())
    {
        IdxType outer = ((i/inner_factor) / (mider_factor)) * (q0dim+q0dim);
        IdxType mider = ((i/inner_factor) % (mider_factor)) * (q1dim+q1dim);
        IdxType inner = i % inner_factor;
        IdxType pos0_org = outer + mider + inner;
        IdxType pos1_org = outer + mider + inner + qubit2_dim;
        IdxType pos2_org = outer + mider + inner + qubit1_dim;
        IdxType pos3_org = outer + mider + inner + q0dim + q1dim;

        IdxType pos0_gid = (pos0_org & (sim->n_gpus-1));
        IdxType pos1_gid = (pos1_org & (sim->n_gpus-1));
        IdxType pos2_gid = (pos2_org & (sim->n_gpus-1));
        IdxType pos3_gid = (pos3_org & (sim->n_gpus-1));

        IdxType pos0 = (pos0_org >> (sim->gpu_scale));
        IdxType pos1 = (pos1_org >> (sim->gpu_scale));
        IdxType pos2 = (pos2_org >> (sim->gpu_scale));
        IdxType pos3 = (pos3_org >> (sim->gpu_scale));

        const ValType el0_real = sv_real[pos0_gid][pos0]; 
        const ValType el0_imag = sv_imag[pos0_gid][pos0];
        const ValType el1_real = sv_real[pos1_gid][pos1]; 
        const ValType el1_imag = sv_imag[pos1_gid][pos1];
        const ValType el2_real = sv_real[pos2_gid][pos2]; 
        const ValType el2_imag = sv_imag[pos2_gid][pos2];
        const ValType el3_real = sv_real[pos3_gid][pos3]; 
        const ValType el3_imag = sv_imag[pos3_gid][pos3];

        //Real part
        sv_real[pos0_gid][pos0] = el0_real;
        sv_real[pos1_gid][pos1] = el2_real;
        sv_real[pos2_gid][pos2] = el1_real;
        sv_real[pos3_gid][pos3] = el3_real;

        //Imag part
        sv_imag[pos0_gid][pos0] = el0_imag;
        sv_imag[pos1_gid][pos1] = el2_imag;
        sv_imag[pos2_gid][pos2] = el1_imag; 
        sv_imag[pos3_gid][pos3] = el3_imag; 
    }
    grid.sync();
}

//============== Unified 1-qubit Gate ================
__device__ __inline__ void C1_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, 
        const ValType e0_real, const ValType e0_imag,
        const ValType e1_real, const ValType e1_imag,
        const ValType e2_real, const ValType e2_imag,
        const ValType e3_real, const ValType e3_imag,
        const IdxType qubit)
{
    OP_HEAD;
    const ValType el0_real = sv_real[pos0_gid][pos0];
    const ValType el0_imag = sv_imag[pos0_gid][pos0];
    const ValType el1_real = sv_real[pos1_gid][pos1];
    const ValType el1_imag = sv_imag[pos1_gid][pos1];

    sv_real[pos0_gid][pos0] = (e0_real * el0_real) - (e0_imag * el0_imag)
                   +(e1_real * el1_real) - (e1_imag * el1_imag);
    sv_imag[pos0_gid][pos0] = (e0_real * el0_imag) + (e0_imag * el0_real)
                   +(e1_real * el1_imag) + (e1_imag * el1_real);
    sv_real[pos1_gid][pos1] = (e2_real * el0_real) - (e2_imag * el0_imag)
                   +(e3_real * el1_real) - (e3_imag * el1_imag);
    sv_imag[pos1_gid][pos1] = (e2_real * el0_imag) + (e2_imag * el0_real)
                   +(e3_real * el1_imag) + (e3_imag * el1_real);
    OP_TAIL;
}



//============== Unified 2-qubit Gate ================
__device__ __inline__ void C2_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, 
        const ValType e00_real, const ValType e00_imag,
        const ValType e01_real, const ValType e01_imag,
        const ValType e02_real, const ValType e02_imag,
        const ValType e03_real, const ValType e03_imag,
        const ValType e10_real, const ValType e10_imag,
        const ValType e11_real, const ValType e11_imag,
        const ValType e12_real, const ValType e12_imag,
        const ValType e13_real, const ValType e13_imag,
        const ValType e20_real, const ValType e20_imag,
        const ValType e21_real, const ValType e21_imag,
        const ValType e22_real, const ValType e22_imag,
        const ValType e23_real, const ValType e23_imag,
        const ValType e30_real, const ValType e30_imag,
        const ValType e31_real, const ValType e31_imag,
        const ValType e32_real, const ValType e32_imag,
        const ValType e33_real, const ValType e33_imag,
        const IdxType qubit1, const IdxType qubit2)
{
    assert (qubit1 != qubit2); //Non-cloning
    multi_grid_group grid = this_multi_grid(); 
    const IdxType q0dim = ((IdxType)1 << max(qubit1, qubit2) );
    const IdxType q1dim = ((IdxType)1 << min(qubit1, qubit2) );
    const IdxType outer_factor = ((sim->dim) + q0dim + q0dim - 1) >> (max(qubit1,qubit2)+1);
    const IdxType mider_factor = (q0dim + q1dim + q1dim - 1) >> (min(qubit1,qubit2)+1);
    const IdxType inner_factor = q1dim;
    const IdxType qubit1_dim = ((IdxType)1 << qubit1);
    const IdxType qubit2_dim = ((IdxType)1 << qubit2);

    for (IdxType i = grid.thread_rank(); i < outer_factor * mider_factor * inner_factor; 
            i+=grid.size())
    {
        IdxType outer = ((i/inner_factor) / (mider_factor)) * (q0dim+q0dim);
        IdxType mider = ((i/inner_factor) % (mider_factor)) * (q1dim+q1dim);
        IdxType inner = i % inner_factor;
        IdxType pos0_org = outer + mider + inner;
        IdxType pos1_org = outer + mider + inner + qubit2_dim;
        IdxType pos2_org = outer + mider + inner + qubit1_dim;
        IdxType pos3_org = outer + mider + inner + q0dim + q1dim;

        IdxType pos0_gid = (pos0_org & (sim->n_gpus-1));
        IdxType pos1_gid = (pos1_org & (sim->n_gpus-1));
        IdxType pos2_gid = (pos2_org & (sim->n_gpus-1));
        IdxType pos3_gid = (pos3_org & (sim->n_gpus-1));

        IdxType pos0 = (pos0_org >> (sim->gpu_scale));
        IdxType pos1 = (pos1_org >> (sim->gpu_scale));
        IdxType pos2 = (pos2_org >> (sim->gpu_scale));
        IdxType pos3 = (pos3_org >> (sim->gpu_scale));

        const ValType el0_real = sv_real[pos0_gid][pos0]; 
        const ValType el0_imag = sv_imag[pos0_gid][pos0];
        const ValType el1_real = sv_real[pos1_gid][pos1]; 
        const ValType el1_imag = sv_imag[pos1_gid][pos1];
        const ValType el2_real = sv_real[pos2_gid][pos2]; 
        const ValType el2_imag = sv_imag[pos2_gid][pos2];
        const ValType el3_real = sv_real[pos3_gid][pos3]; 
        const ValType el3_imag = sv_imag[pos3_gid][pos3];

        //Real part
        sv_real[pos0_gid][pos0] = (e00_real * el0_real) - (e00_imag * el0_imag)
            +(e01_real * el1_real) - (e01_imag * el1_imag)
            +(e02_real * el2_real) - (e02_imag * el2_imag)
            +(e03_real * el3_real) - (e03_imag * el3_imag);
        sv_real[pos1_gid][pos1] = (e10_real * el0_real) - (e10_imag * el0_imag)
            +(e11_real * el1_real) - (e11_imag * el1_imag)
            +(e12_real * el2_real) - (e12_imag * el2_imag)
            +(e13_real * el3_real) - (e13_imag * el3_imag);
        sv_real[pos2_gid][pos2] = (e20_real * el0_real) - (e20_imag * el0_imag)
            +(e21_real * el1_real) - (e21_imag * el1_imag)
            +(e22_real * el2_real) - (e22_imag * el2_imag)
            +(e23_real * el3_real) - (e23_imag * el3_imag);
        sv_real[pos3_gid][pos3] = (e30_real * el0_real) - (e30_imag * el0_imag)
            +(e31_real * el1_real) - (e31_imag * el1_imag)
            +(e32_real * el2_real) - (e32_imag * el2_imag)
            +(e33_real * el3_real) - (e33_imag * el3_imag);
        
        //Imag part
        sv_imag[pos0_gid][pos0] = (e00_real * el0_imag) + (e00_imag * el0_real)
            +(e01_real * el1_imag) + (e01_imag * el1_real)
            +(e02_real * el2_imag) + (e02_imag * el2_real)
            +(e03_real * el3_imag) + (e03_imag * el3_real);
        sv_imag[pos1_gid][pos1] = (e10_real * el0_imag) + (e10_imag * el0_real)
            +(e11_real * el1_imag) + (e11_imag * el1_real)
            +(e12_real * el2_imag) + (e12_imag * el2_real)
            +(e13_real * el3_imag) + (e13_imag * el3_real);
        sv_imag[pos2_gid][pos2] = (e20_real * el0_imag) + (e20_imag * el0_real)
            +(e21_real * el1_imag) + (e21_imag * el1_real)
            +(e22_real * el2_imag) + (e22_imag * el2_real)
            +(e23_real * el3_imag) + (e23_imag * el3_real);
        sv_imag[pos3_gid][pos3] = (e30_real * el0_imag) + (e30_imag * el0_real)
            +(e31_real * el1_imag) + (e31_imag * el1_real)
            +(e32_real * el2_imag) + (e32_imag * el2_real)
            +(e33_real * el3_imag) + (e33_imag * el3_real);
    }
    grid.sync();
}

#define DIV2E(x,y) ((x)>>(y))
#define MOD2E(x,y) ((x)&(((IdxType)1<<(y))-(IdxType)1)) 
#define EXP2E(x) ((IdxType)1<<(x))
#define SV8IDX(x) ( ((x>>2)&1)*EXP2E(qubit0) + ((x>>1)&1)*EXP2E(qubit1) + ((x&1)*EXP2E(qubit2)) )
#define SV16IDX(x) ( ((x>>3)&1)*EXP2E(qubit0) + ((x>>2)&1)*EXP2E(qubit1) + ((x>>1)&1)*EXP2E(qubit2) + ((x&1)*EXP2E(qubit3)) )

//#define PGAS(arr,i) (arr[(i)>>(sim->lg2_m_gpu)][(i)&((sim->m_gpu)-1UL)])
#define PGAS(arr,i) (arr[(i)&(sim->n_gpus-1)][(i)>>(sim->gpu_scale)])

//============== Unified 3-qubit Gate ================
//gm_real and gm_imag should be put in constant memory
__device__ __inline__ void C3_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, 
        const ValType* gm_real, const ValType* gm_imag, const IdxType qubit0, const IdxType qubit1,
        const IdxType qubit2)
{
    multi_grid_group grid = this_multi_grid(); 
    assert (qubit0 != qubit1); //Non-cloning
    assert (qubit0 != qubit2); //Non-cloning
    assert (qubit1 != qubit2); //Non-cloning

    //need to sort qubits: min->max: p, q, r
    const IdxType p = min(min(qubit0, qubit1), qubit2);
    const IdxType r = max(max(qubit0, qubit1), qubit2);
    const IdxType q = qubit0 + qubit1 + qubit2 - p - r;

    for (IdxType i = grid.thread_rank(); i < ((sim->dim)>>3); i+=grid.size())
    {
        const IdxType term0 = MOD2E(i,p);
        const IdxType term1 = MOD2E(DIV2E(i,p),q-p-1)*EXP2E(p+1);
        const IdxType term2 = MOD2E(DIV2E(DIV2E(i,p),q-p-1),r-q-1)*EXP2E(q+1);
        const IdxType term3 = DIV2E(DIV2E(DIV2E(i,p),q-p-1),r-q-1)*EXP2E(r+1);
        const IdxType term = term3 + term2 + term1 + term0;

        const ValType el_real[8] = { 
            PGAS(sv_real,term+SV8IDX(0)), PGAS(sv_real,term+SV8IDX(1)),
            PGAS(sv_real,term+SV8IDX(2)), PGAS(sv_real,term+SV8IDX(3)),
            PGAS(sv_real,term+SV8IDX(4)), PGAS(sv_real,term+SV8IDX(5)),
            PGAS(sv_real,term+SV8IDX(6)), PGAS(sv_real,term+SV8IDX(7))
        };
        const ValType el_imag[8] = { 
            PGAS(sv_imag,term+SV8IDX(0)), PGAS(sv_imag,term+SV8IDX(1)),
            PGAS(sv_imag,term+SV8IDX(2)), PGAS(sv_imag,term+SV8IDX(3)),
            PGAS(sv_imag,term+SV8IDX(4)), PGAS(sv_imag,term+SV8IDX(5)),
            PGAS(sv_imag,term+SV8IDX(6)), PGAS(sv_imag,term+SV8IDX(7))
        };
        #pragma unroll
        for (unsigned j=0; j<8; j++)
        {
            ValType res_real = 0;
            ValType res_imag = 0;
            #pragma unroll
            for (unsigned k=0; k<8; k++)
            {
                res_real += (el_real[k] * gm_real[j*8+k]) - (el_imag[k] * gm_imag[j*8+k]);
                res_imag += (el_real[k] * gm_imag[j*8+k]) + (el_imag[k] * gm_real[j*8+k]);
            }
            PGAS(sv_real, term+SV8IDX(j)) = res_real;
            PGAS(sv_imag, term+SV8IDX(j)) = res_imag;
        }
    }
    grid.sync();
}

//============== Unified 4-qubit Gate ================
//gm_real and gm_imag should be put in constant memory
__device__ __inline__ void C4_GATE(const Simulation* sim, ValType** sv_real, ValType** sv_imag, 
        const ValType* gm_real, const ValType* gm_imag, const IdxType qubit0, const IdxType qubit1,
        const IdxType qubit2, const IdxType qubit3)
{
    multi_grid_group grid = this_multi_grid(); 
    assert (qubit0 != qubit1); //Non-cloning
    assert (qubit0 != qubit2); //Non-cloning
    assert (qubit0 != qubit3); //Non-cloning
    assert (qubit1 != qubit2); //Non-cloning
    assert (qubit1 != qubit3); //Non-cloning
    assert (qubit2 != qubit3); //Non-cloning

    //need to sort qubits: min->max: p, q, r, s
    const IdxType v0 = min(qubit0, qubit1);
    const IdxType v1 = min(qubit2, qubit3);
    const IdxType v2 = max(qubit0, qubit1);
    const IdxType v3 = max(qubit2, qubit3);
    const IdxType p = min(v0,v1); 
    const IdxType q = min(min(v2,v3),max(v0,v1)); 
    const IdxType r = max(min(v2,v3),max(v0,v1)); 
    const IdxType s = max(v2,v3);

    for (IdxType i = grid.thread_rank(); i < ((sim->dim)>>4); i+=grid.size())
    {
        const IdxType term0 = MOD2E(i,p);
        const IdxType term1 = MOD2E(DIV2E(i,p),q-p-1)*EXP2E(p+1);
        const IdxType term2 = MOD2E(DIV2E(DIV2E(i,p),q-p-1),r-q-1)*EXP2E(q+1);
        const IdxType term3 = MOD2E(DIV2E(DIV2E(DIV2E(i,p),q-p-1),r-q-1),s-r-1)*EXP2E(r+1);
        const IdxType term4 = DIV2E(DIV2E(DIV2E(DIV2E(i,p),q-p-1),r-q-1),s-r-1)*EXP2E(s+1);
        const IdxType term = term4 + term3 + term2 + term1 + term0;

        const ValType el_real[16] = { 
            PGAS(sv_real,term+SV16IDX(0)),  PGAS(sv_real,term+SV16IDX(1)),
            PGAS(sv_real,term+SV16IDX(2)),  PGAS(sv_real,term+SV16IDX(3)),
            PGAS(sv_real,term+SV16IDX(4)),  PGAS(sv_real,term+SV16IDX(5)),
            PGAS(sv_real,term+SV16IDX(6)),  PGAS(sv_real,term+SV16IDX(7)),
            PGAS(sv_real,term+SV16IDX(8)),  PGAS(sv_real,term+SV16IDX(9)),
            PGAS(sv_real,term+SV16IDX(10)), PGAS(sv_real,term+SV16IDX(11)),
            PGAS(sv_real,term+SV16IDX(12)), PGAS(sv_real,term+SV16IDX(13)),
            PGAS(sv_real,term+SV16IDX(14)), PGAS(sv_real,term+SV16IDX(15))
        };
        const ValType el_imag[16] = { 
            PGAS(sv_imag,term+SV16IDX(0)),  PGAS(sv_imag,term+SV16IDX(1)),
            PGAS(sv_imag,term+SV16IDX(2)),  PGAS(sv_imag,term+SV16IDX(3)),
            PGAS(sv_imag,term+SV16IDX(4)),  PGAS(sv_imag,term+SV16IDX(5)),
            PGAS(sv_imag,term+SV16IDX(6)),  PGAS(sv_imag,term+SV16IDX(7)),
            PGAS(sv_imag,term+SV16IDX(8)),  PGAS(sv_imag,term+SV16IDX(9)),
            PGAS(sv_imag,term+SV16IDX(10)), PGAS(sv_imag,term+SV16IDX(11)),
            PGAS(sv_imag,term+SV16IDX(12)), PGAS(sv_imag,term+SV16IDX(13)),
            PGAS(sv_imag,term+SV16IDX(14)), PGAS(sv_imag,term+SV16IDX(15))
        };
        #pragma unroll
        for (unsigned j=0; j<16; j++)
        {
            ValType res_real = 0;
            ValType res_imag = 0;
            #pragma unroll
            for (unsigned k=0; k<16; k++)
            {
                res_real += (el_real[k] * gm_real[j*16+k]) - (el_imag[k] * gm_imag[j*16+k]);
                res_imag += (el_real[k] * gm_imag[j*16+k]) + (el_imag[k] * gm_real[j*16+k]);
            }
            PGAS(sv_real,term+SV16IDX(j)) = res_real;
            PGAS(sv_imag,term+SV16IDX(j)) = res_imag;
        }
    }
    grid.sync();
}


//============== Measurement Gate ================
/** Pr(Zero||\psi>) = 1/2 <\psi| |(1+P0 \tp P1 \tp ... \tp P(N-1) )| |\psi>
  Pauli Measurement | Unitary Transformation
         Z          |          1
         X          |          H
         Y          |         H-AdjointS
*/
__device__ __inline__ void Measure_GATE(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    multi_grid_group grid = this_multi_grid();
    IdxType qubit = g->qubit; 
    ValType rand = g->theta;
    IdxType pauli = g->mask;
    const int tid = blockDim.x * blockIdx.x + threadIdx.x;

    ValType** m_real = sim->m_real;

    IdxType mask = ((IdxType)1<<qubit);

    if (pauli == 1)
    {
        H_GATE(sim, sv_real, sv_imag, qubit);
        H_GATE(sim, sv_real, sv_imag, sim->n_qubits+qubit);
    }
    if (pauli == 2)
    {
        AdjointS_GATE(sim, sv_real, sv_imag, qubit);
        S_GATE(sim, sv_real, sv_imag, sim->n_qubits+qubit);
        H_GATE(sim, sv_real, sv_imag, qubit);
        H_GATE(sim, sv_real, sv_imag, sim->n_qubits+qubit);
    }

    for (IdxType i = grid.thread_rank(); i<((IdxType)1<<(sim->n_qubits)); i+=grid.size())
    {
        if ( (i & mask) == 0) //for all conditions with qubit=0, we set it to 0, so we sum up all prob that qubit=1
        {
            PGAS(m_real,i) = 0.;
        }
        else
        {
            PGAS(m_real,i) = abs(PGAS(sv_real,((i<<(sim->n_qubits))+i)));
        }
    }
    grid.sync();
    for (IdxType k=(sim->half_dim); k>0; k>>=1)
    {
        for (IdxType i=grid.thread_rank(); i<k; i+=grid.size())
        {
            PGAS(m_real,i) += PGAS(m_real,i+k);
        }
        grid.sync();
    }

    grid.sync();

    //if (tid ==0 ) printf("m_real[%d] is:%lf\n",tid,m_real[tid]);
    ValType prob_of_one = m_real[0][0];
    grid.sync();

    //Now m_real[0] should have the probability of being 1
    bool val = (rand < prob_of_one);
    
    if (val) // we get 1, so we set all entires with (id&mask==0) to 0, and scale entires with (id&mask==1) by factor
    {
        //ValType factor = (prob_of_one == 0) ? 1. : 1./sqrt(prob_of_one); //we compute 1/sqrt(prob), so other entries can times this val
        ValType factor = 1./prob_of_one; //we compute 1/sqrt(prob), so other entries can times this val

        //assert(factor > 0);

        //ValType factor = 1./sqrt(1-prob_of_one); //we compute 1/sqrt(prob), so other entries can times this val



        //if (tid == 0 ) printf("qubit:%lu, prob:%lf, mask:%lu, m0:%lf, factor:%lf, dim:%lu, half-dim:%lu \n",qubit, rand, mask, m_real[0], factor, sim->dim, sim->half_dim);
        
        //if (tid == 0 ) printf("qubit:%lu, prob:%lf, mask:%lu, m0:%lf, factor:%lf, dim:%lu, half-dim:%lu \n",qubit, rand, mask, m_real[0], factor, sim->dim, sim->half_dim);

        //if (tid ==0 ) printf("m_real[0]:%lf, factor:%lf",m_real[0], factor);

        for (IdxType i=grid.thread_rank(); i<(sim->dim); i+=grid.size())
        {
            if ( (i & mask) == 0)
            {
                PGAS(sv_real,i) = 0.;
                PGAS(sv_imag,i) = 0.;
            }
            else
            {
                PGAS(sv_real,i) *= factor;
                PGAS(sv_imag,i) *= factor;
            }
        }
    }
    else // we get 0, so we set all entires with (id&mask!=0) to 0, and scale entires with (id&mask==0) by factor
    {
        //ValType factor = (prob_of_one == 1) ? 1. : 1./sqrt(1.-prob_of_one); //we compute 1/sqrt(prob), so other entries can times this val
        //ValType factor =  1./sqrt(1.-prob_of_one); //we compute 1/sqrt(prob), so other entries can times this val

        ValType factor =  1./(1.-prob_of_one); //we compute 1/sqrt(prob), so other entries can times this val

        //assert(factor > 0);

        //if (tid == 0 ) printf("qubit:%lu, prob:%lf, mask:%lu, m0:%lf, factor:%lf, dim:%lu, half-dim:%lu \n",qubit, rand, mask, m_real[0], factor, sim->dim, sim->half_dim);

        for (IdxType i=grid.thread_rank(); i<(sim->dim); i+=grid.size())
        {
            if ( (i & mask) == 0)
            {
                PGAS(sv_real,i) *= factor;
                PGAS(sv_imag,i) *= factor;
            }
            else
            {
                PGAS(sv_real,i) = 0.;
                PGAS(sv_imag,i) = 0.;
            }
        }
    }

    grid.sync();
    if (pauli == 1)
    {
        H_GATE(sim, sv_real, sv_imag, qubit);
        H_GATE(sim, sv_real, sv_imag, sim->n_qubits+qubit);
    }
    if (pauli == 2)
    {
        H_GATE(sim, sv_real, sv_imag, qubit);
        H_GATE(sim, sv_real, sv_imag, sim->n_qubits+qubit);
        S_GATE(sim, sv_real, sv_imag, qubit);
        AdjointS_GATE(sim, sv_real, sv_imag, sim->n_qubits+qubit);
    }
}

__device__ void X_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    X_GATE(sim, sv_real, sv_imag, g->qubit); 
    X_GATE(sim, sv_real, sv_imag, (g->qubit)+(sim->n_qubits));

    /*
    C2_GATE(sim, sv_real, sv_imag, XR0,XI0, XR1,XI1, XR2,XI2, XR3,XI3,
                                   XR4,XI4, XR5,XI5, XR6,XI6, XR7,XI7,
                                   XR8,XI8, XR9,XI9, XR10,XI10, XR11,XI11,
                                   XR12,XI12, XR13,XI13, XR14,XI14, XR15,XI15,
            g->qubit, (g->qubit)+(sim->n_qubits));
     */
}

__device__ void Y_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    Y_GATE(sim, sv_real, sv_imag, g->qubit); 
    ConjugateY_GATE(sim, sv_real, sv_imag, (g->qubit)+(sim->n_qubits));

    /*
    C2_GATE(sim, sv_real, sv_imag, YR0,YI0, YR1,YI1, YR2,YI2, YR3,YI3,
                                   YR4,YI4, YR5,YI5, YR6,YI6, YR7,YI7,
                                   YR8,YI8, YR9,YI9, YR10,YI10, YR11,YI11,
                                   YR12,YI12, YR13,YI13, YR14,YI14, YR15,YI15,
            g->qubit, (g->qubit)+(sim->n_qubits));
     */
}

__device__ void Z_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    Z_GATE(sim, sv_real, sv_imag, g->qubit); 
    Z_GATE(sim, sv_real, sv_imag, (g->qubit)+(sim->n_qubits));

    /*
    C2_GATE(sim, sv_real, sv_imag, ZR0,ZI0, ZR1,ZI1, ZR2,ZI2, ZR3,ZI3,
                                   ZR4,ZI4, ZR5,ZI5, ZR6,ZI6, ZR7,ZI7,
                                   ZR8,ZI8, ZR9,ZI9, ZR10,ZI10, ZR11,ZI11,
                                   ZR12,ZI12, ZR13,ZI13, ZR14,ZI14, ZR15,ZI15,
            g->qubit, (g->qubit)+(sim->n_qubits));
     */
}

__device__ void H_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    H_GATE(sim, sv_real, sv_imag, g->qubit); 
    H_GATE(sim, sv_real, sv_imag, (g->qubit)+(sim->n_qubits));
    
    /*
    C2_GATE(sim, sv_real, sv_imag, HR0,HI0, HR1,HI1, HR2,HI2, HR3,HI3,
                                   HR4,HI4, HR5,HI5, HR6,HI6, HR7,HI7,
                                   HR8,HI8, HR9,HI9, HR10,HI10, HR11,HI11,
                                   HR12,HI12, HR13,HI13, HR14,HI14, HR15,HI15,
            g->qubit, (g->qubit)+(sim->n_qubits));
     */
}

__device__ void S_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    S_GATE(sim, sv_real, sv_imag, g->qubit); 
    AdjointS_GATE(sim, sv_real, sv_imag, (g->qubit)+(sim->n_qubits));
}

__device__ void T_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    T_GATE(sim, sv_real, sv_imag, g->qubit); 
    AdjointT_GATE(sim, sv_real, sv_imag, (g->qubit)+(sim->n_qubits));
}

__device__ void AdjointS_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    AdjointS_GATE(sim, sv_real, sv_imag, g->qubit); 
    S_GATE(sim, sv_real, sv_imag, (g->qubit)+(sim->n_qubits));
}

__device__ void AdjointT_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    AdjointT_GATE(sim, sv_real, sv_imag, g->qubit); 
    T_GATE(sim, sv_real, sv_imag, (g->qubit)+(sim->n_qubits));
}

__device__ void RI_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    RI_GATE(sim, sv_real, sv_imag, g->theta, g->qubit); 
    ConjugateRI_GATE(sim, sv_real, sv_imag, g->theta, (g->qubit)+(sim->n_qubits));
}

__device__ void RX_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    RX_GATE(sim, sv_real, sv_imag, g->theta, g->qubit); 
    ConjugateRX_GATE(sim, sv_real, sv_imag, g->theta, (g->qubit)+(sim->n_qubits));
}

__device__ void RY_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    RY_GATE(sim, sv_real, sv_imag, g->theta, g->qubit); 
    RY_GATE(sim, sv_real, sv_imag, g->theta, (g->qubit)+(sim->n_qubits));
}

__device__ void RZ_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    RZ_GATE(sim, sv_real, sv_imag, g->theta, g->qubit); 
    ConjugateRZ_GATE(sim, sv_real, sv_imag, g->theta, (g->qubit)+(sim->n_qubits));
}

__device__ void EI_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    EI_GATE(sim, sv_real, sv_imag, g->theta, g->qubit); 
    ConjugateEI_GATE(sim, sv_real, sv_imag, g->theta, (g->qubit)+(sim->n_qubits));
}

__device__ void EX_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    EX_GATE(sim, sv_real, sv_imag, g->theta, g->qubit); 
    ConjugateEX_GATE(sim, sv_real, sv_imag, g->theta, (g->qubit)+(sim->n_qubits));
}

__device__ void EY_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    EY_GATE(sim, sv_real, sv_imag, g->theta, g->qubit); 
    EY_GATE(sim, sv_real, sv_imag, g->theta, (g->qubit)+(sim->n_qubits));
}

__device__ void EZ_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    EZ_GATE(sim, sv_real, sv_imag, g->theta, g->qubit); 
    ConjugateEZ_GATE(sim, sv_real, sv_imag, g->theta, (g->qubit)+(sim->n_qubits));
}

__device__ void ControlledX_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    ControlledX_GATE(sim, sv_real, sv_imag, g->qubit, g->mask); 
    ControlledX_GATE(sim, sv_real, sv_imag, (g->qubit)+(sim->n_qubits), (g->mask)<<(sim->n_qubits));

    /*
    if (__popcll(g->mask) == 1)
    {
        IdxType control = __ffsll(g->mask)-1;
        C4_GATE(sim, sv_real, sv_imag, CX_real, CX_imag, control, g->qubit, control+(sim->n_qubits), (g->qubit)+(sim->n_qubits));
    }
    else
    {
        ControlledX_GATE(sim, sv_real, sv_imag, g->qubit, g->mask); 
        ControlledX_GATE(sim, sv_real, sv_imag, (g->qubit)+(sim->n_qubits), (g->mask)<<(sim->n_qubits));
    }
     */
 

    
}

__device__ void ControlledY_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    ControlledY_GATE(sim, sv_real, sv_imag, g->qubit, g->mask); 
    ControlledConjugateY_GATE(sim, sv_real, sv_imag, (g->qubit)+(sim->n_qubits), (g->mask)<<(sim->n_qubits));
}

__device__ void ControlledZ_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    ControlledZ_GATE(sim, sv_real, sv_imag, g->qubit, g->mask); 
    ControlledZ_GATE(sim, sv_real, sv_imag, (g->qubit)+(sim->n_qubits), (g->mask)<<(sim->n_qubits));

/*
    if (__popcll(g->mask) == 1)
    {
        IdxType control = __ffsll(g->mask)-1;
        C4_GATE(sim, sv_real, sv_imag, CZ_real, CZ_imag, control, g->qubit, control+(sim->n_qubits), (g->qubit)+(sim->n_qubits));
    }
    else
    {
        ControlledZ_GATE(sim, sv_real, sv_imag, g->qubit, g->mask); 
        ControlledZ_GATE(sim, sv_real, sv_imag, (g->qubit)+(sim->n_qubits), (g->mask)<<(sim->n_qubits));
    }
     */
 

}

__device__ void ControlledH_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    ControlledH_GATE(sim, sv_real, sv_imag, g->qubit, g->mask); 
    ControlledH_GATE(sim, sv_real, sv_imag, (g->qubit)+(sim->n_qubits), (g->mask)<<(sim->n_qubits));
} 

__device__ void ControlledS_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    ControlledS_GATE(sim, sv_real, sv_imag, g->qubit, g->mask); 
    ControlledAdjointS_GATE(sim, sv_real, sv_imag, (g->qubit)+(sim->n_qubits), (g->mask)<<(sim->n_qubits));
} 

__device__ void ControlledT_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    ControlledT_GATE(sim, sv_real, sv_imag, g->qubit, g->mask); 
    ControlledAdjointT_GATE(sim, sv_real, sv_imag, (g->qubit)+(sim->n_qubits), (g->mask)<<(sim->n_qubits));
} 


__device__ void ControlledRI_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    ControlledRI_GATE(sim, sv_real, sv_imag, g->theta, g->qubit, g->mask); 
    ControlledConjugateRI_GATE(sim, sv_real, sv_imag, g->theta, (g->qubit)+(sim->n_qubits), (g->mask)<<(sim->n_qubits));
} 

__device__ void ControlledRX_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    ControlledRX_GATE(sim, sv_real, sv_imag, g->theta, g->qubit, g->mask); 
    ControlledConjugateRX_GATE(sim, sv_real, sv_imag, g->theta, (g->qubit)+(sim->n_qubits), (g->mask)<<(sim->n_qubits));
} 

__device__ void ControlledRY_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    ControlledRY_GATE(sim, sv_real, sv_imag, g->theta, g->qubit, g->mask); 
    ControlledRY_GATE(sim, sv_real, sv_imag, g->theta, (g->qubit)+(sim->n_qubits), (g->mask)<<(sim->n_qubits));
} 

__device__ void ControlledRZ_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    ControlledRZ_GATE(sim, sv_real, sv_imag, g->theta, g->qubit, g->mask); 
    ControlledConjugateRZ_GATE(sim, sv_real, sv_imag, g->theta, (g->qubit)+(sim->n_qubits), (g->mask)<<(sim->n_qubits));
} 

__device__ void ControlledEI_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    ControlledEI_GATE(sim, sv_real, sv_imag, g->theta, g->qubit, g->mask); 
    ControlledConjugateEI_GATE(sim, sv_real, sv_imag, g->theta, (g->qubit)+(sim->n_qubits), (g->mask)<<(sim->n_qubits));
} 

__device__ void ControlledEX_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    ControlledEX_GATE(sim, sv_real, sv_imag, g->theta, g->qubit, g->mask); 
    ControlledConjugateEX_GATE(sim, sv_real, sv_imag, g->theta, (g->qubit)+(sim->n_qubits), (g->mask)<<(sim->n_qubits));
} 

__device__ void ControlledEY_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    ControlledEY_GATE(sim, sv_real, sv_imag, g->theta, g->qubit, g->mask); 
    ControlledEY_GATE(sim, sv_real, sv_imag, g->theta, (g->qubit)+(sim->n_qubits), (g->mask)<<(sim->n_qubits));
} 

__device__ void ControlledEZ_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    ControlledEZ_GATE(sim, sv_real, sv_imag, g->theta, g->qubit, g->mask); 
    ControlledConjugateEZ_GATE(sim, sv_real, sv_imag, g->theta, (g->qubit)+(sim->n_qubits), (g->mask)<<(sim->n_qubits));
} 

__device__ void ControlledAdjointS_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    ControlledAdjointS_GATE(sim, sv_real, sv_imag, g->qubit, g->mask); 
    ControlledS_GATE(sim, sv_real, sv_imag, (g->qubit)+(sim->n_qubits), (g->mask)<<(sim->n_qubits));
} 

__device__ void ControlledAdjointT_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    ControlledAdjointT_GATE(sim, sv_real, sv_imag, g->qubit, g->mask); 
    ControlledT_GATE(sim, sv_real, sv_imag, (g->qubit)+(sim->n_qubits), (g->mask)<<(sim->n_qubits));
} 

__device__ void SWAP_OP(const Gate* g, const Simulation* sim, ValType** sv_real, ValType** sv_imag)
{
    SWAP_GATE(sim, sv_real, sv_imag, g->qubit, g->mask); 
    SWAP_GATE(sim, sv_real, sv_imag, (g->qubit)+(sim->n_qubits), (g->mask)+(sim->n_qubits));
} 









// ============================ Device Function Pointers ================================
__device__ func_t pX = X_OP;
__device__ func_t pY = Y_OP; 
__device__ func_t pZ = Z_OP; 
__device__ func_t pH = H_OP; 
__device__ func_t pS = S_OP;
__device__ func_t pT = T_OP;
__device__ func_t pRI = RI_OP;
__device__ func_t pRX = RX_OP;
__device__ func_t pRY = RY_OP;
__device__ func_t pRZ = RZ_OP;
__device__ func_t pEI = EI_OP;
__device__ func_t pEX = EX_OP;
__device__ func_t pEY = EY_OP;
__device__ func_t pEZ = EZ_OP;
__device__ func_t pControlledX = ControlledX_OP;
__device__ func_t pControlledY = ControlledY_OP; 
__device__ func_t pControlledZ = ControlledZ_OP; 
__device__ func_t pControlledH = ControlledH_OP; 
__device__ func_t pControlledS = ControlledS_OP;
__device__ func_t pControlledT = ControlledT_OP;
__device__ func_t pControlledRI = ControlledRI_OP;
__device__ func_t pControlledRX = ControlledRX_OP;
__device__ func_t pControlledRY = ControlledRY_OP;
__device__ func_t pControlledRZ = ControlledRZ_OP;
__device__ func_t pControlledEI = ControlledEI_OP;
__device__ func_t pControlledEX = ControlledEX_OP;
__device__ func_t pControlledEY = ControlledEY_OP;
__device__ func_t pControlledEZ = ControlledEZ_OP;
__device__ func_t pAdjointS = AdjointS_OP;
__device__ func_t pAdjointT = AdjointT_OP;
__device__ func_t pControlledAdjointS = ControlledAdjointS_OP;
__device__ func_t pControlledAdjointT = ControlledAdjointT_OP;
__device__ func_t pSwap = SWAP_OP;
__device__ func_t pMeasure = Measure_GATE;
//=====================================================================================

}; //namespace SVSim

#endif
