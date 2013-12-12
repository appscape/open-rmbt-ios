/*
 * Copyright 2013 appscape gmbh
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#import "RMBTVerticalTransitionController.h"

@implementation RMBTVerticalTransitionController


- (NSTimeInterval)transitionDuration:(id <UIViewControllerContextTransitioning>)transitionContext {
    return 0.25f;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    UIViewController* toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIViewController* fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];

    CGRect endFrame = [transitionContext initialFrameForViewController:fromViewController];

    [[transitionContext containerView] addSubview:toViewController.view];

    toViewController.view.frame = CGRectOffset(endFrame, 0, (_reverse ? 1 : -1) * toViewController.view.frame.size.height);

    [UIView animateWithDuration:[self transitionDuration:transitionContext] animations:^{
        toViewController.view.frame = endFrame;
        fromViewController.view.frame = CGRectOffset(fromViewController.view.frame, 0,(_reverse ? -1 : 1) * toViewController.view.frame.size.height);
    } completion:^(BOOL finished) {
         [transitionContext completeTransition:YES];
    }];
}
@end
