

#include <iostream>
#include <ftd3xx.h>

int main() {
    std::cout << "Hello, world!" << std::endl;

    DWORD dwNumDevs;
    FT_CreateDeviceInfoList(&dwNumDevs);
    std::cout << "Number of FTDI devices: " << dwNumDevs << std::endl;

    return 0;
}
