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

#import "RMBTSettings.h"
#import "RMBTMapOptions.h"

RMBTMapOptionsOverlay* RMBTMapOptionsOverlayAuto;
RMBTMapOptionsOverlay* RMBTMapOptionsOverlayHeatmap;
RMBTMapOptionsOverlay* RMBTMapOptionsOverlayPoints;
RMBTMapOptionsOverlay* RMBTMapOptionsOverlayShapes;

NSString * const RMBTMapOptionsToastInfoTitle = @"title";
NSString * const RMBTMapOptionsToastInfoKeys =  @"keys";
NSString * const RMBTMapOptionsToastInfoValues = @"values";

#pragma mark - RMBTMapOptions

@interface RMBTMapOptions() {
    NSMutableArray *_types;
}
@end

@implementation RMBTMapOptions

+ (void)initialize {
    if ([self class] == [RMBTMapOptions class]) {
        RMBTMapOptionsOverlayPoints = [[RMBTMapOptionsOverlay alloc] initWithIdentifier:@"points"
                                                                   localizedDescription:NSLocalizedString(@"Points", @"Map overlay description")];
        RMBTMapOptionsOverlayAuto = [[RMBTMapOptionsOverlay alloc] initWithIdentifier:@"auto"
                                                                   localizedDescription:NSLocalizedString(@"Auto", @"Map overlay description")];
        RMBTMapOptionsOverlayHeatmap = [[RMBTMapOptionsOverlay alloc] initWithIdentifier:@"heatmap"
                                                                   localizedDescription:NSLocalizedString(@"Heatmap", @"Map overlay description")];
        RMBTMapOptionsOverlayShapes = [[RMBTMapOptionsOverlay alloc] initWithIdentifier:@"shapes"
                                                                    localizedDescription:NSLocalizedString(@"Shapes", @"Map overlay description")];

    }
}

- (instancetype)initWithResponse:(NSDictionary*)response {
    if (self = [super init]) {
        _overlays = [NSArray arrayWithObjects:RMBTMapOptionsOverlayAuto, RMBTMapOptionsOverlayHeatmap, RMBTMapOptionsOverlayPoints, RMBTMapOptionsOverlayShapes, nil];
        _types = [NSMutableArray array];

        response = response[@"mapfilter"]; // Root element, always the same
        NSParameterAssert(response);
        
        NSDictionary* filters = response[@"mapFilters"];

        for (id typeResponse in response[@"mapTypes"]) {
            RMBTMapOptionsType *type = [[RMBTMapOptionsType alloc] initWithResponse:typeResponse];
            [_types addObject:type];

            // Process filters for this type
            for (id filterResponse in filters[type.identifier]) {
                RMBTMapOptionsFilter *filter = [[RMBTMapOptionsFilter alloc] initWithResponse:filterResponse];
                [type addFilter:filter];
            }
        }

        // Select first subtype of first type as active per default
        _activeSubtype = [[[_types objectAtIndex:0] subtypes] objectAtIndex:0];
        _activeOverlay = RMBTMapOptionsOverlayAuto;

        _mapViewType = RMBTMapOptionsMapViewTypeStandard;

        // ..then try to actually select options from app state, if we have one
        [self restoreSelection];
    }
    return self;
}


- (void)restoreSelection {
    RMBTMapOptionsSelection* selection = [RMBTSettings sharedSettings].mapOptionsSelection;

    if (selection.subtypeIdentifier) {
        for (RMBTMapOptionsType* t in _types) {
            RMBTMapOptionsSubtype *st = [t.subtypes bk_match:^BOOL(RMBTMapOptionsSubtype *s) {
                return [s.identifier isEqualToString:selection.subtypeIdentifier];
            }];
            if (st) {
                _activeSubtype = st;
                break;
            } else if ([t.identifier isEqualToString:selection.subtypeIdentifier]) {
                _activeSubtype = [t.subtypes objectAtIndex:0];
            }
        }
    }

    if (selection.overlayIdentifier) {
        for (RMBTMapOptionsOverlay* o in _overlays) {
            if ([o.identifier isEqualToString:selection.overlayIdentifier]) {
                _activeOverlay = o;
                break;
            }
        }
    }

    if (selection.activeFilters) {
        for (RMBTMapOptionsFilter* f in _activeSubtype.type.filters) {
            NSString *activeFilterValueTitle = selection.activeFilters[f.title];
            if (activeFilterValueTitle) {
                RMBTMapOptionsFilterValue *v = [f.possibleValues bk_match:^BOOL(RMBTMapOptionsFilterValue *fv) {
                    return [fv.title isEqualToString:activeFilterValueTitle];
                }];
                if (v) {
                    f.activeValue = v;
                }
            }
        }
    }
}

- (void)saveSelection {
    RMBTMapOptionsSelection *selection = [[RMBTMapOptionsSelection alloc] init];
    selection.subtypeIdentifier = _activeSubtype.identifier;
    selection.overlayIdentifier = _activeOverlay.identifier;

    NSMutableDictionary *activeFilters = [NSMutableDictionary dictionary];
    for (RMBTMapOptionsFilter *f in _activeSubtype.type.filters) {
        activeFilters[f.title] = f.activeValue.title;
    }
    selection.activeFilters = activeFilters;
    [RMBTSettings sharedSettings].mapOptionsSelection = selection;
}

