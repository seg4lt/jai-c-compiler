int main(void) {
    int x = 10;
    while(x-- > 0) {
        x--;
        break;

        while(x-- > 0) {
            x--;
            break;
        }
    }
    return x;
}