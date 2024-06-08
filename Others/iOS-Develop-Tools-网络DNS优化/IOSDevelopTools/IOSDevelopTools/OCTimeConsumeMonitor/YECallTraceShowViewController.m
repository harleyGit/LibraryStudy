//
//  YECallTraceShowViewController.m
//  IOSDevelopTools
//
//  Created by 叶煌斌 on 2020/3/11.
//  Copyright © 2020 SimonYe. All rights reserved.
//


#import "YECallTraceShowViewController.h"
#import "YECallTraceCore.h"
#import "YECallRecordCell.h"
#import "YECallRecordModel.h"
#import "YECallRecordLevelModel.h"
#import <objc/runtime.h>
#import "YECallMonitor.h"

typedef NS_ENUM(NSInteger, TPTableType) {
    tableTypeSequential,
    tableTypecostTime,
    tableTypeCallCount,
};

static CGFloat TPScrollWidth = 600;
static CGFloat TPHeaderHight = 100;

@interface YECallTraceShowViewController () <UITableViewDataSource, YECallRecordCellDelegate>

@property (nonatomic, strong)UIButton *RecordBtn;
@property (nonatomic, strong)UIButton *costTimeSortBtn;
@property (nonatomic, strong)UIButton *callCountSortBtn;
@property (nonatomic, strong)UIButton *clearBtn;
@property (nonatomic, strong)UIButton *popVCBtn;
@property (nonatomic, strong)UITableView *tpTableView;
@property (nonatomic, strong)UILabel *tableHeaderViewLabel;
@property (nonatomic, strong)UIScrollView *tpScrollView;
@property (nonatomic, copy)NSArray *sequentialMethodRecord;
@property (nonatomic, copy)NSArray *costTimeSortMethodRecord;
@property (nonatomic, copy)NSArray *callCountSortMethodRecord;
@property (nonatomic, assign)TPTableType tpTableType;

@end

@implementation YECallTraceShowViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _sequentialMethodRecord = [NSArray array];
    _tpTableType = tableTypeSequential;
    self.view.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.RecordBtn];
    [self.view addSubview:self.costTimeSortBtn];
    [self.view addSubview:self.callCountSortBtn];
    [self.view addSubview:self.clearBtn];
    [self.view addSubview:self.popVCBtn];
    [self.view addSubview:self.tpScrollView];
    [self.tpScrollView addSubview:self.tableHeaderViewLabel];
    [self.tpScrollView addSubview:self.tpTableView];
    // Do any additional setup after loading the view.
    [self stopAndGetCallRecord];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    startMonitor();
}

- (NSUInteger)findStartDepthIndex:(NSUInteger)start arr:(NSArray *)arr
{
    NSUInteger index = start;
    if (arr.count > index) {
        YECallRecordModel *model = arr[index];
        int minDepth = model.depth;
        int minTotal = model.total;
        for (NSUInteger i = index+1; i < arr.count; i++) {
            YECallRecordModel *tmp = arr[i];
            if (tmp.depth < minDepth || (tmp.depth == minDepth && tmp.total < minTotal)) {
                minDepth = tmp.depth;
                minTotal = tmp.total;
                index = i;
            }
        }
    }
    return index;
}

- (NSArray *)recursive_getRecord:(NSMutableArray *)arr
{
    if ([arr isKindOfClass:NSArray.class] && arr.count > 0) {
        BOOL isValid = YES;
        NSMutableArray *recordArr = [NSMutableArray array];
        NSMutableArray *splitArr = [NSMutableArray array];
        NSUInteger index = [self findStartDepthIndex:0 arr:arr];
        if (index > 0) {
            [splitArr addObject:[NSMutableArray array]];
            for (int i = 0; i < index; i++) {
                [[splitArr lastObject] addObject:arr[i]];
            }
        }
        YECallRecordModel *model = arr[index];
        [recordArr addObject:model];
        [arr removeObjectAtIndex:index];
        int startDepth = model.depth;
        int startTotal = model.total;
        for (NSUInteger i = index; i < arr.count; ) {
            model = arr[i];
            if (model.total == startTotal && model.depth-1==startDepth) {
                [recordArr addObject:model];
                [arr removeObjectAtIndex:i];
                startDepth++;
                isValid = YES;
            }
            else
            {
                if (isValid) {
                    isValid = NO;
                    [splitArr addObject:[NSMutableArray array]];
                }
                [[splitArr lastObject] addObject:model];
                i++;
            }
            
        }
        
        for (NSUInteger i = splitArr.count; i > 0; i--) {
            NSMutableArray *sArr = splitArr[i-1];
            [recordArr addObjectsFromArray:[self recursive_getRecord:sArr]];
        }
        return recordArr;
    }
    return @[];
}

