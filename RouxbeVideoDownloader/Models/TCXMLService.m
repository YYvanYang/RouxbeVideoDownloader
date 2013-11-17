//
//  TCXMLService.m
//  RouxbeVideoDownloader
//
//  Created by Lee Tze Cheun on 11/12/13.
//  Copyright (c) 2013 Lee Tze Cheun. All rights reserved.
//

#import "TCXMLService.h"

@implementation TCXMLService

+ (void)requestXMLDataWithURL:(NSURL *)aURL
                   completion:(TCXMLServiceBlock)completion
{
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];

    // We want the response back as raw NSData, so we set it to AFHTTPResponseSerializer.
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];

    [manager GET:[aURL absoluteString] parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        completion(responseObject, nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        completion(nil, error);
    }];
}

@end
