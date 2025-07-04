
int sum(int p1, int p2) { return p1 + p2; }

int foo(int p1, int p2, int p3, int p4, int p5, int p6, int p7, int p8) {
  return p1 + p8;
}

int main(void) {
  int a = 1;
  int b = 2;
  int c = 3;
  int x = sum(a, b);

  int y = foo(1, 2, 3, 4, 5, 6, 7, 8);
  return x + y;
}