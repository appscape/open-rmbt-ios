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

#import <GoogleMaps/GoogleMaps.h>
#import <BCGenieEffect/UIView+Genie.h>

#import "RMBTMapViewController.h"
#import "RMBTMapOptionsViewController.h"
#import "RMBTMapServer.h"
#import "RMBTMapMeasurement.h"
#import "RMBTMapCalloutView.h"
#import "RMBTLocationTracker.h"

#import "UIViewController+ModalBrowser.h"

// These values are passed to map server and are multiplied by 2x on retina displays to get pixel sizes
static NSUInteger kTileSizePoints = 256;
static NSUInteger kPointDiameterSizePoints = 8;

static NSString* const kCameraLatKey     = @"map.camera.lat";
static NSString* const kCameraLngKey     = @"map.camera.lng";
static NSString* const kCameraZoomKey    = @"map.camera.zoom";
static NSString* const kCameraBearingKey = @"map.camera.bearing";
static NSString* const kCameraAngleKey   = @"map.camera.angle";

@interface RMBTMapViewController()<GMSMapViewDelegate, RMBTMapOptionsViewControllerDelegate, UITabBarControllerDelegate> {
    RMBTMapServer *_mapServer;
    RMBTMapOptions *_mapOptions;
    
    GMSMapView *_mapView;
    GMSMarker *_mapMarker;
    GMSTileLayer *_mapLayerHeatmap, *_mapLayerPoints, *_mapLayerShapes;
    
    NSMutableDictionary *_tileParamsDictionary;

    NSUInteger _tileSize, _pointDiameterSize;

    NSTimer *_hideOverlayTimer;
}

@property (nonatomic, strong) UIBarButtonItem *settingsBarButtonItem;
@end

@implementation RMBTMapViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    if ([self.navigationController.viewControllers firstObject] == self) {
        [self.navigationController.tabBarItem setSelectedImage:[UIImage imageNamed:@"tab_map_selected"]];
    }

    self.toastBarButtonItem.enabled = NO;

    self.settingsBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"map_options"] style:UIBarButtonItemStylePlain target:self action:@selector(showMapOptions)];
    self.settingsBarButtonItem.enabled = NO;

    self.navigationItem.leftBarButtonItems = @[self.settingsBarButtonItem];

    if (self.initialLocation) {
        UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"back"] style:UIBarButtonItemStylePlain target:self action:@selector(back)];
        self.navigationItem.leftBarButtonItems = @[backItem, self.settingsBarButtonItem];
    }

    self.locateMeButton.translatesAutoresizingMaskIntoConstraints = NO;
    NSDictionary *views = @{@"bottom": self.bottomLayoutGuide, @"locme": self.locateMeButton};
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[locme(44)]-10-[bottom]" options:0 metrics:nil views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[locme(44)]-10-|" options:0 metrics:nil views:views]];

    [self.view layoutIfNeeded];
}

