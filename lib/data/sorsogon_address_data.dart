// lib/data/sorsogon_address_data.dart
//
// SORSOGON SECOND CONGRESSIONAL DISTRICT ADDRESS DATA
//
// Source:
// Philippine Statistics Authority (PSA)
// Philippine Standard Geographic Code (PSGC)
// Latest publication: PSGC as of 30 June 2026
//
// Second Congressional District:
// 1. Barcelona
// 2. Bulan
// 3. Bulusan
// 4. Gubat
// 5. Irosin
// 6. Juban
// 7. Matnog
// 8. Prieto Diaz
// 9. Santa Magdalena
//
// Current PSA barangay count for these nine municipalities:
// 281 barangays.
//
// This file is intentionally kept separate from the UI screens
// so the same address data can be used by:
// - Registration
// - Consumer Dashboard
// - Consumer Profile
// - Edit Profile
// - Other address forms

const String sorsogonProvince = 'Sorsogon';

const String sorsogonSecondDistrict = '2nd District';

/// Municipalities belonging to the Sorsogon 2nd Congressional District.
const List<String> sorsogonSecondDistrictMunicipalities = [
  'Barcelona',
  'Bulan',
  'Bulusan',
  'Gubat',
  'Irosin',
  'Juban',
  'Matnog',
  'Prieto Diaz',
  'Santa Magdalena',
];

/// Municipality -> Barangays
///
/// Based on the current PSA PSGC barangay listings.
const Map<String, List<String>> sorsogonSecondDistrictBarangays = {
  // ============================================================
  // BARCELONA
  // 22 BARANGAYS
  // ============================================================
  'Barcelona': [
    'Aguitap',
    'Bagbag',
    'Bagbago',
    'Barcelona',
    'Bubuos',
    'Capurictan',
    'Catangraran',
    'Darasdas',
    'Juan',
    'Laureta',
    'Lipay',
    'Maananteng',
    'Manalpac',
    'Mariquet',
    'Nagpatpatan',
    'Nalasin',
    'Puttao',
    'San Juan',
    'San Julian',
    'Santa Ana',
    'Santiago',
    'Talugtog',
  ],

  // ============================================================
  // BULAN
  // 63 BARANGAYS
  // ============================================================
  'Bulan': [
    'A. Bonifacio',
    'Abad Santos',
    'Aguinaldo',
    'Antipolo',
    'Zone I Pob.',
    'Zone II Pob.',
    'Zone III Pob.',
    'Zone IV Pob.',
    'Zone V Pob.',
    'Zone VI Pob.',
    'Bical',
    'Beguin',
    'Bonga',
    'Butag',
    'Cadandanan',
    'Calomagon',
    'Calpi',
    'Cocok-Cabitan',
    'Daganas',
    'Danao',
    'Dolos',
    'E. Quirino',
    'Fabrica',
    'Gate',
    'Benigno S. Aquino',
    'Inararan',
    'J. Gerona',
    'Jamorawon',
    'Libertad',
    'Lajong',
    'Magsaysay',
    'Managanaga',
    'Marinab',
    'Nasuje',
    'Montecalvario',
    'N. Roque',
    'Namo',
    'Obrero',
    'Osmeña',
    'Otavi',
    'Padre Diaz',
    'Palale',
    'J.P. Laurel',
    'Quezon',
    'R. Gerona',
    'Recto',
    'M. Roxas',
    'Sagrada',
    'San Francisco',
    'San Isidro',
    'San Juan Bag-o',
    'San Juan Daan',
    'San Rafael',
    'San Ramon',
    'San Vicente',
    'Santa Remedios',
    'Santa Teresita',
    'Sigad',
    'Somagongsong',
    'G. Del Pilar',
    'Taromata',
    'Zone VII Pob.',
    'Zone VIII Pob.',
  ],

  // ============================================================
  // BULUSAN
  // 24 BARANGAYS
  // ============================================================
  'Bulusan': [
    'Bagacay',
    'Central',
    'Cogon',
    'Dancalan',
    'Dapdap',
    'Lalud',
    'Looban',
    'Mabuhay',
    'Madlawon',
    'Poctol',
    'Porog',
    'Sabang',
    'Salvacion',
    'San Antonio',
    'San Bernardo',
    'San Francisco',
    'San Isidro',
    'San Jose',
    'San Rafael',
    'San Roque',
    'San Vicente',
    'Santa Barbara',
    'Sapngan',
    'Tinampo',
  ],

  // ============================================================
  // GUBAT
  // 42 BARANGAYS
  // ============================================================
  'Gubat': [
    'Ariman',
    'Bagacay',
    'Balud Del Norte',
    'Balud Del Sur',
    'Benguet',
    'Bentuco',
    'Beriran',
    'Buenavista',
    'Bulacao',
    'Cabigaan',
    'Cabiguhan',
    'Carriedo',
    'Casili',
    'Cogon',
    'Cota Na Daco',
    'Dita',
    'Jupi',
    'Lapinig',
    'Luna-Candol',
    'Manapao',
    'Manook',
    'Naagtan',
    'Nato',
    'Nazareno',
    'Ogao',
    'Paco',
    'Panganiban',
    'Paradijon',
    'Patag',
    'Payawin',
    'Pinontingan',
    'Rizal',
    'San Ignacio',
    'Sangat',
    'Santa Ana',
    'Tabi',
    'Tagaytay',
    'Tigkiw',
    'Tiris',
    'Togawe',
    'Union',
    'Villareal',
  ],

  // ============================================================
  // IROSIN
  // 28 BARANGAYS
  // ============================================================
  'Irosin': [
    'Bagsangan',
    'Bacolod',
    'Batang',
    'Bolos',
    'Buenavista',
    'Bulawan',
    'Carriedo',
    'Casini',
    'Cawayan',
    'Cogon',
    'Gabao',
    'Gulang-Gulang',
    'Gumapia',
    'Santo Domingo',
    'Liang',
    'Macawayan',
    'Mapaso',
    'Monbon',
    'Patag',
    'Salvacion',
    'San Agustin',
    'San Isidro',
    'San Juan',
    'San Julian',
    'San Pedro',
    'Tabon-Tabon',
    'Tinampo',
    'Tongdol',
  ],

  // ============================================================
  // JUBAN
  // 25 BARANGAYS
  // ============================================================
  'Juban': [
    'Anog',
    'Aroroy',
    'Bacolod',
    'Binanuahan',
    'Biriran',
    'Buraburan',
    'Calateo',
    'Calmayon',
    'Carohayon',
    'Catanagan',
    'Catanusan',
    'Cogon',
    'Embarcadero',
    'Guruyan',
    'Lajong',
    'Maalo',
    'North Poblacion',
    'South Poblacion',
    'Puting Sapa',
    'Rangas',
    'Sablayan',
    'Sipaya',
    'Taboc',
    'Tinago',
    'Tughan',
  ],

  // ============================================================
  // MATNOG
  // 40 BARANGAYS
  // ============================================================
  'Matnog': [
    'Balocawe',
    'Banogao',
    'Banuangdaan',
    'Bariis',
    'Bolo',
    'Bon-Ot Big',
    'Bon-Ot Small',
    'Cabagahan',
    'Calayuan',
    'Calintaan',
    'Caloocan',
    'Calpi',
    'Camachiles',
    'Camcaman',
    'Coron-coron',
    'Culasi',
    'Gadgaron',
    'Genablan Occidental',
    'Genablan Oriental',
    'Hidhid',
    'Laboy',
    'Lajong',
    'Mambajog',
    'Manjunlad',
    'Manurabi',
    'Naburacan',
    'Paghuliran',
    'Pangi',
    'Pawa',
    'Poropandan',
    'Santa Isabel',
    'Sinalmacan',
    'Sinang-Atan',
    'Sinibaran',
    'Sisigon',
    'Sua',
    'Sulangan',
    'Tablac',
    'Tabunan',
    'Tugas',
  ],

  // ============================================================
  // PRIETO DIAZ
  // 23 BARANGAYS
  // ============================================================
  'Prieto Diaz': [
    'Brillante',
    'Bulawan',
    'Calao',
    'Carayat',
    'Diamante',
    'Gogon',
    'Lupi',
    'Manlabong',
    'Maningcay De Oro',
    'Perlas',
    'Quidolog',
    'Rizal',
    'San Antonio',
    'San Fernando',
    'San Isidro',
    'San Juan',
    'San Rafael',
    'San Ramon',
    'Santa Lourdes',
    'Santo Domingo',
    'Talisayan',
    'Tupaz',
    'Ulag',
  ],

  // ============================================================
  // SANTA MAGDALENA
  // 14 BARANGAYS
  // ============================================================
  'Santa Magdalena': [
    'La Esperanza',
    'Peñafrancia',
    'Barangay Poblacion I',
    'Barangay Poblacion II',
    'Barangay Poblacion III',
    'Barangay Poblacion IV',
    'Salvacion',
    'San Antonio',
    'San Bartolome',
    'San Eugenio',
    'San Isidro',
    'San Rafael',
    'San Roque',
    'San Sebastian',
  ],
};

