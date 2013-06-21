//
//  OWMissionBadgeView.h
//  OpenWatch
//
//  Created by Christopher Ballinger on 6/21/13.
//  Copyright (c) 2013 The OpenWatch Corporation, Inc. All rights reserved.
//

#import "JSBadgeView.h"

#define kMissionCountUpdateNotification @"kMissionCountUpdateNotification"

@interface OWMissionBadgeView : JSBadgeView

+ (NSString*) userInfoBadgeTextKey; // for notifications

@end
