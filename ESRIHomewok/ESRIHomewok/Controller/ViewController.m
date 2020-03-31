//
//  ViewController.m
//  ESRIHomewok
//
//  Created by 赵龙 on 2020/3/23.
//  Copyright © 2020 赵龙. All rights reserved.
//

#import "ViewController.h"

#import <ArcGIS/ArcGIS.h>

#import "UIImage+MultiFormat.h"

#import "EsriCell.h"

@interface ViewController () <AGSGeoViewTouchDelegate,AGSCalloutDelegate,UITableViewDelegate,UITableViewDataSource>

// mapview
@property (weak, nonatomic) IBOutlet AGSMapView *mapView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *loadIndicator;
@property (strong, nonatomic) AGSMap *map;
@property (strong, nonatomic) AGSFeatureLayer *activeFeatureLayer;

// click top button
- (IBAction)featureTableButtonClicked:(UIButton *)sender;
- (IBAction)descriptionButtonClicked:(UIButton *)sender;
- (IBAction)mapButtonClicked:(UIButton *)sender;


// feature tableview
@property (weak, nonatomic) IBOutlet UITableView *FeatureTableview;
@property (strong, nonatomic) NSMutableArray<AGSFeature*> * featureDataSource;
@property (strong, nonatomic) NSMutableDictionary<NSString *,UIImage *> * imageDataSource;

// feature description
@property (weak, nonatomic) IBOutlet UIView      *DetailView;
@property (weak, nonatomic) IBOutlet UIImageView *DetailNumberImage;
@property (weak, nonatomic) IBOutlet UILabel     *DetailTitle;
@property (weak, nonatomic) IBOutlet UILabel     *DetailDescription;
@property (weak, nonatomic) IBOutlet UILabel     *DetailAddress;
@property (weak, nonatomic) IBOutlet UIImageView *DetailImage;
@property (weak, nonatomic) IBOutlet UIButton *DetailPrevious;
@property (weak, nonatomic) IBOutlet UIButton *DetailNext;

- (IBAction)moreInfoButtonClick:(UIButton *)sender;
- (IBAction)detailLocationButtonClick:(UIButton *)sender;
- (IBAction)detailPreviousButtonClick:(UIButton *)sender;
- (IBAction)detailNextButtonClick:(UIButton *)sender;

@property (weak, nonatomic) IBOutlet UIView *splashView;
- (IBAction)splashClick:(id)sender;
@property (weak, nonatomic) IBOutlet UIView *headerView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //splash
    [UIView animateWithDuration:0.5f delay:2.0f options:UIViewAnimationOptionLayoutSubviews animations:^{
        self.splashView.alpha = 0;
    } completion:^ (BOOL finish) {
        [self.splashView removeFromSuperview];
    }];
    
    self.headerView.userInteractionEnabled = NO;
    
    self.featureDataSource = [NSMutableArray arrayWithCapacity:10];
    self.imageDataSource = [NSMutableDictionary dictionaryWithCapacity:10];
    [self.FeatureTableview registerClass:[EsriCell class] forCellReuseIdentifier:@"EsriCell"];
    
    
    //Set up the map view
    self.mapView.touchDelegate = self;
    self.mapView.callout.delegate = self;
    
    AGSPortal *portal = [AGSPortal ArcGISOnlineWithLoginRequired:NO];
    portal.credential = [AGSCredential credentialWithUser:@"NsLonger" password:@"NsLonger1010"];
    AGSPortalItem *item = [AGSPortalItem portalItemWithPortal:portal itemID:@"3fe3f7db8a644861b5ae44022a536e5c"];
    
    self.map = [AGSMap mapWithItem:item];
    self.mapView.map = self.map;
    
    __weak __typeof(self) weakSelf = self;
    
    self.mapView.layerViewStateChangedHandler = ^(AGSLayer *layer, AGSLayerViewState *layerViewState)
    {
        if (layerViewState.status == AGSLayerViewStatusActive) {
                [weakSelf layerDidLoad:layer];
        }
        else if (layerViewState.status == AGSLayerViewStatusError) {
            [weakSelf layer:layer didFailToLoadWithError:layerViewState.error];
        }
    };
            
    [self.map loadWithCompletion:^(NSError * _Nullable error) {
        [self mapDidLoad];
    }];
    
}

#pragma mark - geoView touch delegate methods

