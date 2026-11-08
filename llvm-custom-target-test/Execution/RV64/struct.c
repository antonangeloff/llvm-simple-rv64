struct Point { int x; int y; };

struct Point make_point(int x, int y) {
  struct Point p;
  p.x = x;
  p.y = y;
  return p;
}

int sum_point(struct Point p) {
  return p.x + p.y;
}

int main(void) {
  struct Point p = make_point(3, 4);
  return sum_point(p) - 7;
}
