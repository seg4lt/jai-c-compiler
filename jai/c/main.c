int main(void) {
    int x = 1;
    do {
        x = x + 1;
        if (x == 5) {
            break;
        }
    } while(x < 10);
    return x;
}