- (void)setRecordDic:(NSMutableArray *)arr record:(YEThreadCallRecord *)record
{
    if ([arr isKindOfClass:NSMutableArray.class] && record) {
        int total=1;
        for (NSUInteger i = 0; i < arr.count; i++)
        {
            YECallRecordModel *model = arr[i];
            if (model.depth == record->depth) {
                total = model.total+1;
                break;
            }
        }
        
        YECallRecordModel *model = [[YECallRecordModel alloc] initWithCls:record->cls sel:record->sel time:record->time depth:record->depth total:total];
        [arr insertObject:model atIndex:0];
    }
}

- (void)stopAndGetCallRecord
{
    stopMonitor();
    NSArray *allMethodRecord = [[YECallMonitor shareInstance] getThreadCallRecord];

    dispatch_async(dispatch_get_main_queue(), ^{
        self.sequentialMethodRecord = [[NSArray alloc] initWithArray:allMethodRecord copyItems:YES];
        self.tpTableType = tableTypeSequential;
        self.RecordBtn.hidden = NO;
        [self clickRecordBtn];
    });
    [self sortCostTimeRecord:[[NSArray alloc] initWithArray:allMethodRecord copyItems:YES]];
    [self sortCallCountRecord:[[NSArray alloc] initWithArray:allMethodRecord copyItems:YES]];
    
}

- (void)debug_printMethodRecord:(NSString *)text
{
    //记录的顺序是方法完成时间
    NSLog(@"=========printMethodRecord==Start================");
    NSLog(@"%@", text);
    NSLog(@"=========printMethodRecord==End================");
}

- (NSString *)debug_getMethodCallStr:(YEThreadCallRecord *)callRecord
{
    NSMutableString *str = [[NSMutableString alloc] init];
    double ms = callRecord->time/1000.0;
    [str appendString:[NSString stringWithFormat:@"　%d　|　%lgms　|　", callRecord->depth, ms]];
    if (callRecord->depth>0) {
        [str appendString:[[NSString string] stringByPaddingToLength:callRecord->depth withString:@"　" startingAtIndex:0]];
    }
    if (class_isMetaClass(callRecord->cls))
    {
        [str appendString:@"+"];
    }
    else
    {
        [str appendString:@"-"];
    }
    [str appendString:[NSString stringWithFormat:@"[%@　　%@]", NSStringFromClass(callRecord->cls), NSStringFromSelector(callRecord->sel)]];
    return str.copy;
}

- (void)sortCostTimeRecord:(NSArray *)arr
{
    NSArray *sortArr = [arr sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        YECallRecordLevelModel *model1 = (YECallRecordLevelModel *)obj1;
        YECallRecordLevelModel *model2 = (YECallRecordLevelModel *)obj2;
        if (model1.rootMethod.costTime > model2.rootMethod.costTime) {
            return NSOrderedAscending;
        }
        return NSOrderedDescending;
    }];
    for (YECallRecordLevelModel *model in sortArr) {
        model.isExpand = NO;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        self.costTimeSortMethodRecord = sortArr;
        self.costTimeSortBtn.hidden = NO;
    });
}

- (void)arrAddRecord:(YECallRecordModel *)model arr:(NSMutableArray *)arr
{
    for (int i = 0; i < arr.count; i++) {
        YECallRecordModel *temp = arr[i];
        if ([temp isEqualRecordModel:model]) {
            temp.callCount++;
            return;
        }
    }
    model.callCount = 1;
    [arr addObject:model];
}

- (void)sortCallCountRecord:(NSArray *)arr
{
    NSMutableArray *arrM = [NSMutableArray array];
    for (YECallRecordLevelModel *model in arr) {
        [self arrAddRecord:model.rootMethod arr:arrM];
        if ([model.subMethods isKindOfClass:NSArray.class]) {
            for (YECallRecordModel *recoreModel in model.subMethods) {
                [self arrAddRecord:recoreModel arr:arrM];
            }
        }
    }
    
    NSArray *sortArr = [arrM sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        YECallRecordModel *model1 = (YECallRecordModel *)obj1;
        YECallRecordModel *model2 = (YECallRecordModel *)obj2;
        if (model1.callCount > model2.callCount) {
            return NSOrderedAscending;
        }
        return NSOrderedDescending;
    }];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.callCountSortMethodRecord = sortArr;
        self.callCountSortBtn.hidden = NO;
    });
}

