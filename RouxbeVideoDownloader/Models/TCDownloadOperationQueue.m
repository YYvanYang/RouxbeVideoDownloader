//
//  TCDownloadOperationQueue.m
//  RouxbeVideoDownloader
//
//  Created by Lee Tze Cheun on 12/5/13.
//  Copyright (c) 2013 Lee Tze Cheun. All rights reserved.
//

#import "TCDownloadOperationQueue.h"
#import "TCDownloadOperation.h"

static void * TCDownloadOperationStateChangedContext = &TCDownloadOperationStateChangedContext;

static NSString * const TCDownloadOperationReadyKeyPath = @"isReady";
static NSString * const TCDownloadOperationExecutingKeyPath = @"isExecuting";
static NSString * const TCDownloadOperationFinishedKeyPath = @"isFinished";
static NSString * const TCDownloadOperationPausedKeyPath = @"isPaused";
static NSString * const TCDownloadOperationCancelledKeyPath = @"isCancelled";

@interface TCDownloadOperationQueue ()

@property (readwrite, nonatomic, strong) NSMutableOrderedSet *allOperations;
@property (readwrite, nonatomic, strong) NSMutableOrderedSet *runningOperations;
@property (readwrite, nonatomic, strong) NSMutableOrderedSet *waitingOperations;

@end

@implementation TCDownloadOperationQueue

- (id)initWithMaxConcurrentDownloadCount:(NSUInteger)maxConcurrentDownloadCount
{
    self = [super init];
    if (self) {
        _maxConcurrentDownloadCount = maxConcurrentDownloadCount;

        //TODO: Init the operation lists.
    }
    return self;
}

- (NSUInteger)downloadOperationCount
{
    return self.allOperations.count;
}

- (TCDownloadOperation *)downloadOperationAtIndex:(NSUInteger)index
{
    return (TCDownloadOperation *)self.allOperations[index];
}

- (void)addDownloadOperations:(NSArray *)operations
{
    for (TCDownloadOperation *operation in operations) {
        [self addDownloadOperation:operation];
    }
}

- (void)addDownloadOperation:(TCDownloadOperation *)downloadOperation
{
    NSParameterAssert(downloadOperation);
    NSAssert(downloadOperation.isReady,
             @"Should only add a download operation that is in Ready state.");
    NSAssert(NSNotFound == [self.allOperations indexOfObject:downloadOperation],
             @"Download operation has already been added to the queue.");

    [self.allOperations addObject:downloadOperation];
    [self registerAsObserverForDownloadOperation:downloadOperation];
    [self startOrSuspendDownloadOperation:downloadOperation];
}

#pragma mark - Controlling Download Operation State

- (void)pauseDownloadOperationAtIndex:(NSUInteger)index
{
    TCDownloadOperation *downloadOperation = self.allOperations[index];

    NSAssert(downloadOperation.isReady || downloadOperation.isExecuting,
             @"Should only be called when download operation is in Ready or Executing state.");

    if (downloadOperation.isReady || downloadOperation.isExecuting) {
        // Get the operation's executing state before it is paused.
        BOOL downloadOperationWasRunning = downloadOperation.isExecuting;

        // Pause download operation and add to waiting list.
        [downloadOperation pause];
        [self.waitingOperations addObject:downloadOperation];

        // Remove download operation from running list, if it was running
        // before it was paused.
        if (downloadOperationWasRunning) {
            [self.runningOperations removeObject:downloadOperation];
        }

        // Attempt to start the next available operation in the waiting list.
        [self startNextWaitingDownloadOperation];
    }
}

- (void)resumeDownloadOperationAtIndex:(NSUInteger)index
{
    TCDownloadOperation *downloadOperation = self.allOperations[index];

    NSAssert(downloadOperation.isPaused,
             @"Should only be called when download operation is in Paused state.");

    // If download operation has previously been paused and there is an
    // available slot for it to run, we will resume the download operation.
    if (downloadOperation.isPaused &&
        self.runningOperations.count <= self.maxConcurrentDownloadCount) {
        [downloadOperation resume];

        // Transfer from waiting list to running list.
        [self.runningOperations addObject:downloadOperation];
        [self.waitingOperations removeObject:downloadOperation];
    }
}

