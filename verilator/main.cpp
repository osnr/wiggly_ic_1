#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vwiggly_ic_1.h"

#include <iostream>
#include <queue>
#include <list>
#include <SDL.h>

#include "vendor/resumable_thing.h"

using std::cout;
using std::endl;

uint64_t _time = 0; // in nanoseconds?

class Ps2Device {
private:
    std::queue<uint8_t> codes_to_send;
    resumable_thing co;

public:
    bool clk, data;

    Ps2Device() { co = this->loop(); };
    
    #define usleep(us)  do {\
        uint64_t _usleep_start = _time;                         \
        do {                                                    \
            co_await std::suspend_always{};                          \
        } while (_time < _usleep_start + (us) * 2);                  \
      } while (0)

    resumable_thing loop() {
        while (true) {
            while (codes_to_send.empty()) { clk = 1; data = 1; usleep(0); }

            uint8_t code = codes_to_send.front(); codes_to_send.pop();
            // cout << "0x" << std::hex << unsigned(code) << std::dec << endl;

            // construct start bit, parity bit, stop bit
            bool start = 0;
            bool parity;
            bool stop = 1;

            int num_ones = 0;

            std::list<bool> bits;
            bits.push_back(start);
            for (int i = 0; i < 8; i++) { // LSB first
                bool bit = (code >> i) & 0x01;
                bits.push_back(bit);
                num_ones += bit;
            }
            parity = num_ones % 2 == 0;
            bits.push_back(parity);
            bits.push_back(stop);

            clk = 1;
            data = 1;
            usleep(50);

            int i = 0;
            for (const bool& bit : bits) {
                // cout << "bit" << i++ << " ";
                clk = 1;
                usleep(20);
                data = bit;
                usleep(20);
                clk = 0;
                usleep(20);
            }
            usleep(20);

            clk = 1;
            data = 1;
            // cout << "done" << endl;
            usleep(200);
        }
    }

    void operator()(uint8_t& out_clk, uint8_t& out_data) {
        co.resume();
        out_clk = clk; out_data = data;
    }

    void send(uint8_t code) { codes_to_send.push(code); }
};

class Vga {
public:
    // screen dimensions
    static const int H_RES = 640;
    static const int V_RES = 480;
    typedef struct Pixel {  // for SDL texture
        uint8_t a;  // transparency
        uint8_t b;  // blue
        uint8_t g;  // green
        uint8_t r;  // red
    } Pixel;

    SDL_Window*   sdl_window = NULL;
    SDL_Renderer* sdl_renderer = NULL;
    SDL_Texture*  sdl_texture  = NULL;

    Pixel screenbuffer[H_RES*V_RES];

    Vga() {
        assert(SDL_Init(SDL_INIT_VIDEO) >= 0);
        assert(sdl_window = SDL_CreateWindow("Square", SDL_WINDOWPOS_CENTERED,
                                             SDL_WINDOWPOS_CENTERED, H_RES, V_RES, SDL_WINDOW_SHOWN));
        assert(sdl_renderer = SDL_CreateRenderer(sdl_window, -1,
                                                 SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC));
        assert(sdl_texture = SDL_CreateTexture(sdl_renderer, SDL_PIXELFORMAT_RGBA8888,
                                               SDL_TEXTUREACCESS_TARGET, H_RES, V_RES));
    }

    void operator()(Vwiggly_ic_1* top) {
        // update pixel if not in blanking interval
        if (top->vga_de) {
            Pixel* p = &screenbuffer[top->vga_sy*H_RES + top->vga_sx];
            p->a = 0xFF;  // transparency
            p->b = top->vga_b << 6;
            p->g = top->vga_g << 6;
            p->r = top->vga_r << 6;
        }
        
        // update texture once per frame at start of blanking
        if (top->vga_sy == V_RES && top->vga_sx == 0) {
            SDL_UpdateTexture(sdl_texture, NULL, screenbuffer, H_RES*sizeof(Pixel));
            SDL_RenderClear(sdl_renderer);
            SDL_RenderCopy(sdl_renderer, sdl_texture, NULL, NULL);
            SDL_RenderPresent(sdl_renderer);
        }
    }
};

class Testbench {
public:
    void operator()(Ps2Device& kbd, Ps2Device& mouse) {
        // move mouse
        // wait
        // where is the mouse pointer?
    }
};

int main(int argc, char* argv[]) {
    std::cout << "hello!" << std::endl;

    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);
    VerilatedVcdC* trace = new VerilatedVcdC;

    Ps2Device kbd, mouse;
    Vga vga;

    Testbench testbench;

    Vwiggly_ic_1* top = new Vwiggly_ic_1;
    top->trace(trace, 99);
    trace->open("trace.vcd");

    top->rst = 1;
    top->clk = 0;
    top->eval();

    top->clk = 1;
    top->eval();

    top->clk = 0;
    top->eval();

    top->rst = 0;

    while (1) {
        _time++;

        testbench(kbd, mouse);

        top->clk = 1; top->vga_clk_pix = 1;
        kbd(top->kbd_clk, top->kbd_data); // input
        mouse(top->mouse_clk, top->mouse_data); // input
        top->eval();
        trace->dump((vluint64_t) (10*_time));

        top->clk = 0; top->vga_clk_pix = 0; 
        top->eval();
        trace->dump((vluint64_t) (10*_time + 5));

        // output
        vga(top);

        if (_time % 20000 == 0) {
            char title_buf[500];
            snprintf(title_buf, sizeof(title_buf), "_time=%lu, most_recent_kbd_data=0x%x", _time, top->most_recent_kbd_data);
            SDL_SetWindowTitle(vga.sdl_window, title_buf);

            SDL_Event e;
            if (SDL_PollEvent(&e)) {
                if (e.type == SDL_KEYDOWN) {
                    kbd.send(0x15); // 'q' scancode
                    cout << "down" << endl;

                } else if (e.type == SDL_KEYUP) {
                    kbd.send(0xF0); // BREAK scancode
                    kbd.send(0x15); // 'q' scancode
                    cout << "up" << endl;

                } else if (e.type == SDL_MOUSEMOTION) {
                    e.motion.yrel = -e.motion.yrel;
                    mouse.send(0b00001000 |
                               ((e.motion.xrel >> 31) << 4) |
                               ((e.motion.yrel >> 31) << 5));
                    mouse.send(e.motion.xrel & 0xFF);
                    mouse.send(e.motion.yrel & 0xFF);
                    // cout << "mouse motion" << endl;
                }
            }
            trace->flush();
        }
    }
}

