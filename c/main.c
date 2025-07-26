
int foo(int p1, int p2, int p3, int p4, int p5, int p6, int p7, int p8,
        int p9) {
  return p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8 + p9;
}

int main(void) {
  int x = 10;
  int y = x + foo(1, 2, 3, 4, 5, 6, 7, 8, 9);
  return y;
  // return foo(1, 2, 3, 4, 5, 6, 7, 8, 9);
}