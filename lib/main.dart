import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speedmeter/response_data.dart';

Future<void> main() async {
  runApp(const NoPermissionApp(hasCheckedPermissions: false));
  WidgetsFlutterBinding.ensureInitialized();

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.unableToDetermine) {
    permission = await GeolocatorPlatform.instance.requestPermission();
  }
  switch (permission) {
    case LocationPermission.deniedForever:
      runApp(const NoPermissionApp(hasCheckedPermissions: true));
      break;

    case LocationPermission.always:
    case LocationPermission.whileInUse:
      runApp(const MySpeedmeterApp());
      break;

    case LocationPermission.denied:
    case LocationPermission.unableToDetermine:
      runApp(const NoPermissionApp(hasCheckedPermissions: false));
  }
}

class NoPermissionApp extends StatelessWidget {
  const NoPermissionApp({
    Key? key,
    required bool hasCheckedPermissions,
  })  : _hasCheckedPermissions = hasCheckedPermissions,
        super(key: key);

  final bool _hasCheckedPermissions;

  @override
  Widget build(BuildContext context) {
    Widget outWidget;
    // Splash screen mode
    if (!_hasCheckedPermissions) {
      outWidget = Container(
        height: 20,
        width: 100,
        color: Colors.amber,
      );
    } else {
      outWidget = const Text(
        'Location permissions permanently denied!\n'
        'Please reinstall app and provide permissions!',
        style: TextStyle(
          color: Colors.red,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: outWidget),
      ),
    );
  }
}

class MySpeedmeterApp extends StatelessWidget {
  const MySpeedmeterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  GeolocatorPlatform locator = GeolocatorPlatform.instance;
  late StreamController<LocationData?> _velocityUpdatedStreamController;
  double mpstokmph(double mps) => mps * 18 / 5;
  double? _velocity;
  double sumCurrDistance = 0;
  LocationData? allData = LocationData(speed: 0, distance: 0, totalDistance: 0);

  Position? _currentPosition;
  Position? _previousPosition;
  StreamSubscription<Position>? _positionStream;
  double _totalDistance = 0;
  double tempDistance = 0;

