//
//  SecondViewController.m
//  HikeBuddy
//
//  Created by Chris Cowdery-Corvan on 7/1/16.
//  Copyright © 2016 Apple. All rights reserved.
//

#import "SecondViewController.h"

#import <CoreLocation/CoreLocation.h>
#import <MobileWiFi/MobileWiFi.h>
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
    
    _locationManager.delegate = self;
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
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
        
        [self p_locationTick];
    }
    else {
        self.name.enabled = YES;
        self.server.enabled = YES;
        
        // TODO: POST /remove_hiker/:id
    }
}

- (NSNumber*) p_wifiStrength
{
    WiFiManagerClientRef manager = WiFiManagerClientCreate(kCFAllocatorDefault, 0);
    CFArrayRef devices = WiFiManagerClientCopyDevices(manager);
    
    WiFiDeviceClientRef client = (WiFiDeviceClientRef)CFArrayGetValueAtIndex(devices, 0);
    CFDictionaryRef data = (CFDictionaryRef)WiFiDeviceClientCopyProperty(client, CFSTR("RSSI"));
    CFNumberRef scaled = (CFNumberRef)WiFiDeviceClientCopyProperty(client, kWiFiScaledRSSIKey);
    
    CFNumberRef RSSI = (CFNumberRef)CFDictionaryGetValue(data, CFSTR("RSSI_CTL_AGR"));
    
    int raw;
    CFNumberGetValue(RSSI, kCFNumberIntType, &raw);
    
    float strength;
    CFNumberGetValue(scaled, kCFNumberFloatType, &strength);
    CFRelease(scaled);
    
    strength *= -1;
    
    // Apple uses -3.0.
    int bars = (int)ceilf(strength * -3.0f);
    bars = MAX(1, MIN(bars, 3));
    
    CFRelease(data);
    CFRelease(scaled);
    CFRelease(devices);
    CFRelease(manager);
    
    return [NSNumber numberWithInt:bars];
}

#pragma mark - CLLocationManagerDelegate

- (void) locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"didFailWithError: %@", error);
    UIAlertView *errorAlert = [[UIAlertView alloc]
                               initWithTitle:@"Error" message:@"Failed to Get Your Location" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [errorAlert show];
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
        
        NSDictionary* headers = @{@"accept": @"application/json"};
        NSDictionary *parameters = @{@"name": self.name.text,
                                     @"latitude": latitude,
                                     @"longitude": longitude,
                                     @"signal_strength" : [self p_wifiStrength]};
        
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
                UIAlertView *errorAlert = [[UIAlertView alloc]
                                           initWithTitle:@"Error" message:body[@"description"] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [errorAlert show];
            }
        }
    }
}











@end
