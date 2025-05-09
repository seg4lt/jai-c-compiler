#ifdef SUPPRESS_WARNINGS
#ifndef __clang__
#pragma GCC diagnostic ignored "-Wswitch-unreachable"
#endif
#endif

int main(void) {
    int a = 3;
    int b = 0;
    switch(1) if (1) case 1: return 10;
}