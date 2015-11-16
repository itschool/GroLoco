//
//  GLShoppingViewController.m
//  GrocoLoco
//
//  Created by Mark Hall on 2015-11-14.
//  Copyright © 2015 Mark Hall. All rights reserved.
//

#import "GLShoppingViewController.h"
#import "GLShoppingItemView.h"
#import "MHSegmentedControl.h"
#import "GLGroceryItem.h"
#import "GLSearchTableViewCell.h"
#import "MHProgressBar.h"

@interface GLShoppingViewController () <MHSegmentedControlDelegate>

@property (weak, nonatomic) IBOutlet UIScrollView *topScrollView;
@property (weak, nonatomic) IBOutlet UIImageView *mapView;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (strong, nonatomic) MHSegmentedControl *segmentedControl;
@property (strong, nonatomic) NSMutableDictionary *itemsInSections;
@property (strong, nonatomic) MHProgressBar *progressBar;
@property (assign, nonatomic) CGFloat currentPage;

@end

@implementation GLShoppingViewController 

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.topScrollView.contentSize = CGSizeMake(self.view.frame.size.width * [self.items count], self.topScrollView.frame.size.height);
    
    self.segmentedControl = [[MHSegmentedControl alloc] initWithFrame:CGRectMake(20, self.view.frame.size.height-40, self.view.frame.size.width-40, 30) Option:@"Map" andOption:@"List" backgroundColor:[UIColor GLlightGreen] selectedIndex:0];
    
    self.segmentedControl.delegate = self;
    [self.view addSubview:self.segmentedControl];

    [self.tableView setContentInset:UIEdgeInsetsMake(0, 0, self.view.frame.size.height - self.segmentedControl.frame.origin.y, 0)];
    [self.tableView setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, self.view.frame.size.height - self.segmentedControl.frame.origin.y, 0)];
    
    self.itemsInSections = @{}.mutableCopy;
    
    self.mapView.userInteractionEnabled = YES;
    
    CGFloat yposition = self.topScrollView.frame.origin.y + self.topScrollView.frame.size.height - 20;
    self.progressBar = [[MHProgressBar alloc] initWithFrame:CGRectMake(20, yposition - 24, self.view.frame.size.width - 40, 24) trackColor:[UIColor GLdarkGreen] barColor:[UIColor GLlightGreen]];
    self.currentPage = 0;
    [self.view addSubview:self.progressBar];
    
    [self makeItemViews];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    for (GLGroceryItem *item in self.items){
        NSLog(@"here");
        NSUInteger coordx = item.coordinates.x / 100 * self.mapView.frame.size.width - 16;
        NSUInteger coordy = item.coordinates.y / 100 * self.mapView.frame.size.height - 32;
        
        item.navPin.frame = CGRectMake(coordx, coordy, 32, 32);
        [self.mapView addSubview:item.navPin];
        [item.navPin addTarget:self action:@selector(itemSelected:) forControlEvents:UIControlEventTouchUpInside];
        item.navPin.tag = [self.items indexOfObject:item];
        
        if (self.itemsInSections[item.aisle]){
            NSMutableArray* items = self.itemsInSections[item.aisle];
            [items addObject:item];
        }
        else{
            self.itemsInSections[item.aisle] = @[item].mutableCopy;
        }
    }
    [self.tableView reloadData];
}

- (void)itemSelected:(UIButton *) sender {
    
    CGRect frame = self.topScrollView.frame;
    frame.origin.x = frame.size.width * (sender.tag);
    frame.origin.y = 0;
    [self.topScrollView scrollRectToVisible:frame animated:YES];
    
    sender.selected = !sender.selected;
}

- (IBAction)nextPressed:(id)sender
{
    [self movePage:1];
}
- (IBAction)previousPressed:(id)sender
{
    [self movePage:-1];
}

- (void)setCurrentPage:(CGFloat)currentPage
{
    if (currentPage > ([self.items count]-1)){
        return;
    }
    _currentPage = currentPage;
    self.progressBar.progress = self.currentPage / ([self.items count]-1);
}

#pragma mark -
#pragma mark UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView* _Nonnull)tableView
{
    return [[self.itemsInSections allKeys] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSArray *keys = [[self.itemsInSections allKeys] sortedArrayUsingSelector:@selector(compare:)];
    return [self.itemsInSections[keys[section]] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    GLSearchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:GL_SEARCH_TABLEVIEW_CELL forIndexPath:indexPath];

    NSArray *keys = [[self.itemsInSections allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSNumber *key = keys[indexPath.section];
    NSLog(@"%@",self.itemsInSections[key][indexPath.row]);
    cell.item = self.itemsInSections[key][indexPath.row];
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSArray *keys = [[self.itemsInSections allKeys] sortedArrayUsingSelector:@selector(compare:)];
    return [NSString stringWithFormat:@"Aisle %@", keys[section]];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    NSArray *keys = [[self.itemsInSections allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray *keyStrings = @[].mutableCopy;
    for (NSString *key in keys){
        [keyStrings addObject:key];
    }
    return keyStrings;
}


#pragma mark -
#pragma mark Helper Methods

- (void)movePage:(NSInteger)direction
{
    CGPoint currentOffset = self.topScrollView.contentOffset;
    if (direction == -1 && currentOffset.x == 0){
        return;
    }
    else if (direction == 1 && currentOffset.x == self.topScrollView.contentSize.width-self.topScrollView.frame.size.width){
        return;
    }
    [self.topScrollView setContentOffset:CGPointMake(self.view.frame.size.width * direction + currentOffset.x, 0) animated:YES];
}

- (void)makeItemViews
{
    for (NSInteger i=0; i< [self.items count]; i++){
        GLGroceryItem *item = self.items[i];
        GLShoppingItemView* itemView = [[[NSBundle mainBundle] loadNibNamed:@"GLShoppingItemView" owner:self options:nil] firstObject];
        itemView.frame = CGRectMake(self.view.frame.size.width * i, 0, self.topScrollView.frame.size.width, self.topScrollView.frame.size.height);
        itemView.item = item;
        itemView.gotItemButton.tag = i;
        [itemView.gotItemButton addTarget:self action:@selector(gotItem:) forControlEvents:UIControlEventTouchUpInside];
        [self.topScrollView addSubview:itemView];
    }
}

- (void)gotItem:(UIButton *)sender
{
    CGRect frame = self.topScrollView.frame;
    frame.origin.x = frame.size.width * (sender.tag+1);
    frame.origin.y = 0;
    [self.topScrollView scrollRectToVisible:frame animated:YES];
    
    self.currentPage += 1;
}

#pragma mark -
#pragma mark UIScrollViewDelegate

//- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
//{
//    CGFloat page = ceil(scrollView.contentOffset.x / self.topScrollView.frame.size.width);
//    self.currentPage = page;
//}

#pragma mark -
#pragma mark MHSegmentedControlDelegate

- (void)didTransitionToIndex:(NSInteger)index
{
    self.mapView.hidden = index;
    self.tableView.hidden = !index;
}


@end