/// Returns the municipalities available in the Sorsogon 2nd District.
List<String> getSorsogonSecondDistrictMunicipalities() {
  return List.unmodifiable(
    sorsogonSecondDistrictMunicipalities,
  );
}

/// Returns the barangays for a selected municipality.
List<String> getBarangaysForMunicipality(
  String? municipality,
) {
  if (municipality == null || municipality.isEmpty) {
    return [];
  }

  return List.unmodifiable(
    sorsogonSecondDistrictBarangays[municipality] ?? [],
  );
}

/// Returns all barangays across the nine municipalities.
List<String> getAllSorsogonSecondDistrictBarangays() {
  return sorsogonSecondDistrictBarangays.values
      .expand((barangays) => barangays)
      .toList();
}

/// Creates a complete readable address.
String buildSorsogonAddress({
  required String municipality,
  required String barangay,
}) {
  return '$barangay, $municipality, Sorsogon';
}

/// Validates whether a municipality belongs to the 2nd District.
bool isValidSorsogonSecondDistrictMunicipality(
  String municipality,
) {
  return sorsogonSecondDistrictMunicipalities
      .contains(municipality);
}

/// Validates whether a barangay belongs to a specific municipality.
bool isValidBarangayForMunicipality({
  required String municipality,
  required String barangay,
}) {
  final barangays =
      sorsogonSecondDistrictBarangays[municipality];

  if (barangays == null) {
    return false;
  }

  return barangays.contains(barangay);
}