- (void)setupMapView {
    NSAssert(!_mapView, @"Map view already initialized!");
    
    // Supply Google Maps API Key only once during whole app lifecycle
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [GMSServices provideAPIKey:RMBT_GMAPS_API_KEY];
    });

    GMSCameraPosition *cam = [GMSCameraPosition cameraWithLatitude:RMBT_MAP_INITIAL_LAT
                                                         longitude:RMBT_MAP_INITIAL_LNG
                                                              zoom:RMBT_MAP_INITIAL_ZOOM];

    // If test coordinates were provided, center map at the coordinates:
    if (self.initialLocation) {
        cam = [GMSCameraPosition cameraWithLatitude:self.initialLocation.coordinate.latitude
                                          longitude:self.initialLocation.coordinate.longitude
                                               zoom:RMBT_MAP_POINT_ZOOM];
    } else {
        // Otherwise, see if we have user's location available...
        CLLocation* location = [RMBTLocationTracker sharedTracker].location;
        if (location) {
            // and if yes, then show it on the map
            cam = [GMSCameraPosition cameraWithLatitude:location.coordinate.latitude
                                              longitude:location.coordinate.longitude
                                                   zoom:RMBT_MAP_POINT_ZOOM];
        }
    }

    _mapView = [GMSMapView mapWithFrame:self.view.bounds camera:cam];

    _mapView.buildingsEnabled = NO;
    _mapView.myLocationEnabled = YES;

    CGFloat bottomPadding = 60.0f;
    if (self.hidesBottomBarWhenPushed) {
        bottomPadding -= self.bottomLayoutGuide.length;
    }

    _mapView.padding = UIEdgeInsetsMake(60.0f, 10.0f, bottomPadding, 10.0f);
    _mapView.settings.myLocationButton = NO;
    _mapView.settings.compassButton = NO;
    _mapView.settings.tiltGestures = NO;
    _mapView.settings.rotateGestures = NO;

    _mapView.delegate = self;


    _tileSize = (NSUInteger)(kTileSizePoints * [UIScreen mainScreen].scale);
    _pointDiameterSize = (NSUInteger)(kPointDiameterSizePoints * [UIScreen mainScreen].scale);

    _mapServer = [[RMBTMapServer alloc] init];
    [_mapServer getMapOptionsWithSuccess:^(id response) {
        _mapOptions = response;
        self.settingsBarButtonItem.enabled = YES;
        self.toastBarButtonItem.enabled = YES;
        [self setupMapLayers];
        [self refresh];
    }];

    // Setup toast (overlay) view
    self.toastView.hidden = YES;
    self.toastView.layer.cornerRadius = 6.0f;

    // Tapping the toast should hide it
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                    action:@selector(toggleToast:)];
    [self.toastView addGestureRecognizer:tapRecognizer];

    [self.view insertSubview:_mapView belowSubview:self.toastView];
    [self.view insertSubview:self.locateMeButton aboveSubview:_mapView];

    // If test coordinates were provided, show a blue untappable pin at those coordinates
    if (self.initialLocation) {
        GMSMarker *marker = [GMSMarker markerWithPosition:self.initialLocation.coordinate];
        // Approx. HUE_AZURE color from Android
        marker.icon = [GMSMarker markerImageWithColor:[UIColor colorWithRed:0.510 green:0.745 blue:0.984 alpha:1]];
        marker.tappable = NO;
        marker.map = _mapView;
    }
}

- (void)setupMapLayers {
    _mapLayerShapes = [GMSURLTileLayer tileLayerWithURLConstructor:^NSURL *(NSUInteger x, NSUInteger y, NSUInteger zoom) {
        return [_mapServer tileURLForMapOverlayType:RMBTMapOptionsOverlayShapes.identifier x:x y:y zoom:zoom params:_tileParamsDictionary];
    }];
    _mapLayerShapes.tileSize = _tileSize;
    _mapLayerShapes.map = _mapView;
    _mapLayerShapes.zIndex = 100;

    _mapLayerHeatmap = [GMSURLTileLayer tileLayerWithURLConstructor:^NSURL *(NSUInteger x, NSUInteger y, NSUInteger zoom) {
        return [_mapServer tileURLForMapOverlayType:RMBTMapOptionsOverlayHeatmap.identifier x:x y:y zoom:zoom params:_tileParamsDictionary];
    }];
    _mapLayerHeatmap.tileSize = _tileSize;
    _mapLayerHeatmap.map = _mapView;
    _mapLayerHeatmap.zIndex = 101;

    _mapLayerPoints = [GMSURLTileLayer tileLayerWithURLConstructor:^NSURL *(NSUInteger x, NSUInteger y, NSUInteger zoom) {
        return [_mapServer tileURLForMapOverlayType:RMBTMapOptionsOverlayPoints.identifier x:x y:y zoom:zoom params:_tileParamsDictionary];
    }];
    _mapLayerPoints.tileSize = _tileSize;
    _mapLayerPoints.map = _mapView;
    _mapLayerPoints.zIndex = 102;
}

- (void)deselectCurrentMarker {
    if (_mapMarker) {
        _mapMarker.map = nil;
        _mapView.selectedMarker = nil;
        _mapMarker = nil;
    }
}

