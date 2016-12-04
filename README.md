Open-RMBT iOS App
=================

OpenRMBT is an open source, multi-threaded bandwidth test used in [RTR-Netztest]. This repository contains the sources for the iOS App. For server and Android App sources, see [https://github.com/alladin-IT/open-rmbt].

OpenRMBT is released under the [Apache License, Version 2.0]. The iOS App was developed by [appscape] and financed by the [Austrian Regulatory Authority for Broadcasting and Telecommunications (RTR)] [RTR].

  [appscape]: http://appscape.at/
  [RTR-Netztest]: http://netztest.at/
  [RTR]: http://www.rtr.at/
  [Apache License, Version 2.0]: http://www.apache.org/licenses/LICENSE-2.0
  [https://github.com/alladin-IT/open-rmbt]: https://github.com/alladin-IT/open-rmbt

Building
--------

Xcode 8+ with iOS 10 SDK is required to build the Open-RMBT iOS App.

Before building, you need to supply a correct Google Maps API key as well as a Open-RMBT server parameters in `RMBTConfig.h`.

Third-party Libraries
---------------------

In addition to Google Maps iOS SDK, OpenRMBT iOS App uses several open source 3rd-party libraries that are under terms of a separate license:

* [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket), public domain license
* [AFNetworking](https://github.com/AFNetworking/AFNetworking), MIT license
* [SVWebViewController](https://github.com/samvermette/SVWebViewController), MIT license
* [BlocksKit](https://github.com/zwaldowski/BlocksKit), MIT license
* [libextobjc](https://github.com/jspahrsummers/libextobjc), MIT license
* [TUSafariActivity](https://github.com/davbeck/TUSafariActivity), 2-clause BSD license
* [BCGenieEeffect](https://github.com/Ciechan/BCGenieEffect), MIT license
* [GCNetworkReachability](https://github.com/GlennChiu/GCNetworkReachability), MIT license

For details, see [acknowledgements](Pods/Target Support Files/Pods-RMBT/Pods-RMBT-acknowledgements.markdown).