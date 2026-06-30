#include <algorithm>
#include <iostream>
#include <string>
#include <vector>

struct Item {
    std::string name;
    int count;
};

int main() {
    std::vector<Item> items = {
        {"alpha", 3},
        {"beta", 7},
        {"gamma", 11},
    };

    std::sort(items.begin(), items.end(), [](const Item& lhs, const Item& rhs) {
        return lhs.count > rhs.count;
    });

    for (const auto& item : items) {
        std::cout << item.name << ": " << item.count << std::endl;
    }
}