-(void)geoView:(AGSGeoView *)geoView didTapAtScreenPoint:(CGPoint)screenPoint mapPoint:(AGSPoint *)mapPoint {
    //Zoom and select for features that were tapped on
    [self.activeFeatureLayer clearSelection];
        NSLog(@"%f %f %@",screenPoint.x,screenPoint.y,mapPoint);
        [self.mapView identifyLayersAtScreenPoint:screenPoint
                                        tolerance:10
                                 returnPopupsOnly:YES
                           maximumResultsPerLayer:1
                                       completion:^(NSArray<AGSIdentifyLayerResult *> * _Nullable identifyResults, NSError * _Nullable error) {
            NSMutableArray *popups = [NSMutableArray array];
            for (AGSIdentifyLayerResult *result in identifyResults) {
                
                [popups addObjectsFromArray:result.popups];
                for (AGSIdentifyLayerResult *sublayerResults in result.sublayerResults) {
                    [popups addObjectsFromArray:sublayerResults.popups];
                }
            }
                                           
                                           
            if (popups.count > 0) {
                
                for (int i = 0; i<self.featureDataSource.count; i++) {
                    AGSFeature * feature = self.featureDataSource[i];
                    if ([feature.geometry isEqualToGeometry:((AGSPopup*)popups[0]).geoElement.geometry]) {
                        AGSPoint * point = feature.geometry.extent.center;
                        [self.activeFeatureLayer selectFeature:feature];
                        [self.mapView setViewpointCenter:point scale:7000.0f completion:nil];
                        [self.FeatureTableview selectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] animated:NO scrollPosition:UITableViewScrollPositionTop];
                        [self detailDidChange];
                        [self descriptionButtonClicked:nil];
                    }
                }
            }
        }];
}


#pragma mark - layer/map handler methods

-(void)layerDidLoad:(AGSLayer *)layer{
    
    //The last feature layer we encounter we will use for editing features
    //If the web map contains more than one feature layer, the sample may need to be modified to handle that
    if([layer isKindOfClass:[AGSFeatureLayer class]]){
        
        dispatch_async(dispatch_get_main_queue(), ^{
        
        self.activeFeatureLayer = (AGSFeatureLayer*)layer;
               
        //Query for tableViewSourceData
        AGSServiceFeatureTable *fTable = (AGSServiceFeatureTable *)self.activeFeatureLayer.featureTable;
        AGSQueryFeatureFields fields = AGSQueryFeatureFieldsLoadAll;
        AGSQueryParameters *query = [AGSQueryParameters queryParameters];
        query.returnGeometry = YES;
        query.whereClause = @"1=1";
        [fTable queryFeaturesWithParameters:query queryFeatureFields:fields completion:
         ^(AGSFeatureQueryResult * _Nullable result, NSError * _Nullable error) {
             if (!error && result.featureEnumerator.allObjects.count > 0) {
                //Result
                self.featureDataSource = [NSMutableArray arrayWithArray:result.featureEnumerator.allObjects];
                [self.FeatureTableview reloadData];
                [self detailDidChange];
                [self featureQueryDidComplete];
                 
             }
         }];
        });
    }
}

- (void)featureQueryDidComplete
{
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 3;
    
    // async to mainqueue
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        //stop loadIndicator
        if ([self.loadIndicator isAnimating]) {
            [self.loadIndicator stopAnimating];
        }
        self.headerView.userInteractionEnabled = YES;
    }];
    
    NSBlockOperation *oparationFinish = [NSBlockOperation blockOperationWithBlock:^{
        NSLog(@"image array download all complete");
    }];
    
    NSMutableArray * opAry = [NSMutableArray arrayWithCapacity:100];
    NSLock * dictionary_lock = [[NSLock alloc] init];
    
    for (AGSFeature* object in self.featureDataSource) {
        if (object.attributes[@"URLGraphic"]) {
            
            NSString * objIdStr = [NSString stringWithFormat:@"%d",[object.attributes[@"ObjectId"] intValue]];
            NSBlockOperation *oparation = [NSBlockOperation blockOperationWithBlock:^{
                NSURL * url = [NSURL URLWithString:object.attributes[@"URLGraphic"]];
                NSData *data = [NSData dataWithContentsOfURL:url];
                UIImage *downloadImage = [UIImage sd_imageWithData:data];

                if (!downloadImage) {
                    downloadImage = [UIImage imageNamed:@"LoadFail"];
                }
                
                // add to dictionary in lock
                [dictionary_lock lock];
                [self.imageDataSource setObject:downloadImage forKey:objIdStr];
                [dictionary_lock unlock];
                
                // async to mainqueue
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    NSLog(@"image array download complete ObjectId = %@",object.attributes[@"ObjectId"]);
                    
                    NSIndexPath * indexPath = [NSIndexPath indexPathForRow:[object.attributes[@"ObjectId"] intValue]-1 inSection:0];

                    NSInteger selectedRow = self.FeatureTableview.indexPathForSelectedRow.row;
                    
                    [self.FeatureTableview reloadRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath,nil] withRowAnimation:UITableViewRowAnimationNone];
                    
                    if (indexPath.row==selectedRow) {
                        [self.FeatureTableview selectRowAtIndexPath:[NSIndexPath indexPathForRow:selectedRow inSection:0] animated:NO scrollPosition:UITableViewScrollPositionTop];
                        [self detailDidChange];
                    }
                }];
                
                
            }];
            [oparationFinish addDependency:oparation];
            [opAry addObject:oparation];
            
        }
    }
    
    for (NSBlockOperation *oparation in opAry) {
        [queue addOperation:oparation];
    }
    [opAry removeAllObjects];
    [queue addOperation:oparationFinish];
    
    
}



- (void)mapDidLoad {
    //do sth
}

