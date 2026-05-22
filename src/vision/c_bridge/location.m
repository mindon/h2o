#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "location.h"

@interface LocationHandler : NSObject <CLLocationManagerDelegate>
@property (strong, nonatomic) CLLocationManager *manager;
@property (strong, nonatomic) dispatch_semaphore_t sem;
@property (assign, nonatomic) CLLocationCoordinate2D coord;
@property (assign, nonatomic) BOOL success;
@end

@implementation LocationHandler
- (id)init {
    self = [super init];
    if (self) {
        self.manager = [[CLLocationManager alloc] init];
        self.manager.delegate = self;
        // 注意：实际使用时可能需要 info.plist 配置 NSLocationWhenInUseUsageDescription
        [self.manager requestWhenInUseAuthorization];
        [self.manager startUpdatingLocation];
        self.sem = dispatch_semaphore_create(0);
        self.success = NO;
    }
    return self;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    CLLocation *loc = [locations lastObject];
    self.coord = loc.coordinate;
    self.success = YES;
    dispatch_semaphore_signal(self.sem);
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    dispatch_semaphore_signal(self.sem);
}
@end

LocationResult get_current_location() {
    LocationHandler *handler = [[LocationHandler alloc] init];
    // 等待定位，最长 5 秒
    dispatch_semaphore_wait(handler.sem, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    
    LocationResult res;
    res.lat = handler.coord.latitude;
    res.lon = handler.coord.longitude;
    res.success = handler.success ? 1 : 0;
    return res;
}
