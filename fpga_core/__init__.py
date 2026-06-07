"""fpga_core -- FPGA RTL synchronization and filelist generation tools.

Modules:
    config:   Configuration, path management, regex constants, Tcl templates
    block_extractor: State-machine extraction of `ifdef FPGA_SYN blocks
    scanner:  Unified directory scanning for rtl_v/fpga_v/stub_v
    merger:   Core diff-and-merge logic between RTL and FPGA files
    memory:   MBIST memory port extraction and FPGA SP RAM generation
    filelist: Filelist.f generation for FPGA synthesis
    report:   bcompare HTML diff report generation and merging
"""

__version__ = "2.0.0"
