//
//  SecondViewController.h
//  HikeBuddy
//
//  Created by Chris Cowdery-Corvan on 7/1/16.
//  Copyright © 2016 Apple. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SecondViewController : UIViewController

@property (weak, nonatomic) IBOutlet UISwitch *enable;
@property (weak, nonatomic) IBOutlet UITextField *name;
@property (weak, nonatomic) IBOutlet UITextField *server;

@end

