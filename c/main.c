// int main (void) {
//     int a = 100;
//     int b = 200L;
//     // int c = 300l;
//     // int d = 123123123123;
//     // long e = 1l;
//     // long f = 2L;
//     // long g = 11111111111;

//     // long g = (int) 123;
//     // long h = (long) 123;
// }
/* The result of a cast expression is not an lvalue */

int main(void) {
    int i = 0;
    i = (long) i = 10;
    return 0;
}
