import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:app_test/Services/CloudFirestoreMethodes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:places_service/places_service.dart';
import '../MyAppClasses/Utilisateur.dart';
import 'package:http/http.dart' as http;

class DeplacementSurLaCarte extends StatefulWidget {
  String idGroupe;
  String idGroupeOwner ;
  String idOwner ;
  DeplacementSurLaCarte(this.idGroupe,this.idGroupeOwner,this.idOwner);

  @override
  State<DeplacementSurLaCarte> createState() => _DeplacementSurLaCarteState();
}

class _DeplacementSurLaCarteState extends State<DeplacementSurLaCarte> {
  HashSet<Marker> markers = HashSet();
  Position? current_location;
  BitmapDescriptor locationMarker = BitmapDescriptor.defaultMarker;
  final Set<Polyline> _polylineSet = <Polyline>{};
  List<LatLng> polylineCoordinates = [];
  late PolylinePoints polylinePoints;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final CollectionReference utilisateurCollection =
      FirebaseFirestore.instance.collection('Utilisateur');

  //******************************
  List<String> listIdUsers = [];
  String idOwner = '';
  Utilisateur owner = Utilisateur.creerUtilisateurVide();
  List<Utilisateur> resteUsers = [];
  bool _boutonvisible = true;
  bool _isLoading = false;
  PlacesAutoCompleteResult lieuArrivee = PlacesAutoCompleteResult(
      placeId: '', description: '', mainText: '', secondaryText: '');
  String newSnippetOwner = '';
  String newSnippetMember = '';
  bool _trajetEstLancee = false ;
  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  Future<BitmapDescriptor> getMarkerFromAsset(String assetName,
      {int width = 120}) async {
    final ByteData byteData = await rootBundle.load('assets/$assetName');
    final Uint8List markerIconBytes = byteData.buffer.asUint8List();

    ui.Codec codec = await ui.instantiateImageCodec(
      markerIconBytes,
      targetWidth: width,
    );
    ui.FrameInfo fi = await codec.getNextFrame();
    final Uint8List resizedMarkerIconBytes =
        (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();

    return BitmapDescriptor.fromBytes(resizedMarkerIconBytes);
  }

  Future<void> addMarkerFromAsset(
      LatLng position, String nomComplet, String placeActuel) async {
    if (mounted) {
      setState(() {
        markers.add(Marker(
          markerId: const MarkerId('Lieu arrivee'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: '                $nomComplet                ',
            snippet: placeActuel,
          ),
        ));
      });
    }
  }

  Future<Uint8List> getBytesFromNetwork(String url, int width) async {
    http.Response response = await http.get(Uri.parse(url));
    ui.Codec codec = await ui.instantiateImageCodec(
      response.bodyBytes,
      targetWidth: width,
    );
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  Future<void> addMarker(String networkImageUrl, LatLng position,
      String nomComplet, String placeActuel) async {
    final Uint8List markerIconBytes =
        await getBytesFromNetwork(networkImageUrl, 100);
    await getBytesFromNetwork(networkImageUrl, 120).then((value) {
      if (mounted) {
        setState(() {
          markers.add(Marker(
            markerId: MarkerId(networkImageUrl),
            position: LatLng(position.latitude, position.longitude),
            icon: BitmapDescriptor.fromBytes(markerIconBytes),
            infoWindow: InfoWindow(
                title: '                $nomComplet                ',
                snippet: placeActuel),
          ));
        });
      }
    });
  }
  void modifierMarker(
      String markerIdToModify,
      String newTitle,
      LatLng newPosition,
      ) {
    Set<Marker> markersCopy = markers.toSet();
    for (Marker marker in markersCopy) {
      if (marker.markerId.value == markerIdToModify) {
        markers.remove(marker);
        Marker modifiedMarker = Marker(
          markerId: MarkerId(markerIdToModify),
          position: newPosition,
          icon: marker.icon,
          infoWindow: InfoWindow(
            title: '                $newTitle                ',
            snippet: marker.infoWindow.snippet,
          ),
        );
        markers.add(modifiedMarker);
        break;
      }
    }
  }

  void setPolylines(LatLng depart, LatLng arrive) async {
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        "AIzaSyC9sGlH43GL0Jer73n9ETKsxNpZqvrWn-k",
        PointLatLng(depart.latitude, depart.longitude),
        PointLatLng(arrive.latitude, arrive.longitude));
    for (var element in result.points) {
      polylineCoordinates.add(LatLng(element.latitude, element.longitude));
    }
    setState(() {
      _polylineSet.add(Polyline(
        polylineId: const PolylineId("Route"),
        points: polylineCoordinates,
        color: Colors.black,
        width: 5,
      ));
      _polylineSet.add(Polyline(
        polylineId: const PolylineId("background"),
        points: polylineCoordinates,
        color: Colors.blue,
        width: 3,
      ));
      markers.add(Marker(
        // Add a marker for depart
        markerId: const MarkerId('depart'),
        position: depart,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(
          title: 'Votre départ',
        ),
      ));
    });
  }

  Future<PlacesAutoCompleteResult> getPlaceFromLatLng(
      double lat, double lng) async {
    final String url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=AIzaSyC9sGlH43GL0Jer73n9ETKsxNpZqvrWn-k';
    final http.Response response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final decodedJson = jsonDecode(response.body);
      final formattedAddress = decodedJson['results'][0]['formatted_address'];
      final placeId = decodedJson['results'][0]['place_id'];
      final mainText =
          decodedJson['results'][0]['address_components'][0]['long_name'];
      final secondaryText =
          decodedJson['results'][0]['address_components'][1]['long_name'];
      return PlacesAutoCompleteResult(
          placeId: placeId,
          description: formattedAddress,
          mainText: mainText,
          secondaryText: secondaryText);
    } else {
      throw Exception('Failed to load place from API');
    }
  }

