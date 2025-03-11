
int main(void) {
    int x = 2;
    int y = 3;
    switch(x) {
        case 1:
            y += 1;
            break;
        case 2:
            y += 2;
            break;
        default:
            y += 3;
            break;
    }
    return y;
}
