extern long sys_write(long fd, const char *buf, long len);

unsigned long strlen(const char *s) {
  unsigned long n = 0;
  while (s[n]) {
    n++;
  }
  return n;
}

int puts(const char *s) {
  sys_write(1, s, strlen(s));
  sys_write(1, "\n", 1);
  return 0;
}

void *memcpy(void *dest, const void *src, unsigned long n) {
  unsigned char *d = (unsigned char *)dest;
  const unsigned char *s = (const unsigned char *)src;
  for (unsigned long i = 0; i < n; i++) {
    d[i] = s[i];
  }
  return dest;
}

void *memset(void *s, int c, unsigned long n) {
  unsigned char *p = (unsigned char *)s;
  for (unsigned long i = 0; i < n; i++) {
    p[i] = (unsigned char)c;
  }
  return s;
}

int printf(const char *fmt, ...) {
  puts("printf: not implemented");
  return 0;
}
