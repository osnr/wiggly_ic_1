#include <verilated.h>
#include "Vtop.h"

#include <iostream>
#include <SDL.h>

#include "vendor/generator.hpp"

uint64_t _time; // in nanoseconds ?

#define $start       $emit(std::nullptr_t) uint64_t _usleep_start
#define $usleep(us)  _usleep_start = _time; while (_time < _usleep_start + us * 1000) $yield(nullptr)

$generator(PS2Device) {
private:
public:
    PS2Device() {

    };

    $start;
        if (send) {
            // pull data line low
            $usleep(200);
        }
    $stop;

    bool operator()() { std::nullptr_t n; return this->operator()(n); }

    void enqueue(char code) {
        
    }
};

// FIXME: PS2Mouse

void main_sdl_boilerplate() {
    const int H_RES = 640;
    const int V_RES = 480;
    SDL_Window *sdl_window;
    SDL_Renderer *sdl_renderer;
    assert(SDL_Init(SDL_INIT_VIDEO) >= 0);
    assert(sdl_window = SDL_CreateWindow("Square", SDL_WINDOWPOS_CENTERED,
                                         SDL_WINDOWPOS_CENTERED, H_RES, V_RES, SDL_WINDOW_SHOWN));
    assert(sdl_renderer = SDL_CreateRenderer(sdl_window, -1,
                                             SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC));
    assert(SDL_CreateTexture(sdl_renderer, SDL_PIXELFORMAT_RGBA8888,
                             SDL_TEXTUREACCESS_TARGET, H_RES, V_RES));
}

int main(int argc, char* argv[]) {
    std::cout << "hello!" << std::endl;
        
    Verilated::commandArgs(argc, argv);

    main_sdl_boilerplate();

    PS2Device kbd;

    Vtop* top = new Vtop;
    top->rst = 1;
    top->clk = 0;
    top->eval();
    top->rst = 0;
    top->eval();

    while (1) {
        top->clk = 1;

        kbd();
        top->eval();

        top->clk = 0;
        top->eval();


        SDL_Event e;
        if (SDL_PollEvent(&e)) {
            
        }
    }
}

