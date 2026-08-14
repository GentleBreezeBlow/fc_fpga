trimcode_chk_enable=0;
override_chk_enable=0;
end

//------------------------------------
//// IO ports declaration********************
output RDONE;
// LIB++ power(VDD) , ground(VSS), power_down(!VDD+VSS+!VDIO), max_capacitance(*_cap), max_transition(pin_max_transition)
input SET;       // LIB++ power(VDD) , ground(VSS), capacitance(*_cap), max_transition(pin_max_transition)
input RESET;     // LIB++ power(VDD) , ground(VSS), capacitance(*_cap), max_transition(pin_max_transition)
//input RECALL;
//input CK_EXT;
input RST;       // LIB++ power(VDD) , ground(VSS), capacitance(*_cap), max_transition(pin_max_transition)
input NAP;       // LIB++ power(VDD) , ground(VSS), capacitance(*_cap), max_transition(pin_max_transition)
//input HTOL_EN;
input IFREN;     // LIB++ power(VDD) , ground(VSS), capacitance(*_cap), max_transition(pin_max_transition)
input IFREN1;    // LIB++ power(VDD) , ground(VSS), capacitance(*_cap), max_transition(pin_max_transition)
input REDEN;     // LIB++ power(VDD) , ground(VSS), capacitance(*_cap), max_transition(pin_max_transition)
input XE;        // LIB++ power(VDD) , ground(VSS), capacitance(*_cap), max_transition(pin_max_transition)
input YE;        // LIB++ power(VDD) , ground(VSS), capacitance(*_cap), max_transition(pin_max_transition)
input READ;      // LIB++ power(VDD) , ground(VSS), capacitance(*_cap), clock(true), max_transition(pin_max_transition)
//input PD;
//input RST_N;
input CE;        // LIB++ power(VDD) , ground(VSS), capacitance(*_cap), max_transition(pin_max_transition)
input POC_IO;    // LIB++ power(VDIO), ground(VSS), capacitance(*_cap), max_transition(pin_max_transition)
input PCH_EXT;   // LIB++ power(VDD) , ground(VSS), capacitance(*_cap), max_transition(pin_max_transition)
input AE;        // LIB++ power(VDD) , ground(VSS), capacitance(*_cap), max_transition(pin_max_transition)
//input DATAMEM;
input [numXadr-1:0] XADR;    // LIB++ power(VDD) , ground(VSS), capacitance(*_cap), max_transition(pin_max_transition)
input [numYadr-1:0] YADR;    // LIB++ power(VDD) , ground(VSS), capacitance(*_cap), max_transition(pin_max_transition)

output [numOut-1:0] DOUT;
// LIB++ power(VDD) , ground(VSS), power_down(!VDD+VSS+!VDIO), max_capacitance(*_cap), max_transition(pin_max_transition)
input [numOut-1:0] DIN;        // LIB++ power(VDD) , ground(VSS), capacitance(*_cap), max_transition(pin_max_transition)
input [numCFG-1:0] CFG_MACRO;  // LIB++ power(VDD) , ground(VSS), capacitance(*_cap), max_transition(pin_max_transition)

//new
//analog
//inout [numANA-1:0] ANALOG;
//inout [7:0] DMA_ANA;

input [numCR-1:0] DIN_CR;    // LIB++ power(VDD) , ground(VSS), capacitance(*_cap), max_transition(pin_max_transition)
output [numCR-1:0] DOUT_CR;
// LIB++ power(VDD) , ground(VSS), power_down(!VDD+VSS+!VDIO), max_capacitance(*_cap), max_transition(pin_max_transition)

`ifdef UPF
input VSS;    // LIB++ voltage(VSS) , pg_type(primary_ground)
input VDD;    // LIB++ voltage(VDD) , pg_type(primary_power)
input VDIO;   // LIB++ voltage(VDIO), pg_type(primary_power)
//inout ANALOG_0;
`endif

inout ANALOG_0;
// LIB++ power(VDIO), ground(VSS), capacitance(*_cap), power_down(!VDD+VSS+!VDIO), max_capacitance(100), is_analog(true), max_transition
//inout ANALOG_1;
// LIB++ power(VDIO), ground(VSS), capacitance(*_cap), power_down(!VDD+VSS+!VDIO), max_capacitance(100), is_analog(true)

//================================================
// LIBERTY leakage_power_begin -- (uA x V = uW)
//================================================
// <NAME>   : <POWER_PIN> : <VALUE>              : <WHEN>                    -- <comments>
// Idd1   : VDIO      : rd_Idd1_vdio33_uW      : CE * !NAP * READ * !RESET * !SET -- in READ mode
// Idd1   : VDD       : rd_Idd1_vd33_uW        : CE * !NAP * READ * !RESET * !SET -- in READ mode
// Iwrite : VDIO      : wr_Idd1_vdio33_uW      : CE * !NAP * !READ * (RESET | SET)* !CFG_MACRO[118] -- in WRITE mode
// Iwrite : VDD       : wr_Idd1_vd33_uW        : CE * !NAP * !READ * (RESET | SET)* !CFG_MACRO[118] -- in WRITE mode
// Iform  : VDIO      : IFORM_VDIO_uW          : CE * !NAP * !READ * (RESET | SET)* CFG_MACRO[118] -- in FORM mode