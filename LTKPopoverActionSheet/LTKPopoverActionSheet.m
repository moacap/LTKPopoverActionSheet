//
//  LTKPopoverActionSheet.m
//  LTKPopoverActionSheet
//
//  Created by Adam Schlag on 9/30/12.
//  Copyright (c) 2012 Logical Thought. All rights reserved.
//

#import "LTKPopoverActionSheet.h"
#import <UIKit/UIPopoverBackgroundView.h>
#import <QuartzCore/QuartzCore.h>

@interface LTKPopoverActionSheetPopoverDelegate : NSObject <UIPopoverControllerDelegate>

@property (nonatomic, weak) LTKPopoverActionSheet *popoverActionSheet;
@property (nonatomic) NSInteger activeButtonIndex;

@end

@interface LTKPopoverActionSheetContentController : UIViewController

- (void) addActionSheet:(LTKPopoverActionSheet *)actionSheet;

@end

@interface LTKPopoverActionSheet ()

@property (nonatomic, strong) NSMutableArray* buttonArray;
@property (nonatomic, strong) NSMutableArray* blockArray;
@property (nonatomic, strong) UIPopoverController* popoverController;
@property (nonatomic, strong) LTKPopoverActionSheetPopoverDelegate* popoverDelegate;
@property (nonatomic, getter = isDismissing) BOOL dismissing;

- (void) buttonPressed:(id)sender;
- (void) buttonHighlighted:(id)sender;
- (void) buttonReleased:(id)sender;
- (CGSize) sizeForContent;
- (NSInteger) addDestructiveButtonWithTitle:(NSString *)title;

@end

@implementation LTKPopoverActionSheet

- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self)
    {
        _destructiveButtonIndex = -1;
    }
    
    return self;
}

- (id) initWithTitle:(NSString *)title delegate:(id<LTKPopoverActionSheetDelegate>)delegate destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ...
{
    self = [self initWithFrame:CGRectMake(0.0f, 0.0f, 272.0f, 480.0f)];
    
    if (self)
    {
        self.title = title;
        self.delegate = delegate;
        _destructiveButtonIndex = -1;
        
        if (nil != destructiveButtonTitle)
        {
            _destructiveButtonIndex = [self addDestructiveButtonWithTitle:destructiveButtonTitle];
        }
        
        va_list args;
        va_start(args, otherButtonTitles);
        for (NSString *arg = otherButtonTitles; arg != nil; arg = va_arg(args, NSString *))
        {
            [self addButtonWithTitle:arg];
        }
        va_end(args);
    }
    
    return self;
}

- (void) layoutSubviews
{
    // remove any currently added subviews
    for (UIView *subview in self.subviews)
    {
        [subview removeFromSuperview];
    }
    
    // set up the view
    self.backgroundColor = [UIColor clearColor]; // TODO this should be customizable
    CGFloat viewHeight   = (44.0f * self.buttonArray.count) + (8.0f * (self.buttonArray.count - 1));
    self.frame           = CGRectMake(0.0f, 0.0f, 272.0f, viewHeight);
    
    CGFloat currentY = 0.0f;
    
    // if set, add the title label
    if (nil != self.title)
    {
        currentY = currentY + 7.0f;
        
        CGSize maximumSize  = CGSizeMake(272.0f, 13.0f * 10.0f);
        CGSize stringSize   = [self.title sizeWithFont:[UIFont systemFontOfSize:13.0f] constrainedToSize:maximumSize lineBreakMode:UILineBreakModeWordWrap];
        
        // TODO this should be customizable
        UILabel *titleLabel        = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, currentY, 272.0f, stringSize.height)];
        titleLabel.font            = [UIFont systemFontOfSize:13.0f];
        titleLabel.numberOfLines   = 0;
        titleLabel.text            = self.title;
        titleLabel.textAlignment   = UITextAlignmentCenter;
        titleLabel.textColor       = [UIColor whiteColor];
        titleLabel.backgroundColor = [UIColor clearColor];
        
        // add in height for the label
        CGRect viewFrame      = self.frame;
        viewFrame.size.height = 7.0f + titleLabel.frame.size.height + 12.0f + viewFrame.size.height;
        self.frame            = viewFrame;
        
        [self addSubview:titleLabel];
        currentY = currentY + titleLabel.frame.size.height + 12.0f;
    }
    
    NSUInteger buttonIndex = 0;
    
    for (UIButton *button in self.buttonArray)
    {
        CGRect buttonFrame = button.frame;
        buttonFrame.origin = CGPointMake(0.0f, currentY);
        button.frame       = buttonFrame;
        button.tag         = buttonIndex;
        buttonIndex        = buttonIndex + 1;
        
        [self addSubview:button];
        currentY = currentY + button.frame.size.height + 8.0f;
    }
}

