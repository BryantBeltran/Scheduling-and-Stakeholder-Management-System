enum Flavor {
  dev,
  prod,
}

class FlavorConfig {
  final Flavor flavor;
  final String name;
  final bool useMockData;
  final bool useFirebase;
  
  static FlavorConfig? _instance;
  
  factory FlavorConfig({
    required Flavor flavor,
    required String name,
    required bool useMockData,
    required bool useFirebase,
  }) {
    _instance ??= FlavorConfig._internal(
      flavor,
      name,
      useMockData,
      useFirebase,
    );
    return _instance!;
  }
  
  FlavorConfig._internal(
    this.flavor,
    this.name,
    this.useMockData,
    this.useFirebase,
  );
  
  static FlavorConfig get instance {
    return _instance ?? FlavorConfig(
      flavor: Flavor.dev,
      name: 'Development',
      useMockData: true,
      useFirebase: false,
    );
  }
  
  static bool get isDevelopment => instance.flavor == Flavor.dev;
  static bool get isProduction => instance.flavor == Flavor.prod;
}
