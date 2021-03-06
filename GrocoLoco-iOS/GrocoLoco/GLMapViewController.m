//
//  GLMapViewController.m
//  GrocoLoco
//
//  Created by Mark Hall on 2015-10-19.
//  Copyright © 2015 Mark Hall. All rights reserved.
//

#import "GLMapViewController.h"
#import "MapKit/MapKit.h"
#import "GLMapAnnotation.h"

@interface GLMapViewController () <CLLocationManagerDelegate, UISearchBarDelegate, MKMapViewDelegate>

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CLLocation *userLocation;
@property (strong, nonatomic) CLGeocoder *geocoder;
@property (strong, nonatomic) CLPlacemark *placemark;
@property (strong, nonatomic) MKLocalSearch *localSearch;
@property (strong, nonatomic) NSArray *places;

@end

@implementation GLMapViewController

#pragma mark -
#pragma mark View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;

    self.userLocation = [[CLLocation alloc] init];

    self.geocoder = [[CLGeocoder alloc] init];

    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    self.locationManager.distanceFilter = 10.0f;
    [self.locationManager startUpdatingLocation];
    self.mapView.showsUserLocation = YES;
    [self.locationManager requestAlwaysAuthorization];

    self.searchBar.delegate = self;

    self.navigationController.navigationBarHidden = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [[GLNetworkingManager sharedManager] getListOFGroceryStores:^(NSDictionary *response, NSError *error) {
        if (error){
            NSLog(@"%@",error.localizedDescription);
        }
        else{
            NSInteger tag = 0;
            for (NSDictionary *store in response){
                GLMapAnnotation* annotation = [[GLMapAnnotation alloc] init];
                annotation.title = store[@"StoreName"];
                annotation._id = store[@"_id"];
                annotation.tag = tag;
                CLLocationCoordinate2D myCoordinate;
                myCoordinate.latitude = [store[@"Latitude"] doubleValue];
                myCoordinate.longitude = [store[@"Longitude"] doubleValue];
                annotation.coordinate = myCoordinate;
                [self.mapView addAnnotation:annotation];
                tag++;
            }
        }
    }];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
//    self.navigationController.navigationBarHidden = NO;
}

#pragma mark -
#pragma mark CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    self.userLocation = [locations lastObject];

    [manager stopUpdatingLocation]; // We only want one update.

    manager.delegate = nil;

    [self.mapView setCenterCoordinate:[self.userLocation coordinate] animated:YES];
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance([self.userLocation coordinate], 2000, 2000);
    [self.mapView setRegion:[self.mapView regionThatFits:region] animated:YES];

    // Reverse Geocoding
    [self.geocoder reverseGeocodeLocation:self.userLocation
                        completionHandler:^(NSArray *placemarks, NSError *error) {

                            if (error == nil && [placemarks count] > 0) {
                                self.placemark = [placemarks lastObject];
                                //                                self.searchBar.text = [NSString stringWithFormat:@"%@ %@\n%@ %@\n%@\n%@",
                                //                                                                self.placemark.subThoroughfare, self.placemark.thoroughfare,
                                //                                                                self.placemark.postalCode, self.placemark.locality,
                                //                                                                self.placemark.administrativeArea,
                                //                                                                self.placemark.country];
                            }
                            else {
                                NSLog(@"Geocoder Error: %@", error.debugDescription);
                            }
                        }];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    [self showError:error];
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil;
    }
    static NSString *identifier = @"PinAnnotation";
    MKPinAnnotationView *pinView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:identifier];
    pinView.animatesDrop = YES;
    pinView.canShowCallout = YES;

    //TODO: Check if annotation coordinates match user's store and set button to selected

    UIButton *rightButton = [UIButton buttonWithType:UIButtonTypeCustom];
    rightButton.frame = CGRectMake(0, 0, 36, 36);
    [rightButton setImage:[UIImage imageNamed:@"Check"] forState:UIControlStateSelected];
    [rightButton setImage:[UIImage imageNamed:@"uncheck"] forState:UIControlStateNormal];
    [rightButton addTarget:self
                    action:@selector(buttonMethod:)
          forControlEvents:UIControlEventTouchUpInside];
    GLMapAnnotation *customAnnotation = (GLMapAnnotation *)annotation;
    rightButton.tag = customAnnotation.tag;
    pinView.rightCalloutAccessoryView = rightButton;

    if ([self CLLocationCoordinateEqualC1:customAnnotation.coordinate C2:[[GLUserManager sharedManager] storeCoordinate]]) {
        rightButton.selected = YES;
    }

    return pinView;
}

