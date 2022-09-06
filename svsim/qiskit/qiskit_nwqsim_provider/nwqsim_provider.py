# -*- coding: utf-8 -*-

# Copyright 2018, IBM.
#
# This source code is licensed under the Apache License, Version 2.0 found in
# the LICENSE.txt file in the root directory of this source tree.

"""Provider for the NWQSim backend."""

from qiskit.providers import ProviderV1 as Provider
from qiskit.providers.providerutils import filter_backends
from qiskit_nwqsim_provider.dmsim_cpu_simulator import DMSimCpuSimulator
from qiskit_nwqsim_provider.svsim_cpu_simulator import SVSimCpuSimulator

class NWQSimProvider(Provider):
    """Provider for the NWQSim backend."""

    def __init__(self, token=None):
        super().__init__()
        self.token = token
        self.backends = {'dmsim_cpu': DMSimCpuSimulator(provider=self),
                         'svsim_cpu': SVSimCpuSimulator(provider=self)}

    def backends(self, name=None, **kwargs):
        if name:
            backends = [
                    backend for backend in backends if backend.name() == name]
        return filter_backends(backends, filters=filters, **kwargs)

    def __str__(self):
        return 'NWQSimProvider'
