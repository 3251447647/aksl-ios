#import "BroadcastFinish.h"

void AKFinishBroadcastWithoutError(RPBroadcastSampleHandler *handler) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [handler finishBroadcastWithError:nil];
#pragma clang diagnostic pop
}