- (void)buttonMethod:(UIButton *)sender
{
    sender.selected = !sender.selected;
    
    
    GLMapAnnotation *selectedAnnotation;
    
    for (GLMapAnnotation *annotation in self.mapView.annotations){
        if ([annotation isKindOfClass:[MKUserLocation class]]) {
            continue;
        }
        if (annotation.tag == sender.tag){
            selectedAnnotation = annotation;
        }
    }
    
    [[GLNetworkingManager sharedManager] setUserLocation:selectedAnnotation.title
                               id:selectedAnnotation._id
                              completion:^(NSDictionary *response, NSError *error) {
                                  if (error) {
                                      [self showError:error];
                                  }
                                  else {
                                      [[GLUserManager sharedManager] setStoreName:selectedAnnotation.title];
                                      [[GLUserManager sharedManager] setStoreCoordinate:CLLocationCoordinate2DMake(selectedAnnotation.coordinate.latitude, selectedAnnotation.coordinate.longitude)];
                                      if (self.isChangingStore){
                                          [self dismissViewControllerAnimated:YES completion:nil];
                                      }
                                      else{
                                          [[GLNetworkingManager sharedManager] createNewGroceryList:[[GLUserManager sharedManager] storeName] completion:^(NSDictionary *response, NSError *error) {
                                              if (error){
                                                  NSLog(@"%@",error.localizedDescription);
                                              }
                                              else{
                                                  [self performSegueWithIdentifier:GL_SHOW_HOME_MAP sender:self];
                                              }
                                          }];
                                      }
                                  }
                              }];
}

#pragma mark -
#pragma mark UISearchBarDelegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [self.mapView removeAnnotations:self.mapView.annotations];
    [searchBar resignFirstResponder];

    if (self.localSearch.searching) {
        [self.localSearch cancel];
    }

    //    MKCoordinateRegion newRegion;
    ////    newRegion = self.mapView.region;
    //    newRegion.center.latitude = self.userLocation.coordinate.latitude;
    //    newRegion.center.longitude = self.userLocation.coordinate.longitude;
    //
    //    newRegion.span.latitudeDelta = 0.5;
    //    newRegion.span.longitudeDelta = 0.5;

    MKLocalSearchRequest *request = [[MKLocalSearchRequest alloc] init];

    request.naturalLanguageQuery = searchBar.text;
    //    request.region = newRegion;
    request.region = self.mapView.region;

    MKLocalSearchCompletionHandler completionHandler = ^(MKLocalSearchResponse *response, NSError *error) {
        if (error != nil) {
            [self showError:error];
        }
        else {
            self.places = [response mapItems];
            for (MKMapItem *mapItem in self.places) {
                GLMapAnnotation *annotation = [[GLMapAnnotation alloc] init];
                annotation.coordinate = mapItem.placemark.location.coordinate;
                annotation.title = mapItem.name;
                annotation.url = mapItem.url;
                [self.mapView addAnnotation:annotation];
            }
            NSInteger i = 0;
            id annotation = [self.mapView.annotations objectAtIndex:i];
            while ([annotation isKindOfClass:[MKUserLocation class]]) {
                annotation = [self.mapView.annotations objectAtIndex:i];
                ++i;
            }
            [self.mapView selectAnnotation:annotation animated:YES];
            MKCoordinateRegion region = response.boundingRegion;

            self.mapView.centerCoordinate = region.center;
        }
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    };

    if (self.localSearch != nil) {
        self.localSearch = nil;
    }
    self.localSearch = [[MKLocalSearch alloc] initWithRequest:request];

    [self.localSearch startWithCompletionHandler:completionHandler];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

#pragma mark -
#pragma mark Helper Methods

- (BOOL)CLLocationCoordinateEqualC1:(CLLocationCoordinate2D)coordinate1 C2:(CLLocationCoordinate2D)coordinate2
{
    return (coordinate1.latitude == coordinate2.latitude) && (coordinate1.longitude == coordinate2.longitude);
}

@end
