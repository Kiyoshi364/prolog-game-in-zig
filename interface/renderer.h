#include <stdint.h>

typedef struct Color {
    uint8_t r;
    uint8_t g;
    uint8_t b;
    uint8_t a;
} Color;

typedef struct Renderer {
    void (*clear_background)(void *ctx, Color color);

    void (*set_clip)(void *ctx, int32_t x, int32_t y, int32_t w, int32_t h);
    void (*reset_clip)(void *ctx);

    void (*draw_rect)(void *ctx, int32_t x, int32_t y, int32_t w, int32_t h, Color color);
    void (*draw_circ)(void *ctx, int32_t x, int32_t y, float r, Color color);
    void (*draw_line)(void *ctx, int32_t x0, int32_t y0, int32_t x1, int32_t y1, Color color);
} Renderer;