- (void)retryFailedDownloadOperationAtIndex:(NSUInteger)index
{
    TCDownloadOperation *operation = self.allOperations[index];

    NSAssert(operation.isFinished && operation.error,
             @"Should only be called when download operation has failed.");

    if (operation.isFinished && operation.error) {
        // Make a copy of the failed operation so that its state is Ready.
        // The original failed operation's state is Finished and we can't do anything with it.
        TCDownloadOperation *operationCopy = [operation copy];

        // Replace the failed operation with the new copy.
        [self.allOperations replaceObjectAtIndex:index
                                         withObject:operationCopy];

        // Attempt to start the new copy of the operation.
        [self startOrSuspendDownloadOperation:operationCopy];
    }
}

/**
 * Starts the given download operation if there is an available slot.
 * Otherwise, it adds the download operation to the waiting list. The
 * download operation will be scheduled to run when there is an available slot.
 */
- (void)startOrSuspendDownloadOperation:(TCDownloadOperation *)downloadOperation
{
    NSAssert(downloadOperation.isReady || downloadOperation.isPaused,
             @"Should only be called when download operation in Ready or Paused state.");

    if (downloadOperation.isReady || downloadOperation.isPaused) {
        if (self.runningOperations.count <= self.maxConcurrentDownloadCount) {
            // Start/Resume the download operation, since we have an available slot.
            if (downloadOperation.isReady) {
                [downloadOperation start];
            } else if (downloadOperation.isPaused) {
                [downloadOperation resume];
            }

            // Transfer operation from waiting list to running list.
            [self.runningOperations addObject:downloadOperation];
            [self.waitingOperations removeObject:downloadOperation];
        } else {
            // Reached the download operation limit.
            // Add the download operation to the waiting list.
            [self.waitingOperations addObject:downloadOperation];
        }
    }
}

/**
 * Attempt to start the next available download operation in the waiting list.
 * If there are no operations in the waiting list, this method does nothing.
 */
- (void)startNextWaitingDownloadOperation
{
    if (self.waitingOperations.count > 0) {
        [self startOrSuspendDownloadOperation:self.waitingOperations.firstObject];
    }
}

#pragma mark - Key-Value Observing (KVO)

+ (NSArray *)allObservableDownloadOperationKeyPaths
{
    static NSArray *allKeyPaths = nil;
    if (!allKeyPaths) {
        allKeyPaths = @[TCDownloadOperationReadyKeyPath,
                        TCDownloadOperationExecutingKeyPath,
                        TCDownloadOperationFinishedKeyPath,
                        TCDownloadOperationPausedKeyPath,
                        TCDownloadOperationCancelledKeyPath];
    }
    return allKeyPaths;
}

- (void)registerAsObserverForDownloadOperation:(TCDownloadOperation *)downloadOperation
{
    NSArray *keyPaths = [[self class] allObservableDownloadOperationKeyPaths];
    for (NSString *keyPath in keyPaths) {
        [downloadOperation addObserver:self
                            forKeyPath:keyPath
                               options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
                               context:TCDownloadOperationStateChangedContext];
    }
}

- (void)unregisterAsObserverForDownloadOperation:(TCDownloadOperation *)downloadOperation
{
    NSArray *keyPaths = [[self class] allObservableDownloadOperationKeyPaths];
    for (NSString *keyPath in keyPaths) {
        [downloadOperation removeObserver:self
                               forKeyPath:keyPath
                                  context:TCDownloadOperationStateChangedContext];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == TCDownloadOperationStateChangedContext) {
        TCDownloadOperation *downloadOperation = (TCDownloadOperation *)object;

        if (downloadOperation.isFinished) {
            if (downloadOperation.error) {
                // Download operation has been cancelled or failed.
                // Do not remove from the operation queue because we want to
                // retry the failed operation again later.
                [self.runningOperations removeObject:downloadOperation];
                [self.waitingOperations addObject:downloadOperation];
            } else {
                // Download operation has finished successfully.
                // Start the next download operation in the waiting list.
                [self.runningOperations removeObject:downloadOperation];
                [self startNextWaitingDownloadOperation];
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
