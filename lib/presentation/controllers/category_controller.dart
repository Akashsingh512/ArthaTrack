import 'package:flutter/foundation.dart';
import '../../data/repositories/category_repository.dart';

class CategoryController extends ChangeNotifier {
  final CategoryRepository _repo;

  List<String> _categories = List.from(CategoryRepository.defaultCategories);
  List<Map<String, dynamic>> _categoriesWithMeta = [];
  bool _isLoading = false;

  CategoryController({CategoryRepository? repo})
      : _repo = repo ?? CategoryRepository();

  List<String> get categories => _categories;
  List<Map<String, dynamic>> get categoriesWithMeta => _categoriesWithMeta;
  bool get isLoading => _isLoading;

  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();

    try {
      _categories = await _repo.getAllCategoryNames();
      _categoriesWithMeta = await _repo.getCategoriesWithMeta();
    } catch (e) {
      print('Error loading categories: $e');
      _categories = List.from(CategoryRepository.defaultCategories);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addCategory(String name, {String? icon}) async {
    final success = await _repo.addCustomCategory(name, icon: icon);
    if (success) {
      await loadCategories();
    }
    return success;
  }

  Future<bool> deleteCategory(String name) async {
    final success = await _repo.deleteCategory(name);
    if (success) {
      await loadCategories();
    }
    return success;
  }
}