  List<Position> locations = <Position>[];
  List<Position> locationsOnlyForDrive = <Position>[];
  final LocationSettings locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 100,
  );

  Future _calculateDistance(bool isDriving) async {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) async {
      if ((await Geolocator.isLocationServiceEnabled())) {
        Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          forceAndroidLocationManager: true,
        ).then((Position position) {
          setState(() {
            _currentPosition = position;

            locations.add(_currentPosition!);
            if (isDriving) {
              locationsOnlyForDrive.add(_currentPosition!);
            }

            if (locations.length > 1) {
              _previousPosition = locations.elementAt(locations.length - 2);

              print('previous lat = ' + _previousPosition!.latitude.toString());
              print(
                  'previous long = ' + _previousPosition!.longitude.toString());

              print('current lat = ' + _currentPosition!.latitude.toString());
              print('current long = ' + _currentPosition!.longitude.toString());

              var _distanceBetweenLastTwoLocations = Geolocator.distanceBetween(
                _previousPosition!.latitude,
                _previousPosition!.longitude,
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              );

              _totalDistance += _distanceBetweenLastTwoLocations >= 0
                  ? _distanceBetweenLastTwoLocations
                  : 0;
              tempDistance = _totalDistance;
              print('Total Distance: $_totalDistance');
            }
          });
        }).catchError((err) {
          print(err);
        });
      } else {
        print("GPS is off.");
        showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                content: const Text('Make sure your GPS is on in Settings !'),
                actions: <Widget>[
                  TextButton(
                      child: const Text('OK'),
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).pop();
                      })
                ],
              );
            });
      }
    });
  }

  void _onAccelerate(double speed) {
    locator.getCurrentPosition().then(
      (Position updatedPosition) {
        _velocity = (speed + updatedPosition.speed) / 2;

        // _currDistance = Geolocator.distanceBetween(initLat, initLong,
        //     updatedPosition.latitude, updatedPosition.longitude);

        // sumCurrDistance = sumCurrDistance + _currDistance!;
        // print('Speed = ' + _velocity.toString());
        // print('initLat = ' + x.toString());
        // print('initLong = ' + y.toString());

        // print('currentLat = ' + updatedPosition.latitude.toString());
        // print('currentLong = ' + updatedPosition.longitude.toString());
        // print('currDistance = ' + (_currDistance! / 1000).toString());
        // print('Sum currDistance = ' + (sumCurrDistance / 1000).toString());
        print('Speed = ' + _velocity.toString());
        if (_velocity! <= 0.09) {
          _velocity = 0.0;
        }
        print('Speed2 = ' + _velocity.toString());
        allData?.speed = _velocity;

        _velocityUpdatedStreamController.add(allData);
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _velocityUpdatedStreamController = StreamController<LocationData?>();
    locator
        .getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      ),
    )
        .listen(
      (Position position) {
        _onAccelerate(position.speed);
      },
    );
    _calculateDistance(false);
  }

  @override
  void dispose() {
    _velocityUpdatedStreamController.close();
    super.dispose();
  }

  // bool isVisible = true;
  double tuningValue = 0;
  bool isInitialDistance = true;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'SpeedMeter',
            style: TextStyle(fontSize: 30),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _positionStream?.cancel();
                        _totalDistance = 0;
                        tuningValue = 0;
                        tempDistance = 0;
                      });
                    },
                    child: const Text(
                      'Reset',
                      style: TextStyle(fontSize: 30),
                    ),
                  ),
                  const SizedBox(width: 20),
                  InkWell(
                    onTap: () {
                      _calculateDistance(false);
                    },
                    child: const Text(
                      'Start',
                      style: TextStyle(fontSize: 30),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
        body: SingleChildScrollView(
          child: Center(
            child: StreamBuilder<LocationData?>(
                stream: _velocityUpdatedStreamController.stream,
                builder: (context, snapshot) {
                  // print(snapshot.data?.speed.toString());
                  print('Temp distance = ' + tempDistance.toString());
                  print('Tuning distance = ' + tuningValue.toString());
                  return snapshot.hasData
                      ? InkWell(
                          onTap: () async {
                            setState(() {
                              //    isVisible = !isVisible;
                              isInitialDistance = false;
                              tempDistance = _totalDistance - tuningValue;
                              tuningValue = _totalDistance;
                            });
                            // locator.getCurrentPosition().then(
                            //       (value) => calcDistance(
                            //         value.latitude,
                            //         value.longitude,
                            //         _currentPosition!.latitude,
                            //         _currentPosition!.longitude,
                            //       ),
                            //     );
                            // _calculateDistance(true);
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              SizedBox(
                                height: 800,
                                child: Column(children: [
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'Distance',
                                          style: TextStyle(fontSize: 30),
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          textBaseline: TextBaseline.alphabetic,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              isInitialDistance
                                                  ? _totalDistance
                                                      .toStringAsFixed(2)
                                                  : (_totalDistance -
                                                              tuningValue) >=
                                                          1000
                                                      ? ((_totalDistance -
                                                                  tuningValue) /
                                                              1000)
                                                          .toStringAsFixed(2)
                                                      : (_totalDistance -
                                                              tuningValue)
                                                          .toStringAsFixed(2),
                                              style: const TextStyle(
                                                fontSize: 100,
                                                letterSpacing: 4,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              (_totalDistance - tuningValue) >=
                                                      1000
                                                  ? " Km"
                                                  : " M",
                                              style: TextStyle(fontSize: 30),
                                            )
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        const Text(
                                          'Total trip',
                                          style: TextStyle(fontSize: 30),
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          textBaseline: TextBaseline.alphabetic,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              (_totalDistance >= 1000
                                                      ? _totalDistance / 1000
                                                      : _totalDistance)
                                                  .toStringAsFixed(2),
                                              style: const TextStyle(
                                                fontSize: 100,
                                                letterSpacing: 4,
                                              ),
                                            ),
                                            Text(
                                              _totalDistance >= 1000
                                                  ? " Km"
                                                  : " M",
                                              style: TextStyle(fontSize: 30),
                                            )
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'Speed',
                                          style: TextStyle(fontSize: 30),
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          textBaseline:
                                              TextBaseline.ideographic,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              ((snapshot.data!.speed! * 18) / 5)
                                                  .toStringAsFixed(1),
                                              style: const TextStyle(
                                                fontSize: 100,
                                                letterSpacing: 4,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            const Text(
                                              ' Km/h',
                                              style: TextStyle(fontSize: 30),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ]),
                              ),
                            ],
                          ),
                        )
                      : const CircularProgressIndicator();
                }),
          ),
        ),
      ),
    );
  }
}