-(void)layer:(AGSLayer *)layer didFailToLoadWithError:(NSError *)error{
    NSLog(@"Failed to load layer : %@", layer.name);
    NSLog(@"ESRI Homework Simple may not work as expected");
}

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.featureDataSource count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    EsriCell *cell = [tableView dequeueReusableCellWithIdentifier:@"EsriCell" forIndexPath:indexPath];
    NSMutableDictionary * dataSouce = self.featureDataSource[indexPath.row].attributes;
    NSString * obcIdStr = [NSString stringWithFormat:@"%d",[dataSouce[@"ObjectId"] intValue]];
    UIImage * itemImage = self.imageDataSource[obcIdStr];
    [cell setAttributes:dataSouce downloadImage:itemImage];
    
    [cell clear];
    [cell draw];

    return cell;
}

#pragma mark -
#pragma mark UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [self detailDidChange];
    [self descriptionButtonClicked:nil];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark TopButtonClicked
- (IBAction)featureTableButtonClicked:(UIButton *)sender {
    self.FeatureTableview.hidden = NO;
    self.DetailView.hidden = YES;
}

- (IBAction)descriptionButtonClicked:(UIButton *)sender {
    self.FeatureTableview.hidden = YES;
    self.DetailView.hidden = NO;
}

- (IBAction)mapButtonClicked:(UIButton *)sender {
    self.FeatureTableview.hidden = YES;
    self.DetailView.hidden = YES;
}

#pragma mark -
#pragma mark MediaLayout

- (void)detailDidChange
{
    NSInteger selectedRow = self.FeatureTableview.indexPathForSelectedRow.row;
    NSLog(@"detailDidChange row = %d",selectedRow);
    if (selectedRow==0) {
        [self.DetailPrevious setEnabled:NO];
    }
    else
    {
        [self.DetailPrevious setEnabled:YES];
    }
    
    if (selectedRow==(self.featureDataSource.count-1))
    {
        [self.DetailNext setEnabled:NO];
    }
    else
    {
        [self.DetailNext setEnabled:YES];
    }
    
    AGSFeature *feature = self.featureDataSource[selectedRow];
    
    UIImage * numImage = [UIImage imageNamed:[NSString stringWithFormat:@"%@%d",@"NumberIcong",[feature.attributes[@"ObjectId"] intValue]]];
    self.DetailNumberImage.image = numImage;
    self.DetailTitle.text = feature.attributes[@"RestaurantName"];
    self.DetailDescription.text = feature.attributes[@"Description"];
    self.DetailAddress.text = [NSString stringWithFormat:@"%@ %@ %@ %@",feature.attributes[@"Address"],feature.attributes[@"City"],feature.attributes[@"State"],feature.attributes[@"Zip"]];
    
    NSString * objIdStr = [NSString stringWithFormat:@"%d",[feature.attributes[@"ObjectId"] intValue]];
    UIImage * image = self.imageDataSource[objIdStr];
    if (!image) {
        image = [UIImage imageNamed:@"imagePlaceholderBig"];
    }
    
    self.DetailImage.backgroundColor = [UIColor whiteColor];
    self.DetailImage.image = image;
    CALayer * layer = [self.DetailImage layer];
    layer.borderColor = [[UIColor whiteColor] CGColor];
    layer.borderWidth = 4.0f;
    
}

- (IBAction)detailNextButtonClick:(UIButton *)sender {
    NSInteger selectedRow = self.FeatureTableview.indexPathForSelectedRow.row;
    [self.FeatureTableview selectRowAtIndexPath:[NSIndexPath indexPathForRow:selectedRow+1 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionTop];
    [self detailDidChange];
}

- (IBAction)detailPreviousButtonClick:(UIButton *)sender {
    NSInteger selectedRow = self.FeatureTableview.indexPathForSelectedRow.row;
    [self.FeatureTableview selectRowAtIndexPath:[NSIndexPath indexPathForRow:selectedRow-1 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionTop];
    [self detailDidChange];
}

- (IBAction)detailLocationButtonClick:(UIButton *)sender {
    
    [self.activeFeatureLayer clearSelection];
    
    NSInteger selectedRow = self.FeatureTableview.indexPathForSelectedRow.row;
    AGSFeature * feature = self.featureDataSource[selectedRow];
    AGSPoint * point = feature.geometry.extent.center;
    [self.activeFeatureLayer selectFeature:feature];
    [self.mapView setViewpointCenter:point scale:7000.0f completion:nil];
    [self mapButtonClicked:nil];
    
}

- (IBAction)moreInfoButtonClick:(UIButton *)sender {
    NSInteger selectedRow = self.FeatureTableview.indexPathForSelectedRow.row;
    AGSFeature *feature = self.featureDataSource[selectedRow];
    NSString * url = feature.attributes[@"Website"];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url] options:@{UIApplicationOpenURLOptionUniversalLinksOnly : @NO} completionHandler:nil];
}
- (IBAction)splashClick:(id)sender {
    [self.splashView removeFromSuperview];
}
@end