- (void)clickPopVCBtn:(UIButton *)btn
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - YECallRecordCellDelegate

- (void)recordCell:(YECallRecordCell *)cell clickExpandWithSection:(NSInteger)section
{
    NSIndexSet *indexSet;
    YECallRecordLevelModel *model;
    switch (self.tpTableType) {
        case tableTypeSequential:
            model = self.sequentialMethodRecord[section];
            break;
        case tableTypecostTime:
            model = self.costTimeSortMethodRecord[section];
            break;
            
        default:
            break;
    }
    model.isExpand = !model.isExpand;
    indexSet=[[NSIndexSet alloc] initWithIndex:section];
    [self.tpTableView reloadSections:indexSet withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (self.tpTableType == tableTypeSequential) {
        return self.sequentialMethodRecord.count;
    }
    else if (self.tpTableType == tableTypecostTime)
    {
        return self.costTimeSortMethodRecord.count;
    }
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.tpTableType == tableTypeSequential) {
        YECallRecordLevelModel *model = self.sequentialMethodRecord[section];
        if (model.isExpand && [model.subMethods isKindOfClass:NSArray.class]) {
            return model.subMethods.count+1;
        }
    }
    else if (self.tpTableType == tableTypecostTime)
    {
        YECallRecordLevelModel *model = self.costTimeSortMethodRecord[section];
        if (model.isExpand && [model.subMethods isKindOfClass:NSArray.class]) {
            return model.subMethods.count+1;
        }
    }
    else
    {
        return self.callCountSortMethodRecord.count;
    }
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *YECallRecordCell_reuseIdentifier = @"YECallRecordCell_reuseIdentifier";
    YECallRecordCell *cell = [tableView dequeueReusableCellWithIdentifier:YECallRecordCell_reuseIdentifier];
    if (!cell) {
        cell = [[YECallRecordCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:YECallRecordCell_reuseIdentifier];
    }
    YECallRecordLevelModel *model;
    YECallRecordModel *recordModel;
    BOOL isShowExpandBtn;
    switch (self.tpTableType) {
        case tableTypeSequential:
            model = self.sequentialMethodRecord[indexPath.section];
            recordModel = [model getRecordModel:indexPath.row];
            isShowExpandBtn = indexPath.row == 0 && [model.subMethods isKindOfClass:NSArray.class] && model.subMethods.count > 0;
            cell.delegate = self;
            [cell bindRecordModel:recordModel isHiddenExpandBtn:!isShowExpandBtn isExpand:model.isExpand section:indexPath.section isCallCountType:NO];
            break;
        case tableTypecostTime:
            model = self.costTimeSortMethodRecord[indexPath.section];
            recordModel = [model getRecordModel:indexPath.row];
            isShowExpandBtn = indexPath.row == 0 && [model.subMethods isKindOfClass:NSArray.class] && model.subMethods.count > 0;
            cell.delegate = self;
            [cell bindRecordModel:recordModel isHiddenExpandBtn:!isShowExpandBtn isExpand:model.isExpand section:indexPath.section isCallCountType:NO];
            break;
        case tableTypeCallCount:
            recordModel = self.callCountSortMethodRecord[indexPath.row];
            [cell bindRecordModel:recordModel isHiddenExpandBtn:YES isExpand:YES section:indexPath.section isCallCountType:YES];
            break;
            
        default:
            break;
    }
    return cell;
}

#pragma mark - Btn click method

- (void)clickRecordBtn
{
    self.costTimeSortBtn.selected = NO;
    self.callCountSortBtn.selected = NO;
    if (!self.RecordBtn.selected) {
        self.RecordBtn.selected = YES;
        self.tpTableType = tableTypeSequential;
        [self.tpTableView reloadData];
    }
}

- (void)clickCostTimeSortBtn
{
    self.RecordBtn.selected = NO;
    self.callCountSortBtn.selected = NO;
    if (!self.costTimeSortBtn.selected) {
        self.costTimeSortBtn.selected = YES;
        self.tpTableType = tableTypecostTime;
        [self.tpTableView reloadData];
    }
}

- (void)clickCallCountSortBtn
{
    self.costTimeSortBtn.selected = NO;
    self.RecordBtn.selected = NO;
    if (!self.callCountSortBtn.selected) {
        self.callCountSortBtn.selected = YES;
        self.tpTableType = tableTypeCallCount;
        [self.tpTableView reloadData];
    }
}

- (void)clickClearBtn
{
    clearCallRecords();
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - get&set method

- (UIScrollView *)tpScrollView
{
    if (!_tpScrollView) {
        _tpScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, TPHeaderHight, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height-TPHeaderHight)];
        _tpScrollView.showsHorizontalScrollIndicator = YES;
        _tpScrollView.alwaysBounceHorizontal = YES;
        _tpScrollView.contentSize = CGSizeMake(TPScrollWidth, 0);
    }
    return _tpScrollView;
}

