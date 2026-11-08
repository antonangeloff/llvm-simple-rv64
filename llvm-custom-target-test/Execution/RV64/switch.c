int classify(int x) {
  switch (x) {
    case 0: return 10;
    case 1: return 20;
    case 2: return 30;
    case 3: return 40;
    case 4: return 50;
    default: return -1;
  }
}

int main(void) {
  return classify(3) - 40;
}
