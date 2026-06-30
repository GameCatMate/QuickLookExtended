#import <Foundation/Foundation.h>
#include <map>
#include <string>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        std::map<std::string, double> metrics = {
            {"latency.p95", 184.2},
            {"errors", 2.0},
            {"workers", 6.0},
        };

        for (const auto& [name, value] : metrics) {
            NSLog(@"%s %.2f", name.c_str(), value);
        }
    }
    return 0;
}