- (UITableView *)tpTableView
{
    if (!_tpTableView) {
        _tpTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 30, TPScrollWidth, [UIScreen mainScreen].bounds.size.height-TPHeaderHight-30) style:UITableViewStylePlain];
        _tpTableView.bounces = NO;
        _tpTableView.dataSource = self;
        _tpTableView.rowHeight = 18;
        _tpTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
    return _tpTableView;
}

- (UIButton *)getTPBtnWithFrame:(CGRect)rect title:(NSString *)title sel:(SEL)sel
{
    UIButton *btn = [[UIButton alloc] initWithFrame:rect];
    btn.layer.cornerRadius = 2;
    btn.layer.borderWidth = 1;
    btn.layer.borderColor = [UIColor blackColor].CGColor;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setBackgroundImage:[self imageWithColor:[UIColor colorWithRed:127/255.0 green:179/255.0 blue:219/255.0 alpha:1]] forState:UIControlStateSelected];
    btn.titleLabel.font = [UIFont systemFontOfSize:10];
    [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (UIImage *)imageWithColor:(UIColor *)color{
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    UIImage *theImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return theImage;
}

- (UIButton *)RecordBtn
{
    if (!_RecordBtn) {
        _RecordBtn = [self getTPBtnWithFrame:CGRectMake(5, 65, 60, 30) title:@"调用时间" sel:@selector(clickRecordBtn)];
        _RecordBtn.hidden = YES;
    }
    return _RecordBtn;
}

- (UIButton *)costTimeSortBtn
{
    if (!_costTimeSortBtn) {
        _costTimeSortBtn = [self getTPBtnWithFrame:CGRectMake(70, 65, 60, 30) title:@"最耗时" sel:@selector(clickCostTimeSortBtn)];
        _costTimeSortBtn.hidden = YES;
    }
    return _costTimeSortBtn;
}

- (UIButton *)callCountSortBtn
{
    if (!_callCountSortBtn) {
        _callCountSortBtn = [self getTPBtnWithFrame:CGRectMake(135, 65, 60, 30) title:@"调用次数" sel:@selector(clickCallCountSortBtn)];
        _callCountSortBtn.hidden = YES;
    }
    return _callCountSortBtn;
}

- (UIButton *)clearBtn
{
    if (!_clearBtn) {
        _clearBtn = [self getTPBtnWithFrame:CGRectMake(200, 65, 60, 30) title:@"清空记录" sel:@selector(clickClearBtn)];
        _clearBtn.hidden = NO;
    }
    return _clearBtn;
}

- (UIButton *)popVCBtn
{
    if (!_popVCBtn) {
        _popVCBtn = [self getTPBtnWithFrame:CGRectMake([UIScreen mainScreen].bounds.size.width-50, 65, 40, 30) title:@"关闭" sel:@selector(clickPopVCBtn:)];
    }
    return _popVCBtn;
}

- (UILabel *)tableHeaderViewLabel
{
    if (!_tableHeaderViewLabel) {
        _tableHeaderViewLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, TPScrollWidth, 30)];
        _tableHeaderViewLabel.font = [UIFont systemFontOfSize:15];
        _tableHeaderViewLabel.backgroundColor = [UIColor colorWithRed:219.0/255 green:219.0/255 blue:219.0/255 alpha:1];
    }
    return _tableHeaderViewLabel;
}

- (void)setTpTableType:(TPTableType)tpTableType
{
    if (_tpTableType!=tpTableType) {
        if (tpTableType==tableTypeCallCount) {
            self.tableHeaderViewLabel.text = @"深度       耗时      次数            方法名";
        }
        else
        {
            self.tableHeaderViewLabel.text = @"深度       耗时                  方法名";
        }
        _tpTableType = tpTableType;
    }
}

@end
