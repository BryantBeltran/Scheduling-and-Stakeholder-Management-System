import 'dart:async';
import 'package:flutter/material.dart';
import '../services/places_service.dart';

/// A text field with Google Places autocomplete functionality
/// 
/// Provides location suggestions as the user types and allows
/// selecting a place to auto-fill address details.
class LocationAutocompleteField extends StatefulWidget {
  /// Initial value for the location field
  final String? initialValue;
  
  /// Callback when a location is selected
  final ValueChanged<PlaceDetails>? onPlaceSelected;
  
  /// Callback when the text changes (even without selecting a place)
  final ValueChanged<String>? onChanged;
  
  /// Text field decoration
  final InputDecoration? decoration;
  
  /// Form field validator
  final String? Function(String?)? validator;
  
  /// Controller for the text field
  final TextEditingController? controller;
  
  /// Whether the field is enabled
  final bool enabled;

  const LocationAutocompleteField({
    super.key,
    this.initialValue,
    this.onPlaceSelected,
    this.onChanged,
    this.decoration,
    this.validator,
    this.controller,
    this.enabled = true,
  });

  @override
  State<LocationAutocompleteField> createState() => _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState extends State<LocationAutocompleteField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  
  OverlayEntry? _overlayEntry;
  List<PlacePrediction> _predictions = [];
  bool _isLoading = false;
  Timer? _debounce;
  
  final PlacesService _placesService = PlacesService();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController(text: widget.initialValue);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _removeOverlay();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _removeOverlay();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay() {
    _removeOverlay();
    
    if (_predictions.isEmpty && !_isLoading) return;
    
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    
    // Calculate available space below and above the text field
    final screenHeight = MediaQuery.of(context).size.height;
    final spaceBelow = screenHeight - offset.dy - size.height;
    final spaceAbove = offset.dy;
    
    // Determine if dropdown should appear above or below
    final showAbove = spaceBelow < 250 && spaceAbove > spaceBelow;
    final maxHeight = showAbove 
        ? (spaceAbove - 8).clamp(100.0, 250.0)
        : (spaceBelow - 8).clamp(100.0, 250.0);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: showAbove 
              ? Offset(0, -(maxHeight + 4))
              : Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: _buildPredictionsList(),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  Widget _buildPredictionsList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_predictions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No results found'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _predictions.length,
      itemBuilder: (context, index) {
        final prediction = _predictions[index];
        return ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: Text(
            prediction.mainText,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            prediction.secondaryText,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          onTap: () => _selectPlace(prediction),
        );
      },
    );
  }

  Future<void> _onTextChanged(String value) async {
    widget.onChanged?.call(value);
    
    // Cancel previous debounce timer
    _debounce?.cancel();
    
    if (value.length < 3) {
      setState(() {
        _predictions = [];
        _isLoading = false;
      });
      _removeOverlay();
      return;
    }

    // Debounce API calls to avoid too many requests
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      
      setState(() {
        _isLoading = true;
      });
      _showOverlay();

      try {
        final predictions = await _placesService.getAutocompletePredictions(value);
        if (!mounted) return;
        
        setState(() {
          _predictions = predictions;
          _isLoading = false;
        });
        _showOverlay();
      } catch (e) {
        if (!mounted) return;
        
        setState(() {
          _predictions = [];
          _isLoading = false;
        });
        _removeOverlay();
      }
    });
  }

  Future<void> _selectPlace(PlacePrediction prediction) async {
    _removeOverlay();
    
    // Update the text field with the selected place
    _controller.text = prediction.description;
    
    // Fetch place details
    try {
      final details = await _placesService.getPlaceDetails(prediction.placeId);
      if (details != null) {
        widget.onPlaceSelected?.call(details);
      }
    } catch (e) {
      // If we can't get details, at least pass the description
      widget.onPlaceSelected?.call(PlaceDetails(
        placeId: prediction.placeId,
        name: prediction.mainText,
        formattedAddress: prediction.description,
      ));
    }
    
    // Clear predictions
    setState(() {
      _predictions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        decoration: widget.decoration ?? const InputDecoration(
          labelText: 'Location',
          hintText: 'Start typing to search...',
          prefixIcon: Icon(Icons.location_on_outlined),
        ),
        onChanged: _onTextChanged,
        validator: widget.validator,
      ),
    );
  }
}
