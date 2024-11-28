class InventoryData {
  // Clothing Types (categories and subcategories)
  final Map<String, List<String>> clothingTypes = {
    'Uniform': ['Senior High', 'College'],
    'Proware Shirt': ['Proware Shirt'],
    'Merch & Accessories': ['Merch & Accessories'],
  };

  // Senior High and College Uniforms
  final Map<String, List<String>> shsUniforms = {
    'Senior High': [
      'BLOUSE WITH VEST',
      'POLO WITH VEST',
      'HM SKIRT',
      'HS PANTS',
      'HRM-CHECKERED PANTS FEMALE',
      'HRM CHEF\'S POLO FEMALE',
      'HRM CHEF\'S POLO MALE',
      'HRM-CHECKERED PANTS MALE',
      'HS PE SHIRT',
      'HS PE PANTS',
    ]
  };

  final Map<String, List<String>> collegeUniforms = {
    'College': [
      'IT 3/4 BLOUSE',
      'IT 3/4 POLO',
      'FEMALE BLAZER',
      'MALE BLAZER',
      'HRM BLOUSE',
      'HRM POLO',
      'HRM VEST FEMALE',
      'HRM VEST MALE',
      'RTW SKIRT',
      'RTW FEMALE PANTS',
      'RTW MALE PANTS',
      'CHEF\'S POLO',
      'CHEF\'S PANTS',
      'TM FEMALE BLOUSE',
      'TM FEMALE BLAZER',
      'TM SKIRT',
      'TM MALE POLO',
      'TM MALE BLAZER',
      'BM/AB COMM BLOUSE',
      'BM/AB COMM POLO',
      'PE SHIRT',
      'PE PANTS',
      'WASHDAY SHIRT',
      'NSTP SHIRT',
      'NECKTIE',
      'SCARF',
      'FABRIC SPECIAL SIZE',
    ]
  };

  // Price Options for Uniforms
  final Map<String, Map<String, double>> priceOptions = {
    // SHS Uniforms
    'BLOUSE WITH VEST': {
      'Small': 600.00,
      'Medium': 600.00,
      'Large': 600.00,
      'XL': 600.00,
      '2XL': 600.00,
      '3XL': 600.00,
      '4XL': 910.00,
      '5XL': 910.00,
      '6XL': 910.00,
      '7XL': 910.00,
    },
    'POLO WITH VEST': {
      'Small': 620.00,
      'Medium': 620.00,
      'Large': 620.00,
      'XL': 655.00,
      '2XL': 655.00,
      '3XL': 655.00,
      '4XL': 950.00,
      '5XL': 950.00,
      '6XL': 950.00,
      '7XL': 950.00,
    },
    'HM SKIRT': {
      'Small': 275.00,
      'Medium': 275.00,
      'Large': 275.00,
      'XL': 275.00,
      '2XL': 290.00,
      '3XL': 290.00,
      '5XL': 290.00,
    },
    'HS PANTS': {
      'Small': 415.00,
      'Medium': 415.00,
      'Large': 440.00,
      'XL': 440.00,
      '2XL': 440.00,
      '3XL': 470.00,
    },
    'HRM-CHECKERED PANTS FEMALE': {
      'Medium': 250.00,
      'Large': 250.00,
      'XL': 250.00,
      '2XL': 250.00,
      '3XL': 250.00,
    },
    'HRM-CHECKERED PANTS MALE': {
      'XS': 265.00,
      'Small': 265.00,
      'Medium': 265.00,
      'Large': 265.00,
      'XL': 265.00,
      '2XL': 265.00,
      '3XL': 265.00,
    },
    'HRM CHEF\'S POLO FEMALE': {
      'Small': 375.00,
      'Medium': 375.00,
      'Large': 375.00,
      'XL': 375.00,
      '2XL': 375.00,
      '3XL': 375.00,
    },
    'HRM CHEF\'S POLO MALE': {
      'XS': 400.00,
      'Small': 400.00,
      'Medium': 400.00,
      'Large': 400.00,
      'XL': 400.00,
      '2XL': 400.00,
      '3XL': 400.00,
    },
    'HS PE SHIRT': {
      'XS': 175.00,
      'Small': 175.00,
      'Medium': 175.00,
      'Large': 175.00,
      'XL': 175.00,
      '2XL': 175.00,
      '3XL': 200.00,
      '5XL': 230.00,
    },
    'HS PE PANTS': {
      'Small': 340.00,
      'Medium': 340.00,
      'Large': 340.00,
      'XL': 340.00,
      '2XL': 360.00,
      '3XL': 360.00,
      '5XL': 415.00,
    },

    // College Uniforms
    'IT 3/4 BLOUSE': {
      'Small': 380.00,
      'Medium': 380.00,
      'Large': 380.00,
      'XL': 380.00,
      '2XL': 380.00,
      '3XL': 380.00,
    },
    'IT 3/4 POLO': {
      'Small': 390.00,
      'Medium': 390.00,
      'Large': 390.00,
      'XL': 390.00,
      '2XL': 390.00,
      '3XL': 390.00,
    },
    'FEMALE BLAZER': {
      'Small': 720.00,
      'Medium': 720.00,
      'Large': 720.00,
      'XL': 840.00,
      '2XL': 840.00,
      '3XL': 840.00,
    },
    'MALE BLAZER': {
      'Small': 750.00,
      'Medium': 750.00,
      'Large': 750.00,
      'XL': 870.00,
      '2XL': 870.00,
      '3XL': 870.00,
    },
    'HRM BLOUSE': {
      'Small': 360.00,
      'Medium': 360.00,
      'Large': 360.00,
      'XL': 360.00,
      '2XL': 360.00,
      '3XL': 360.00,
    },
    'HRM POLO': {
      'Small': 380.00,
      'Medium': 380.00,
      'Large': 380.00,
      'XL': 380.00,
      '2XL': 380.00,
      '3XL': 380.00,
    },
    'HRM VEST FEMALE': {
      'Small': 350.00,
      'Medium': 350.00,
      'Large': 350.00,
      'XL': 350.00,
      '2XL': 350.00,
      '3XL': 350.00,
    },
    'HRM VEST MALE': {
      'Small': 380.00,
      'Medium': 380.00,
      'Large': 380.00,
      'XL': 390.00,
      '2XL': 405.00,
      '3XL': 405.00,
    },
    'RTW SKIRT': {
      'Small': 195.00,
      'Medium': 195.00,
      'Large': 195.00,
      'XL': 195.00,
      '2XL': 195.00,
      '3XL': 195.00,
    },
    'RTW FEMALE PANTS': {
      'Small': 442.00,
      'Medium': 442.00,
      'Large': 442.00,
      'XL': 442.00,
      '2XL': 442.00,
      '3XL': 442.00,
    },
    'RTW MALE PANTS': {
      'Small': 450.00,
      'Medium': 450.00,
      'Large': 450.00,
      'XL': 450.00,
      '2XL': 450.00,
      '3XL': 450.00,
    },
    'CHEF\'S POLO': {
      'XS': 360.00,
      'Small': 360.00,
      'Medium': 360.00,
      'Large': 360.00,
      'XL': 360.00,
      '2XL': 360.00,
      '3XL': 360.00,
    },
    'CHEF\'S PANTS': {
      'XS': 305.00,
      'Small': 305.00,
      'Medium': 305.00,
      'Large': 305.00,
      'XL': 305.00,
      '2XL': 305.00,
      '3XL': 305.00,
    },
    'TM FEMALE BLOUSE': {
      'Small': 365.00,
      'Medium': 365.00,
      'Large': 365.00,
      'XL': 365.00,
      '3XL': 365.00,
    },
    'TM FEMALE BLAZER': {
      'Small': 750.00,
      'Medium': 750.00,
      'Large': 750.00,
      'XL': 750.00,
      '3XL': 750.00,
    },
    'TM SKIRT': {
      'Small': 240.00,
      'Medium': 240.00,
      'Large': 240.00,
      'XL': 240.00,
      '3XL': 240.00,
    },
    'TM MALE POLO': {
      'Small': 375.00,
      'Medium': 375.00,
      'Large': 375.00,
      'XL': 375.00,
    },
    'TM MALE BLAZER': {
      'Small': 780.00,
      'Medium': 780.00,
      'Large': 780.00,
      'XL': 780.00,
    },
    'TM CLOTH PANTS': {
      'M 1yard': 330.00,
      'XL 1.5yard': 345.00,
      '3XL 2yard': 390.00,
    },
    'BM/AB COMM BLOUSE': {
      'Small': 365.00,
      'Medium': 365.00,
      'Large': 365.00,
      'XL': 365.00,
      '2XL': 365.00,
      '3XL': 365.00,
    },
    'BM/AB COMM POLO': {
      'Small': 395.00,
      'Medium': 395.00,
      'Large': 395.00,
      'XL': 395.00,
      '2XL': 395.00,
      '3XL': 395.00,
    },
    'PE SHIRT': {
      'XS': 175.00,
      'Small': 175.00,
      'Medium': 175.00,
      'Large': 175.00,
      'XL': 175.00,
      '2XL': 175.00,
      '3XL': 175.00,
      '5XL': 195.00,
    },
    'PE PANTS': {
      'XS': 310.00,
      'Small': 310.00,
      'Medium': 310.00,
      'Large': 310.00,
      'XL': 310.00,
      '2XL': 310.00,
      '3XL': 310.00,
      '5XL': 310.00,
    },
    'WASHDAY SHIRT': {
      'Small': 220.00,
      'Medium': 220.00,
      'Large': 220.00,
      'XL': 220.00,
      '2XL': 220.00,
      '3XL': 220.00,
      '5XL': 245.00,
    },
    'NSTP SHIRT': {
      'XS': 210.00,
      'Small': 210.00,
      'Medium': 210.00,
      'Large': 210.00,
      'XL': 210.00,
      '2XL': 230.00,
      '3XL': 230.00,
      '5XL': 250.00,
    },
    'NECKTIE': {
      'AB/COMM': 125.00,
      'BM': 125.00,
      'TM': 140.00,
      'CRIM': 130.00,
    },
    'SCARF': {
      'AB/COMM': 70.00,
      'BM': 70.00,
      'TM': 70.00,
    },
    'FABRIC SPECIAL SIZE': {
      'CHEF\'S PANTS FABRIC 2.5 yards': 400.00,
      'CHEF\'S POLO FABRIC 2.5 yards': 470.00,
      'HRM FABRIC 3 yards': 410.00,
      'HRM VEST FABRIC 2.5 yards': 300.00,
      'IT FABRIC 2.5 yards': 380.00,
      'ABCOMM/BM FABRIC 2.5 yards': 400.00,
      'PANTS FABRIC 2.5 yards': 260.00,
      'BLAZER FABRIC 2.75 yards': 740.00,
      'TOURISM BLAZER FABRIC 2.5 yards': 400.00,
      'TOURISM PANTS FABRIC 2.5 yards': 400.00,
      'TOURISM POLO FABRIC 2.5 yards': 295.00,
    },
  };

  // Get Categories
  List<String> getCategories() {
    return clothingTypes.keys.toList();
  }

  // Get Subcategories by Category
  List<String>? getSubcategories(String category) {
    return clothingTypes[category];
  }

  // Get Senior High Uniforms
  List<String>? getSHSUniforms() {
    return shsUniforms['Senior High'];
  }

  // Get College Uniforms
  List<String>? getCollegeUniforms() {
    return collegeUniforms['College'];
  }

  // Get Uniforms by Category
  List<String>? getUniformsByCategory(String category) {
    if (category == 'Senior High') {
      return getSHSUniforms();
    } else if (category == 'College') {
      return getCollegeUniforms();
    }
    return null;
  }

  // Get Price Options for a Uniform
  Map<String, double>? getPriceOptions(String uniformName) {
    return priceOptions[uniformName];
  }
}
