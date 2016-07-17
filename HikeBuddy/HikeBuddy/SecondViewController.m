//
//  SecondViewController.m
//  HikeBuddy
//
//  Created by Chris Cowdery-Corvan on 7/1/16.
//  Copyright © 2016 Apple. All rights reserved.
//

#import "SecondViewController.h"

#import <CoreLocation/CoreLocation.h>
#import <NetworkExtension/NetworkExtension.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import "UNIRest.h"

static NSUInteger kServerPort = 3000;

@interface SecondViewController () <CLLocationManagerDelegate>

@end

@implementation SecondViewController
{
    NSNumber *_hikerId;
    NSTimer *_submissionTimer;
    
    CLLocationManager *_locationManager;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _hikerId = nil;
    
    _locationManager = [[CLLocationManager alloc] init];
    _backgroundTaskList = [[NSMutableSet alloc] init];
    
    _locationManager.delegate = self;
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    
    self.name.text = [[UIDevice currentDevice] name];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)didChangeEnableState:(id)sender
{
    UISwitch *enableSwitch = self.enable;
    BOOL isEnabled = enableSwitch.isOn;
    
    if (isEnabled) {
        self.name.enabled = NO;
        self.server.enabled = NO;
        
        if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
            [_locationManager requestAlwaysAuthorization];
        }
        
        [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
        
        [self p_locationTick];
    }
    else {
        self.name.enabled = YES;
        self.server.enabled = YES;
        
        // TODO: POST /remove_hiker/:id
        
        [[UIDevice currentDevice] setBatteryMonitoringEnabled:NO];
    }
}

#pragma mark - Background Task


#pragma mark - CLLocationManagerDelegate

- (void) locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"didFailWithError: %@", error);
}

- (void) p_locationTick
{
    [_locationManager requestLocation];
    
    BOOL isEnabled = self.enable.isOn;
    
    if (isEnabled) {
        [NSTimer scheduledTimerWithTimeInterval:5.0f
                                         target:self
                                       selector:@selector(p_locationTick)
                                       userInfo:nil
                                        repeats:NO];
    }
}

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    CLLocation *currentLocation = [locations lastObject];
    
    if (currentLocation != nil) {
        NSString *longitude = [NSString stringWithFormat:@"%.8f", currentLocation.coordinate.longitude];
        NSString *latitude = [NSString stringWithFormat:@"%.8f", currentLocation.coordinate.latitude];
        
        NSString *url;
        NSString *server = [NSString stringWithFormat:@"http://%@:%lu", self.server.text, (unsigned long)kServerPort];
        
        CGFloat batteryLevel = [[UIDevice currentDevice] batteryLevel];
        
        NSDictionary* headers = @{@"accept": @"application/json"};
        NSDictionary *parameters = @{@"name": self.name.text,
                                     @"latitude": latitude,
                                     @"longitude": longitude,
                                     @"batteryLevel" : @(batteryLevel)};
        if (_hikerId == nil) {
            url = [NSString stringWithFormat:@"%@/add_hiker", server];
            
            UNIHTTPJsonResponse *response = [[UNIRest post:^(UNISimpleRequest *request) {
                [request setUrl:url];
                [request setHeaders:headers];
                [request setParameters:parameters];
            }] asJson];
            
            NSDictionary *body = response.body.JSONObject;
            
            if (body[@"id"] != nil) {
                _hikerId = body[@"id"];
            }
        }
        else {
            url = [NSString stringWithFormat:@"%@/update_hiker/%@", server, _hikerId];
            
            UNIHTTPJsonResponse *response = [[UNIRest post:^(UNISimpleRequest *request) {
                [request setUrl:url];
                [request setHeaders:headers];
                [request setParameters:parameters];
            }] asJson];
            
            NSDictionary *body = response.body.JSONObject;
            
            if ([body[@"status"] isEqual:@"ok"]) {
                  // See if any messages dropped
            }
            else {
                NSLog(@"Error encountered: %@", body);
            }
        }
    }
}











@end
