/* code obtained by googling =) */
#include "err.h"

void errx(int eval, const char *fmt, ...) {
    va_list args;

    va_start(args, fmt);
    fprintf(stderr, "Fatal Error: ");
    fprintf(stderr, fmt, args);
    fprintf(stderr, "\n");
    va_end(args);
    exit(eval);
}