- (NSDictionary*)toastInfo {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    NSMutableArray *keys = [NSMutableArray array];
    NSMutableArray *values = [NSMutableArray array];

    info[RMBTMapOptionsToastInfoTitle] = [NSString stringWithFormat:@"%@ %@", _activeSubtype.type.title, _activeSubtype.title];

    [keys addObject:@"Overlay"];
    [values addObject:_activeOverlay.localizedDescription];

    for (RMBTMapOptionsFilter* f in _activeSubtype.type.filters) {
        [keys addObject:[f.title capitalizedString]];
        [values addObject:f.activeValue.title];
    }

    info[RMBTMapOptionsToastInfoKeys] = keys;
    info[RMBTMapOptionsToastInfoValues] = values;

    return info;
}

@end


#pragma mark - RMBTMapOptionsOverlay

@implementation RMBTMapOptionsOverlay
- (instancetype)initWithIdentifier:(NSString*)identifier localizedDescription:(NSString*)localizedDescription {
    if (self = [super init]) {
        _identifier = identifier;
        _localizedDescription = localizedDescription;
    }
    return self;
}
@end

#pragma mark - RMBTMapOptionsType

@interface RMBTMapOptionsType() {
    NSMutableArray *_subtypes;
    NSMutableArray *_filters;
    
    NSMutableDictionary *_paramsDictionary;
}
@end

@implementation RMBTMapOptionsType
- (instancetype)initWithResponse:(id)response {
    if (self = [super init]) {
        _filters = [NSMutableArray array];
        _title = response[@"title"];
        _subtypes = [NSMutableArray array];
        for (id subresponse in response[@"options"]) {
            RMBTMapOptionsSubtype *subtype = [[RMBTMapOptionsSubtype alloc] initWithResponse:subresponse];
            subtype.type = self;
            [_subtypes addObject:subtype];
            
            NSArray *pathComponents = [subtype.mapOptions componentsSeparatedByString:@"/"];
            
            // browser/signal -> browser
            if (!_identifier) {
                _identifier = [pathComponents objectAtIndex:0];
            } else {
                NSAssert([_identifier isEqualToString:[pathComponents objectAtIndex:0]], @"Subtype identifier invalid");
            }
        }
    }
    return self;
}

- (void)addFilter:(RMBTMapOptionsFilter*)filter {
    [_filters addObject:filter];
}

- (NSDictionary*)paramsDictionary {
    if (!_paramsDictionary) {
        _paramsDictionary = [NSMutableDictionary dictionary];
        for (RMBTMapOptionsFilter *f in _filters) {
            [_paramsDictionary addEntriesFromDictionary:f.activeValue.info];
        }
    }
    return _paramsDictionary;
}

@end

#pragma mark - RMBTMapOptionsSubtype

@interface RMBTMapOptionsSubtype() {
    NSMutableDictionary *_paramsDictionary;    
}
@end

@implementation RMBTMapOptionsSubtype

- (instancetype)initWithResponse:(id)response {
    if (self = [super init]) {
        _title = response[@"title"];
        _summary = response[@"summary"];
        _mapOptions = response[@"map_options"];
        _overlayType = response[@"overlay_type"];
        _identifier = _mapOptions;
    }
    return self;
}

- (NSDictionary*)paramsDictionary {
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:@{
             @"map_options": _mapOptions
    }];
    
    for (RMBTMapOptionsFilter *f in self.type.filters) {
        [result addEntriesFromDictionary:f.activeValue.info];
    }
        
    return result;
}


- (NSDictionary*)markerParamsDictionary {
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:@{
                                   @"options": @{@"map_options": _mapOptions, @"overlay_type": _overlayType}
    }];
    
    NSMutableDictionary *filterResult = [NSMutableDictionary dictionary];
    for (RMBTMapOptionsFilter *f in self.type.filters) {
        [filterResult addEntriesFromDictionary:f.activeValue.info];
    }
    
    [result setObject:filterResult forKey:@"filter"];
    
    return result;
}

@end

#pragma mark - RMBTMapOptionsFilterValue

@implementation RMBTMapOptionsFilterValue

- (instancetype)initWithResponse:(id)response {
    if (self = [super init]) {
        _title = response[@"title"];
        _summary = response[@"summary"];
        _isDefault = [response[@"default"] boolValue];
        NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:response];
        [d removeObjectsForKeys:@[@"title", @"summary", @"default"]];
        
        // Remove empty keys
        for (id key in d) {
            if ([d[key] isEqual:@""]) [d removeObjectForKey:key];
        }
        
        _info = d;
    }
    return self;
}
@end

#pragma mark - RMBTMapOptionsFilter

@implementation RMBTMapOptionsFilter

- (instancetype)initWithResponse:(id)response {
    if (self = [super init]) {
        _title = response[@"title"];
        _possibleValues = [NSMutableArray array];
        for (id subresponse in response[@"options"]) {
            RMBTMapOptionsFilterValue *filterValue = [[RMBTMapOptionsFilterValue alloc] initWithResponse:subresponse];
            if (filterValue.isDefault) _activeValue = filterValue;
            [((NSMutableArray*)_possibleValues) addObject:filterValue];
        }
    }
    return self;
}
@end

#pragma mark - RMBTMapOptionsSelection

@implementation RMBTMapOptionsSelection
@end