- (void)togglePopGestureRecognizer:(BOOL)state {
    // Temporary fix for http://code.google.com/p/gmaps-api-issues/issues/detail?id=5772 on iOS7
    self.navigationController.interactivePopGestureRecognizer.enabled = state;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self togglePopGestureRecognizer:YES];
    self.tabBarController.delegate = nil;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self togglePopGestureRecognizer:NO];

    // Note that initializing map view for the first time takes few seconds until all resources are initialized,
    // so to appear more responsive we we do it here (instead of viewDidLoad).
    if (!_mapView) { [self setupMapView]; }

    self.tabBarController.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)refresh {
    _tileParamsDictionary = [_mapOptions.activeSubtype.paramsDictionary mutableCopy];
    [_tileParamsDictionary addEntriesFromDictionary:@{
        @"size": [NSString stringWithFormat:@"%lu", (unsigned long)_tileSize],
        @"point_diameter": [NSString stringWithFormat:@"%lu", (unsigned long)_pointDiameterSize]
    }];

    [self updateLayerVisiblity];

    [_mapLayerShapes clearTileCache];
    [_mapLayerPoints clearTileCache];
    [_mapLayerHeatmap clearTileCache];

    NSDictionary* toastInfo = [_mapOptions toastInfo];

    _toastTitleLabel.text = toastInfo[RMBTMapOptionsToastInfoTitle];
    _toastKeysLabel.text = [toastInfo[RMBTMapOptionsToastInfoKeys] componentsJoinedByString:@"\n"];
    _toastValuesLabel.text = [toastInfo[RMBTMapOptionsToastInfoValues] componentsJoinedByString:@"\n"];

    [self displayToast:YES withGenieEffect:NO];
}

- (void)displayToast:(BOOL)state withGenieEffect:(BOOL)genie {
    if (self.toastView.hidden != state) return; // already displayed/hidden
    self.toastView.hidden = NO;

    if (!genie) {
        self.toastView.alpha = state ? 0.0f : 1.0f;
        self.toastView.transform = CGAffineTransformIdentity;
        [UIView animateWithDuration:0.5f animations:^{
            self.toastView.alpha = state ? 1.0f : 0.0f;
        } completion:^(BOOL finished) {
            self.toastView.hidden = !state;
        }];

        if (state) {
            // autohide
            [self bk_performBlock:^(id sender) {
                [self displayToast:NO withGenieEffect:YES];
            } afterDelay:3.0f];
        }
    } else {
//        self.toastBarButtonItem.enabled = NO;
        CGRect buttonRect = CGRectMake(self.view.frame.size.width-40-10,20,40,40);

        if (state) {
            [self.toastView genieOutTransitionWithDuration:0.5f startRect:buttonRect startEdge:BCRectEdgeBottom completion:^{
//                self.toastBarButtonItem.enabled = YES;
            }];
        } else {
            [self.toastView genieInTransitionWithDuration:0.5f destinationRect:buttonRect destinationEdge:BCRectEdgeBottom completion:^{
//                self.toastBarButtonItem.enabled = YES;
                self.toastView.hidden = YES;
            }];
        }
    }
}

#pragma mark - MapView delegate

- (void)mapView:(GMSMapView *)mapView didTapAtCoordinate:(CLLocationCoordinate2D)coordinate {
    // If we're not showing points, ignore this tap
    if (!_mapLayerPoints.map) return;
    
    [_mapServer getMeasurementsAtCoordinate:coordinate zoom:_mapView.camera.zoom params:_mapOptions.activeSubtype.markerParamsDictionary success:^(NSArray *measurements) {
        RMBTMapMeasurement *measurement = measurements.count > 0 ? [measurements objectAtIndex:0] : nil;
        [self deselectCurrentMarker];
        if (measurement) {
            CGPoint point = [_mapView.projection pointForCoordinate:measurement.coordinate];
            point.y = point.y - 180;
            GMSCameraUpdate *camera =
            [GMSCameraUpdate setTarget:[mapView.projection coordinateForPoint:point]];
            [mapView animateWithCameraUpdate:camera];

            _mapMarker = [GMSMarker markerWithPosition:measurement.coordinate];
            _mapMarker.icon = [self emptyMarkerImage];
            _mapMarker.userData = measurement;
            _mapMarker.appearAnimation = kGMSMarkerAnimationPop;
            _mapMarker.map = _mapView;
            _mapView.selectedMarker = _mapMarker;
        }
    }];
}

