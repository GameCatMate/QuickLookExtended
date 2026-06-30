#import <Foundation/Foundation.h>

@interface QLDemoMetric : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic) double value;
- (instancetype)initWithName:(NSString *)name value:(double)value;
@end

@implementation QLDemoMetric
- (instancetype)initWithName:(NSString *)name value:(double)value {
    self = [super init];
    if (self) {
        _name = [name copy];
        _value = value;
    }
    return self;
}
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSArray *metrics = @[
            [[QLDemoMetric alloc] initWithName:@"latency.p95" value:184.2],
            [[QLDemoMetric alloc] initWithName:@"errors" value:2.0]
        ];
        for (QLDemoMetric *metric in metrics) {
            NSLog(@"%@ %.2f", metric.name, metric.value);
        }
    }
    return 0;
}
