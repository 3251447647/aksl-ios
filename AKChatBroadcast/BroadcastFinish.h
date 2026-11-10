#import <Foundation/Foundation.h>
#import <ReplayKit/ReplayKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 结束广播且不弹系统错误框（ReplayKit 的 finishBroadcastWithError: 传 nil）。
void AKFinishBroadcastWithoutError(RPBroadcastSampleHandler *handler);

NS_ASSUME_NONNULL_END
