#include <verilated.h>
#include "Vtop.h"

#include <iostream>

int main(int argc, char* argv[]) {
    std::cout << "hello!" << std::endl;
        
    Verilated::commandArgs(argc, argv);

    Vtop* top = new Vtop;
    top->eval();
}

