// ==============================================================================
// GOOGLE PLACES SERVICE
// ==============================================================================
// Provides location autocomplete and place details using Google Places API.
// Requires a valid Google Maps API key with Places API enabled.
// ==============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Represents a place prediction from Google Places Autocomplete
class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final structuredFormatting = json['structured_formatting'] as Map<String, dynamic>? ?? {};
    return PlacePrediction(
      placeId: json['place_id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      mainText: structuredFormatting['main_text'] as String? ?? '',
      secondaryText: structuredFormatting['secondary_text'] as String? ?? '',
    );
  }
}

/// Represents detailed place information from Google Places
class PlaceDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double? latitude;
  final double? longitude;
  final String? phoneNumber;
  final String? website;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    this.latitude,
    this.longitude,
    this.phoneNumber,
    this.website,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;
    
    return PlaceDetails(
      placeId: json['place_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      formattedAddress: json['formatted_address'] as String? ?? '',
      latitude: location?['lat'] as double?,
      longitude: location?['lng'] as double?,
      phoneNumber: json['formatted_phone_number'] as String?,
      website: json['website'] as String?,
    );
  }
}

/// Service for interacting with Google Places API
class PlacesService {
  static final PlacesService _instance = PlacesService._internal();
  factory PlacesService() => _instance;
  PlacesService._internal();

  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';
  
  /// Get the API key from config
  /// You need to add this to your AppConfig
  String get _apiKey => AppConfig.instance.googleMapsApiKey;

  /// Check if Places API is configured
  bool get isConfigured => _apiKey.isNotEmpty;

  /// Search for place predictions based on input text
  Future<List<PlacePrediction>> getAutocompletePredictions(String input) async {
    if (input.isEmpty || !isConfigured) {
      return [];
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/autocomplete/json?input=${Uri.encodeComponent(input)}&key=$_apiKey&types=establishment|geocode',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final predictions = data['predictions'] as List<dynamic>? ?? [];
        
        return predictions
            .map((p) => PlacePrediction.fromJson(p as Map<String, dynamic>))
            .toList();
      } else {
        debugPrint('Places API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Places API exception: $e');
      return [];
    }
  }

  /// Get detailed information about a place
  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    if (placeId.isEmpty || !isConfigured) {
      return null;
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/details/json?place_id=$placeId&key=$_apiKey&fields=place_id,name,formatted_address,geometry,formatted_phone_number,website',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final result = data['result'] as Map<String, dynamic>?;
        
        if (result != null) {
          return PlaceDetails.fromJson(result);
        }
      } else {
        debugPrint('Places Details API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Places Details API exception: $e');
    }
    
    return null;
  }
}
