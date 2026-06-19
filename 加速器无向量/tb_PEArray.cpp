#include "VPEArray.h"
#include "verilated.h"
#include "verilated_saif_c.h"

vluint64_t main_time = 0;

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    // 初始化 SAIF（去掉 VCD 相关代码）
    Verilated::traceEverOn(true);
    VerilatedSaifC* saif = new VerilatedSaifC;
    VPEArray* top = new VPEArray;
    
    top->trace(saif, 99);
    saif->open("dump.saif");
    
    // 仿真循环
    top->clk = 0;
    while (!Verilated::gotFinish() && main_time < 10000) {
        if (main_time % 10 == 0) top->clk = !top->clk;
        top->eval();
        saif->dump(main_time);
        main_time++;
    }
    
    saif->close();
    delete top;
    delete saif;
    return 0;
}