- (UIView *)mapView:(GMSMapView *)mapView markerInfoWindow:(GMSMarker *)marker {
    return [RMBTMapCalloutView calloutViewWithMeasurement:marker.userData];
}

- (void)mapView:(GMSMapView *)mapView didTapInfoWindowOfMarker:(GMSMarker *)marker {
    RMBTMapMeasurement *m = marker.userData;
    [_mapServer getURLStringForOpenTestUUID:m.openTestUUID success:^(id url) {
        [self presentModalBrowserWithURLString:url];
    }];
}

- (void)mapView:(GMSMapView *)mapView idleAtCameraPosition:(GMSCameraPosition *)position {
    [self updateLayerVisiblity];
}

#pragma mark - Layer visibility

- (void)setLayer:(GMSTileLayer *)layer hidden:(BOOL)hidden {
    BOOL state = (layer.map == nil);
    if (state == hidden) return;
    layer.map = hidden ? nil : _mapView;
}

- (void)updateLayerVisiblity {
    if (!_mapOptions) return;

    RMBTMapOptionsOverlay* overlay = _mapOptions.activeOverlay;

    BOOL heatmapVisible = NO;
    BOOL shapesVisible = NO;
    BOOL pointsVisible = NO;

    if (overlay == RMBTMapOptionsOverlayShapes) {
        shapesVisible = YES;
    } else if (overlay == RMBTMapOptionsOverlayPoints) {
        pointsVisible = YES;
    } else if (overlay == RMBTMapOptionsOverlayHeatmap) {
        heatmapVisible = YES;
    } else if (overlay == RMBTMapOptionsOverlayAuto) {
        if ([_mapOptions.activeSubtype.type.identifier isEqualToString:@"browser"]) {
            // Shapes
            shapesVisible = YES;
        } else {
            heatmapVisible = YES;
        }
        pointsVisible = (_mapView.camera.zoom >= RMBT_MAP_AUTO_TRESHOLD_ZOOM);
    } else {
        NSParameterAssert(NO);
    }

    [self setLayer:_mapLayerHeatmap hidden:!heatmapVisible];
    [self setLayer:_mapLayerPoints hidden:!pointsVisible];
    [self setLayer:_mapLayerShapes hidden:!shapesVisible];
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"show_map_options"]) {
        RMBTMapOptionsViewController *optionsVC = segue.destinationViewController;
        optionsVC.delegate = self;
        optionsVC.mapOptions = _mapOptions;
    }
}

- (void)mapOptionsViewController:(RMBTMapOptionsViewController *)viewController willDisappearWithChange:(BOOL)change {
    if (change) {
        RMBTLog(@"Map options changed, refreshing...");
        [_mapOptions saveSelection];
        [self refresh];
    }

    switch(_mapOptions.mapViewType) {
        case RMBTMapOptionsMapViewTypeHybrid: { _mapView.mapType = kGMSTypeHybrid; break; }
        case RMBTMapOptionsMapViewTypeSatellite: { _mapView.mapType = kGMSTypeSatellite; break; }
        default: { _mapView.mapType = kGMSTypeNormal; break; }
    }
}

#pragma mark - Button actions

- (void)back {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)showMapOptions {
    [self performSegueWithIdentifier:@"show_map_options" sender:self];
}

- (IBAction)toggleToast:(id)sender {
    [self displayToast:self.toastView.hidden withGenieEffect:YES];
}

- (IBAction)locateMe:(id)sender {
    if (![RMBTLocationTracker sharedTracker].location) return;
    GMSCameraUpdate *camera = [GMSCameraUpdate setTarget:_mapView.myLocation.coordinate];
    [_mapView animateWithCameraUpdate:camera];
}

#pragma mark - Tab bar reloading

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
    if (viewController == self.navigationController) {
        [self deselectCurrentMarker];
        [self locateMe:tabBarController];
    }
}

#pragma mark - Helpers

- (UIImage*)emptyMarkerImage {
    static dispatch_once_t onceToken;
    static UIImage *image;
    dispatch_once(&onceToken, ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), NO, 0.0);
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return image;
}

@end