#pragma mark - UIActionSheet compatibility API

- (NSInteger) addButtonWithTitle:(NSString *)title
{
    UIButton *newButton = [UIButton buttonWithType:UIButtonTypeCustom];
    newButton.frame = CGRectMake(0.0f, 0.0f, 272.0f, 44.0f);
    newButton.layer.borderColor = [[UIColor blackColor] CGColor];
    newButton.layer.borderWidth = 0.5f;
    newButton.layer.cornerRadius = 6.0f;
    newButton.titleLabel.font = [UIFont boldSystemFontOfSize:19.0f];
    [newButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [newButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
    newButton.backgroundColor = [UIColor whiteColor];
    [newButton setTitle:title forState:UIControlStateNormal];
    [newButton addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [newButton addTarget:self action:@selector(buttonHighlighted:) forControlEvents:UIControlEventTouchDown];
    [newButton addTarget:self action:@selector(buttonReleased:) forControlEvents:UIControlEventTouchDragExit];
    
    [self.buttonArray addObject:newButton];
    
    // invalidate the popover so it will redraw
    self.popoverController = nil;
    
    return [self.buttonArray indexOfObject:newButton];
}

- (NSString *) buttonTitleAtIndex:(NSInteger)buttonIndex
{
    if (self.buttonArray.count > buttonIndex)
    {
        UIButton *button = (UIButton *)[self.buttonArray objectAtIndex:buttonIndex];
        
        return [button titleForState:UIControlStateNormal];
    }
    
    return nil;
}

- (void) dismissWithClickedButtonIndex:(NSInteger)buttonIndex animated:(BOOL)animated
{
    if ([self isDismissing])
    {
        return;
    }
    
    self.dismissing = YES;
    self.popoverDelegate.activeButtonIndex = buttonIndex;
    
    if (buttonIndex >= 0)
    {
        id block = [self.blockArray objectAtIndex:buttonIndex];
        
        if (![block isEqual:[NSNull null]])
        {
            ((void (^)())block)();
        }
    }
    
    BOOL hasDelegate = nil != self.delegate;
    
    if (hasDelegate && [self.delegate respondsToSelector:@selector(actionSheet:clickedButtonAtIndex:)])
    {
        [self.delegate actionSheet:self clickedButtonAtIndex:buttonIndex];
    }
    
    if (hasDelegate && [self.delegate respondsToSelector:@selector(actionSheet:willDismissWithButtonIndex:)])
    {
        [self.delegate actionSheet:self willDismissWithButtonIndex:buttonIndex];
    }
    
    [self.popoverController dismissPopoverAnimated:animated];
    
    if (hasDelegate && [self.delegate respondsToSelector:@selector(actionSheet:didDismissWithButtonIndex:)])
    {
        [self.delegate actionSheet:self didDismissWithButtonIndex:buttonIndex];
    }
    
    self.dismissing = NO;
}

- (void) showFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated
{
    if ([self.popoverController isPopoverVisible])
    {
        return;
    }
    
    [self setNeedsDisplay];
    [self.popoverController setPopoverContentSize:[self sizeForContent]];
    
    if (nil != self.delegate && [self.delegate respondsToSelector:@selector(willPresentActionSheet:)])
    {
        [self.delegate willPresentActionSheet:self];
    }
    
    [self.popoverController presentPopoverFromBarButtonItem:item permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

- (void) showFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated
{
    if ([self.popoverController isPopoverVisible])
    {
        return;
    }
    
    [self setNeedsDisplay];
    [self.popoverController setPopoverContentSize:[self sizeForContent]];
    [self.popoverController presentPopoverFromRect:rect inView:view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

#pragma mark - custom convenience API

- (id) initWithTitle:(NSString *)title
{
    self = [self initWithFrame:CGRectMake(0.0f, 0.0f, 272.0f, 480.0f)];
    
    if (self)
    {
        self.title              = title;
        _destructiveButtonIndex = -1;
    }
    
    return self;
}

- (id) init
{
    return [self initWithTitle:nil];
}

- (NSInteger) addButtonWithTitle:(NSString *)title block:(LTKPopoverActionSheetBlock)block
{
    NSInteger buttonIndex = [self addButtonWithTitle:title];
    
    if (buttonIndex >= 0 && nil != block)
    {
        [self.blockArray addObject:[block copy]];
    }
    else
    {
        [self.blockArray addObject:[NSNull null]];
    }
    
    return buttonIndex;
}

- (NSInteger) addDestructiveButtonWithTitle:(NSString *)title block:(LTKPopoverActionSheetBlock)block
{
    NSInteger buttonIndex = [self addDestructiveButtonWithTitle:title];
    
    if (buttonIndex >= 0 && nil != block)
    {
        [self.blockArray addObject:[block copy]];
    }
    else
    {
        [self.blockArray addObject:[NSNull null]];
    }
    
    return buttonIndex;
}

- (void) dismissPopoverAnimated:(BOOL)animated
{
    return [self dismissWithClickedButtonIndex:-1 animated:animated];
}

#pragma mark - custom getters/setters

- (void) setDestructiveButtonIndex:(NSInteger)destructiveButtonIndex
{
    // if the input index is less than 0, just ignore and return
    // NOTE: internal methods looking to set the value should directly set
    // the _destructiveButtonIndex variable
    if (destructiveButtonIndex < 0)
    {
        return;
    }
    
    // if there is no destructive button then just return
    if (-1 == self.destructiveButtonIndex)
    {
        return;
    }
    // if there is only one button then just return
    else if (1 == self.buttonArray.count)
    {
        return;
    }
    else
    {
        UIButton *destructiveButton = [self.buttonArray objectAtIndex:self.destructiveButtonIndex];
        self.destructiveButtonIndex = destructiveButtonIndex;
        [self.buttonArray insertObject:destructiveButton atIndex:destructiveButtonIndex];
        
        // invalidate the popover so it will redraw
        self.popoverController = nil;
    }
}

- (NSInteger) firstOtherButtonIndex
{
    // The first button index will only ever be -1, 0, or 1:
    //  • it will be -1 if there is no regular button
    //  • it will be 0 if there is at least one button and the destructive button index is not 0
    //  • it will be 1 if there is more than one button and the destructive button index is 0
    NSInteger buttonIndex = -1;
    
    if (0 != self.destructiveButtonIndex && self.buttonArray.count > 0)
    {
        buttonIndex = 0;
    }
    else if (0 == self.destructiveButtonIndex && self.buttonArray.count > 1)
    {
        buttonIndex = 1;
    }
    
    return buttonIndex;
}

- (NSInteger) numberOfButtons
{
    return self.buttonArray.count;
}

- (BOOL) isVisible
{
    return [self.popoverController isPopoverVisible];
}

- (UIPopoverController *) popoverController
{
    if (nil == _popoverController)
    {
        LTKPopoverActionSheetContentController *contentController = [[LTKPopoverActionSheetContentController alloc] init];
        [contentController addActionSheet:self];
        
        _popoverController = [[UIPopoverController alloc] initWithContentViewController:contentController];
        _popoverController.delegate = self.popoverDelegate;
        //_popoverController.popoverBackgroundViewClass = [LTKPopoverBackgroundView class];
    }
    
    return _popoverController;
}

- (LTKPopoverActionSheetPopoverDelegate *) popoverDelegate
{
    if (nil == _popoverDelegate)
    {
        _popoverDelegate = [[LTKPopoverActionSheetPopoverDelegate alloc] init];
        _popoverDelegate.popoverActionSheet = self;
        _popoverDelegate.activeButtonIndex  = -1;
    }
    
    return _popoverDelegate;
}

- (NSMutableArray *) buttonArray
{
    if (nil == _buttonArray)
    {
        _buttonArray = [[NSArray array] mutableCopy];
    }
    
    return _buttonArray;
}

- (NSMutableArray *) blockArray
{
    if (nil == _blockArray)
    {
        _blockArray = [[NSArray array] mutableCopy];
    }
    
    return _blockArray;
}

#pragma mark - private methods

- (void) buttonPressed:(id)sender
{
    if ([sender isKindOfClass:[UIButton class]])
    {
        UIButton  *button      = (UIButton *)sender;
        NSInteger  buttonIndex = button.tag;
        
        if (nil == button.currentBackgroundImage)
        {
            // set custom color
            if ([UIColor blueColor] == button.backgroundColor)
            {
                button.backgroundColor = [UIColor whiteColor];
            }
            else
            {
                button.backgroundColor = [UIColor redColor];
            }
        }
        
        [self dismissWithClickedButtonIndex:buttonIndex animated:YES];
    }
}

- (void) buttonHighlighted:(id)sender
{
    if ([sender isKindOfClass:[UIButton class]])
    {
        UIButton *button = (UIButton *)sender;
        
        if (nil == button.currentBackgroundImage)
        {
            // set custom color
            if ([UIColor whiteColor] == button.backgroundColor)
            {
                button.backgroundColor = [UIColor blueColor];
            }
            else
            {
                button.backgroundColor = [UIColor colorWithRed:0.61f green:0.0f blue:0.0f alpha:1.0f];
            }
        }
    }
}

- (void) buttonReleased:(id)sender
{
    if ([sender isKindOfClass:[UIButton class]])
    {
        UIButton  *button      = (UIButton *)sender;
        
        if (nil == button.currentBackgroundImage)
        {
            // set custom color
            if ([UIColor blueColor] == button.backgroundColor)
            {
                button.backgroundColor = [UIColor whiteColor];
            }
            else
            {
                button.backgroundColor = [UIColor redColor];
            }
        }
    }
}

- (CGSize) sizeForContent
{
    CGFloat viewHeight = (44.0f * self.buttonArray.count) + (8.0f * (self.buttonArray.count - 1));
    
    if (nil != self.title)
    {
        CGSize maximumSize  = CGSizeMake(272.0f, 13.0f * 10.0f);
        CGSize stringSize   = [self.title sizeWithFont:[UIFont systemFontOfSize:13.0f] constrainedToSize:maximumSize lineBreakMode:UILineBreakModeWordWrap];
        
        // add in height for the label
        viewHeight = 7.0f + stringSize.height + 12.0f + viewHeight;
    }
    
    return CGSizeMake(272.0f, viewHeight);
}

- (NSInteger) addDestructiveButtonWithTitle:(NSString *)title
{
    UIButton *destructiveButton = [UIButton buttonWithType:UIButtonTypeCustom];
    destructiveButton.layer.borderColor = [[UIColor blackColor] CGColor];
    destructiveButton.layer.borderWidth = 0.5f;
    destructiveButton.layer.cornerRadius = 6.0f;
    destructiveButton.frame = CGRectMake(0.0f, 0.0f, 272.0f, 44.0f);
    destructiveButton.titleLabel.font = [UIFont boldSystemFontOfSize:19.0f];
    [destructiveButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [destructiveButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
    destructiveButton.backgroundColor = [UIColor redColor];
    [destructiveButton setTitle:title forState:UIControlStateNormal];
    [destructiveButton addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [destructiveButton addTarget:self action:@selector(buttonHighlighted:) forControlEvents:UIControlEventTouchDown];
    [destructiveButton addTarget:self action:@selector(buttonReleased:) forControlEvents:UIControlEventTouchDragExit];
    
    [self.buttonArray addObject:destructiveButton];
    
    // invalidate the popover so it will redraw
    self.popoverController = nil;
    
    return [self.buttonArray indexOfObject:destructiveButton];
}

@end

@implementation LTKPopoverActionSheetPopoverDelegate

- (void) popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    if (nil != self.popoverActionSheet && nil != self.popoverActionSheet.delegate &&
        [self.popoverActionSheet.delegate respondsToSelector:@selector(actionSheet:didDismissWithButtonIndex:)])
    {
        [self.popoverActionSheet.delegate actionSheet:self.popoverActionSheet didDismissWithButtonIndex:self.activeButtonIndex];
        
        self.popoverActionSheet = nil;
        self.activeButtonIndex  = -1;
    }
}

- (BOOL) popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController
{
    return YES;
}

@end

@implementation LTKPopoverActionSheetContentController

- (void) viewWillAppear:(BOOL)animated
{
    // This will remove the inner shadow from the popover
    if ([NSStringFromClass([self.view.superview class]) isEqualToString:@"UILayoutContainerView"])
    {
        self.view.superview.layer.cornerRadius = 0;
        
        for (UIView *subview in self.view.superview.subviews)
        {
            if ([NSStringFromClass([subview class]) isEqualToString:@"UIImageView"] )
            {
                [subview removeFromSuperview];
            }
        }
    }
}

- (void) addActionSheet:(LTKPopoverActionSheet *)actionSheet
{
    // remove any currently added subviews
    for (UIView *subview in self.view.subviews)
    {
        [subview removeFromSuperview];
    }
    
    CGRect viewFrame = self.view.frame;
    viewFrame.size   = actionSheet.frame.size;
    self.view.frame  = viewFrame;
    
    CGRect actionSheetFrame = actionSheet.frame;
    actionSheetFrame.origin = CGPointZero;
    actionSheet.frame       = actionSheetFrame;
    
    [self.view addSubview:actionSheet];
}

@end