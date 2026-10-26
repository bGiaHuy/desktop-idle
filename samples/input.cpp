#include <iostream>

int main() {
    int a, b;
    std::cout << "Nhap hai so: " << std::flush;
    if (!(std::cin >> a >> b)) return 1;
    std::cout << "Tong = " << a + b << '\n';
    return 0;
}