  Future<LatLng> getPlaceLatLng(String placeId) async {
    String url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=AIzaSyC9sGlH43GL0Jer73n9ETKsxNpZqvrWn-k';
    var response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      var result = jsonDecode(response.body);
      double lat = result['result']['geometry']['location']['lat'];
      double lng = result['result']['geometry']['location']['lng'];
      return LatLng(lat, lng);
    } else {
      throw Exception('Failed to load place');
    }
  }
  void getUserPlace(LatLng latLngPositionActuel,String placeActuel)async{
    PlacesAutoCompleteResult lieuActuel = await getPlaceFromLatLng(
        latLngPositionActuel.latitude,
        latLngPositionActuel.longitude);
        placeActuel = (lieuActuel.description != null)
        ? lieuActuel.description!
        : '';
  }

  late GoogleMapController mapController;
  LatLng? currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentPosition();
  }

  @override
  void dispose() {
    positionStream?.cancel();
    super.dispose();
  }

  StreamSubscription<Position>? positionStream;

  void _getCurrentPosition() async {
    Geolocator.requestPermission().then((permission) async {
      if (permission == LocationPermission.denied) {
        return;
      }
      positionStream = Geolocator.getPositionStream().listen((position) async {
        currentPosition = LatLng(position.latitude, position.longitude);
        setState(() {
          sauvgarderPositionActuel(position.latitude, position.longitude);
        });
      });
    });
  }

  sauvgarderPositionActuel(double lat, double lng) async {
    await CloudFirestoreMethodes()
        .modifierPositionActuel(auth.currentUser!.uid, LatLng(lat, lng));
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigoAccent[200],
        elevation: 0,
        title: const Align(
          alignment: Alignment.center,
          child: Text(
            'Déplacement sur la carte',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Poppins'),
          ),
        ),
        actions: const [
          IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: Colors.transparent,
                size: 36,
              ),
              onPressed: null),
        ],
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: 36,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: currentPosition == null
          ? Center(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: Colors.white,
                  backgroundColor: Colors.indigoAccent[400],
                ),
                const Text('Veuillez patienter un instant...')
              ],
            ))
          : SafeArea(
              // le premier StreamBuilder pour get les id de chaque utilisateur dans le groupe
              child: StreamBuilder<DocumentSnapshot>(
                stream: utilisateurCollection
                    .doc(widget.idOwner)
                    .collection('Groupes')
                    .doc(widget.idGroupeOwner)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Text('Il n\'existe aucun Groupe');
                  } else {
                    listIdUsers.clear();
                    resteUsers.clear();
                    idOwner = '';
                    if (snapshot.data!.exists) {
                      // get les informations du groupe
                      lieuArrivee = PlacesAutoCompleteResult(
                          placeId: snapshot.data!['lieuArrivee']['placeId'],
                          description: snapshot.data!['lieuArrivee']
                              ['description'],
                          mainText: snapshot.data!['lieuArrivee']['mainText'],
                          secondaryText: snapshot.data!['lieuArrivee']
                              ['secondaryText']);
                      // get le proprietaire du groupe
                      idOwner = snapshot.data!['idOwner'];
                      // get les membres du groupe
                      Map<String, dynamic> membresData = snapshot.data!.data() as Map<String, dynamic>;
                      if (membresData.isNotEmpty){
                        listIdUsers = List<String>.from(membresData['membres']);
                      }
                      listIdUsers.add(idOwner); // to find it in the condition
                      // le 2eme StreamBuilder pour get les utilisateurs qui appartient au ce groupe par les id precedentes
                      return StreamBuilder<QuerySnapshot>(
                        stream: utilisateurCollection.snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Text('Il n\'existe aucun membre');
                          } else {
                            final allUsers = snapshot.data!.docs;
                            for (var u in allUsers) {
                              if (listIdUsers.contains(u['identifiant'])) {
                                if (u.exists) {
                                  Utilisateur utilisateur =
                                      Utilisateur.creerUtilisateurVide();
                                  utilisateur.identifiant = u['identifiant'];
                                  utilisateur.nomComplet = u['nomComplet'];
                                  utilisateur.email = u['email'];
                                  utilisateur.numeroDeTelephone =
                                      u['numeroDeTelephone'];
                                  utilisateur.imageUrl = u['imageUrl'];
                                  GeoPoint geoPointActuel = u['positionActuel'];
                                  utilisateur.positionActuel = LatLng(
                                      geoPointActuel.latitude,
                                      geoPointActuel.longitude);
                                  if (utilisateur.identifiant == idOwner &&
                                      listIdUsers
                                          .contains(utilisateur.identifiant)) {
                                    // si ce utilisateur est le owner
                                    // et il faut qu'il fait partie du groupe
                                    owner = Utilisateur.creerUtilisateurVide();
                                    owner = utilisateur;
                                    if (_trajetEstLancee){
                                       modifierMarker(owner.imageUrl, owner.nomComplet, owner.positionActuel);
                                    }
                                  } else if (utilisateur.identifiant !=
                                          idOwner &&
                                      listIdUsers
                                          .contains(utilisateur.identifiant)) {
                                    // si ce utilisateur est un membre
                                    // et il faut qu'il fait partie du groupe
                                    resteUsers.add(utilisateur);
                                    if (_trajetEstLancee){
                                      modifierMarker(utilisateur.imageUrl, utilisateur.nomComplet, utilisateur.positionActuel);
                                    }
                                  }
                                }
                              }
                            }
                            return GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: currentPosition!,
                                zoom: 14.0,
                              ),
                              myLocationEnabled: true,
                              myLocationButtonEnabled: true,
                              markers: Set.from(markers),
                              onMapCreated: (GoogleMapController controller) {
                                mapController = controller;
                              },
                              polylines: _polylineSet,
                            );
                          }
                        },
                      );
                    } else {
                      return const SizedBox(width: 0, height: 0);
                    }
                  }
                },
              ),
            ),
      floatingActionButton: Visibility(
        visible: _boutonvisible && currentPosition != null,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent[400],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(60))),
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });

              /// 1) set a marker to the owner
              if (idOwner != auth.currentUser!.uid) {
                // vous avez deja la marke
                String placeActuelOwner = '';
                LatLng latLngPositionActuelOwner = LatLng(
                    owner.positionActuel.latitude,
                    owner.positionActuel.longitude);
                PlacesAutoCompleteResult lieuActuel = PlacesAutoCompleteResult(
                    placeId: '',
                    description: '',
                    mainText: '',
                    secondaryText: '');
                lieuActuel = await getPlaceFromLatLng(
                    latLngPositionActuelOwner.latitude,
                    latLngPositionActuelOwner.longitude);
                placeActuelOwner = (lieuActuel.description != null)
                    ? lieuActuel.description!
                    : '';
                addMarker(owner.imageUrl, owner.positionActuel,
                    '${owner.nomComplet} (Le propriétaire)', placeActuelOwner);
              }

              /// 2) set makers to the membres
              for (Utilisateur utilisateur in resteUsers) {
                if (utilisateur.identifiant != auth.currentUser!.uid) {
                  String placeActuel = '';
                  LatLng latLngPositionActuel = LatLng(
                      utilisateur.positionActuel.latitude,
                      utilisateur.positionActuel.longitude);
                  PlacesAutoCompleteResult lieuActuel =
                      PlacesAutoCompleteResult(
                          placeId: '',
                          description: '',
                          mainText: '',
                          secondaryText: '');
                  lieuActuel = await getPlaceFromLatLng(
                      latLngPositionActuel.latitude,
                      latLngPositionActuel.longitude);
                  placeActuel = (lieuActuel.description != null)
                      ? lieuActuel.description!
                      : '';
                  addMarker(utilisateur.imageUrl, utilisateur.positionActuel,
                      utilisateur.nomComplet, placeActuel);
                }
              }

              /// 3) set the marker to the lieuArrivee
              /// get LatLng from PlacesAutoCompleteResult
              LatLng latlngArrivee = await getPlaceLatLng(lieuArrivee.placeId!);
              addMarkerFromAsset(
                  latlngArrivee, 'Lieu d\'arrivée', lieuArrivee.description!);
              polylinePoints = PolylinePoints();
              setPolylines(
                  LatLng(currentPosition!.latitude, currentPosition!.longitude),
                  latlngArrivee);
              setState(() {
                _isLoading = false;
                _boutonvisible = false;
                _trajetEstLancee = true;
              });
            },
            child: SizedBox(
              width: screenWidth / 2,
              height: 60,
              child: Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: (!_isLoading)
                      ? const Text(
                          'Commencer le trajet',
                          style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Poppins',
                              color: Colors.white),
                        )
                      : const CircularProgressIndicator(
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
