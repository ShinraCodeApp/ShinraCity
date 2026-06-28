import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_it/get_it.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/commerce_entity.dart';
import '../../../services/image_upload_service.dart';

class RegisterBusinessScreen extends StatefulWidget {
  final String? editCommerceId;
  const RegisterBusinessScreen({super.key, this.editCommerceId});

  bool get isEditing => editCommerceId != null;

  @override
  State<RegisterBusinessScreen> createState() => _RegisterBusinessScreenState();
}

class _RegisterBusinessScreenState extends State<RegisterBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirebaseFirestore.instance;
  final _imageService = GetIt.instance<ImageUploadService>();

  // Controllers
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController(text: 'Argentina');
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _instagram = TextEditingController();
  final _facebook = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();

  CommerceCategory _category = CommerceCategory.restaurants;

  // Images
  File? _logoFile;
  String? _existingLogoUrl;
  List<File> _galleryFiles = [];
  List<String> _existingGalleryUrls = [];

  bool _saving = false;
  bool _loadingLocation = false;
  bool _loadingData = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    setState(() => _loadingData = true);
    try {
      final doc = await _db
          .collection(AppConstants.commercesCollection)
          .doc(widget.editCommerceId)
          .get();
      final data = doc.data();
      if (data == null) return;

      _name.text = data['name'] ?? '';
      _description.text = data['description'] ?? '';
      _address.text = data['address'] ?? '';
      _city.text = data['city'] ?? '';
      _country.text = data['country'] ?? 'Argentina';
      _phone.text = data['phone'] ?? '';
      _whatsapp.text = (data['socialLinks'] as Map?)?.get('whatsapp') ?? '';
      _email.text = data['email'] ?? '';
      _website.text = data['website'] ?? '';
      _instagram.text = (data['socialLinks'] as Map?)?.get('instagram') ?? '';
      _facebook.text = (data['socialLinks'] as Map?)?.get('facebook') ?? '';

      final loc = data['location'] as GeoPoint?;
      if (loc != null) {
        _lat.text = loc.latitude.toString();
        _lng.text = loc.longitude.toString();
      }

      final catStr = data['category'] as String? ?? 'restaurants';
      _category = CommerceCategory.values.firstWhere(
        (c) => c.name == catStr,
        orElse: () => CommerceCategory.restaurants,
      );

      _existingLogoUrl = data['logoUrl'] as String?;
      _existingGalleryUrls =
          (data['galleryUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
    } finally {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _pickLogo() async {
    final picked = await showModalBottomSheet<File?>(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: AppColors.primary),
            title: const Text('Tomar foto', style: TextStyle(color: Colors.white)),
            onTap: () async {
              final f = await _imageService.pickFromCamera();
              Navigator.pop(ctx, f);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: AppColors.primary),
            title: const Text('Elegir de galería', style: TextStyle(color: Colors.white)),
            onTap: () async {
              final f = await _imageService.pickFromGallery();
              Navigator.pop(ctx, f);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
    if (picked != null) setState(() => _logoFile = picked);
  }

  Future<void> _pickGallery() async {
    final remaining = 5 - _galleryFiles.length - _existingGalleryUrls.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo 5 fotos en la galería')),
      );
      return;
    }
    final files = await _imageService.pickMultipleFromGallery(limit: remaining);
    if (files.isNotEmpty) setState(() => _galleryFiles.addAll(files));
  }

  Future<void> _getGpsLocation() async {
    setState(() => _loadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Activá el GPS en tu dispositivo');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Permiso de ubicación denegado');
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _lat.text = pos.latitude.toStringAsFixed(6);
        _lng.text = pos.longitude.toStringAsFixed(6);
      });
      _showSnack('📍 Ubicación obtenida', color: AppColors.success);
    } catch (e) {
      _showSnack('No se pudo obtener la ubicación');
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  void _showSnack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color ?? AppColors.error,
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lat.text.isEmpty || _lng.text.isEmpty) {
      _showSnack('📍 Ingresá las coordenadas o usá el botón GPS');
      return;
    }
    setState(() => _saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final lat = double.parse(_lat.text);
      final lng = double.parse(_lng.text);
      final isCreating = !widget.isEditing;

      String? logoUrl = _existingLogoUrl;
      List<String> galleryUrls = List.from(_existingGalleryUrls);

      final String docId = widget.editCommerceId ??
          _db.collection(AppConstants.commercesCollection).doc().id;

      // Upload logo
      if (_logoFile != null) {
        logoUrl = await _imageService.uploadCommerceLogo(
          commerceId: docId,
          file: _logoFile!,
        );
      }

      // Upload new gallery images
      for (final file in _galleryFiles) {
        final url = await _imageService.uploadCommerceGalleryImage(
          commerceId: docId,
          file: file,
        );
        galleryUrls.add(url);
      }

      // Check if user is admin
      final userDoc = await _db.collection(AppConstants.usersCollection).doc(uid).get();
      final role = userDoc.data()?['role'] as String? ?? 'user';
      final isAdmin = role == 'admin' || role == 'superAdmin';

      final data = {
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'category': _category.name,
        'address': _address.text.trim(),
        'city': _city.text.trim(),
        'country': _country.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'website': _website.text.trim().isEmpty ? null : _website.text.trim(),
        'socialLinks': {
          if (_whatsapp.text.trim().isNotEmpty) 'whatsapp': _whatsapp.text.trim(),
          if (_instagram.text.trim().isNotEmpty) 'instagram': _instagram.text.trim(),
          if (_facebook.text.trim().isNotEmpty) 'facebook': _facebook.text.trim(),
        },
        'location': GeoPoint(lat, lng),
        'geohash': '',
        'logoUrl': logoUrl,
        'galleryUrls': galleryUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isCreating) {
        data.addAll({
          'ownerId': uid,
          'status': isAdmin ? 'active' : 'pending',
          'plan': 'free',
          'subCategories': [],
          'tags': [],
          'businessHours': {},
          'pointsConfig': {},
          'authorizedEmployeeIds': [],
          'rating': 0.0,
          'reviewCount': 0,
          'followerCount': 0,
          'activePromotionsCount': 0,
          'isCurrentlyOpen': true,
          'hasActivePromotion': false,
          'isVerified': isAdmin,
          'isFeatured': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await _db
            .collection(AppConstants.commercesCollection)
            .doc(docId)
            .set(data);
      } else {
        await _db
            .collection(AppConstants.commercesCollection)
            .doc(docId)
            .update(data);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        _showSnack(
          isCreating
              ? isAdmin
                  ? '✅ Negocio creado y activo'
                  : '✅ Negocio enviado para revisión'
              : '✅ Negocio actualizado',
          color: AppColors.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showSnack('Error: $e');
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name, _description, _address, _city, _country,
      _phone, _whatsapp, _email, _website, _instagram, _facebook, _lat, _lng,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundCard,
        title: Text(
          widget.isEditing ? '✏️ Editar Negocio' : '🏪 Registrar Negocio',
          style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(
                'Guardar',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.primary),
              ),
            ),
        ],
      ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLogoSection(),
                    const SizedBox(height: 24),
                    _buildSection(
                      icon: '📋',
                      title: 'Información general',
                      children: [
                        _field(_name, '🏷️ Nombre del negocio', required: true),
                        _field(_description, '📝 Descripción', required: true, maxLines: 3),
                        _categoryDropdown(),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      icon: '📍',
                      title: 'Ubicación',
                      children: [
                        _field(_address, '🏠 Dirección', required: true),
                        _field(_city, '🌆 Ciudad', required: true),
                        _field(_country, '🌎 País'),
                        _coordinatesRow(),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      icon: '📞',
                      title: 'Contacto',
                      children: [
                        _field(_phone, '📱 Teléfono', keyboard: TextInputType.phone),
                        _field(_whatsapp, '💬 WhatsApp (sin código de país: ej. 2645551234)',
                            keyboard: TextInputType.phone),
                        _field(_email, '📧 Email del negocio',
                            keyboard: TextInputType.emailAddress),
                        _field(_website, '🌐 Sitio web', keyboard: TextInputType.url),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      icon: '📲',
                      title: 'Redes sociales',
                      children: [
                        _field(_instagram, '📸 Instagram (usuario sin @)'),
                        _field(_facebook, '👥 Facebook (usuario o URL)'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildGallerySection(),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _saving ? null : _save,
                        child: Text(
                          widget.isEditing ? 'Guardar cambios' : 'Registrar negocio',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLogoSection() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickLogo,
            child: Stack(
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundCard,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: ClipOval(
                    child: _logoFile != null
                        ? Image.file(_logoFile!, fit: BoxFit.cover)
                        : _existingLogoUrl != null
                            ? CachedNetworkImage(
                                imageUrl: _existingLogoUrl!,
                                fit: BoxFit.cover,
                              )
                            : const Icon(
                                Icons.storefront,
                                size: 48,
                                color: AppColors.textSecondaryDark,
                              ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.backgroundDark, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Logo del negocio',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String icon,
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.textSecondaryDark),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1E293B)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1E293B)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
          filled: true,
          fillColor: AppColors.backgroundSurface,
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null
            : null,
      ),
    );
  }

  Widget _categoryDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<CommerceCategory>(
        value: _category,
        dropdownColor: AppColors.backgroundCard,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: '🗂️ Categoría',
          labelStyle: TextStyle(color: AppColors.textSecondaryDark),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1E293B)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
          filled: true,
          fillColor: AppColors.backgroundSurface,
        ),
        items: _categoryItems
            .map((c) => DropdownMenuItem(
                  value: c.$1,
                  child: Text(c.$2, style: const TextStyle(color: Colors.white)),
                ))
            .toList(),
        onChanged: (v) => setState(() => _category = v!),
      ),
    );
  }

  Widget _coordinatesRow() {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TextFormField(
              controller: _lat,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '🌐 Latitud',
                labelStyle: TextStyle(color: AppColors.textSecondaryDark),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1E293B)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                filled: true,
                fillColor: AppColors.backgroundSurface,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TextFormField(
              controller: _lng,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '🌐 Longitud',
                labelStyle: TextStyle(color: AppColors.textSecondaryDark),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1E293B)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                filled: true,
                fillColor: AppColors.backgroundSurface,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _loadingLocation ? null : _getGpsLocation,
            child: _loadingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.my_location, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildGallerySection() {
    final allImages = [
      ..._existingGalleryUrls.map((u) => _GalleryItem(url: u)),
      ..._galleryFiles.map((f) => _GalleryItem(file: f)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🖼️', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              'Fotos del negocio',
              style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
            ),
            const Spacer(),
            Text(
              '${allImages.length}/5',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Add button
              if (allImages.length < 5)
                GestureDetector(
                  onTap: _pickGallery,
                  child: Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.4),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate, color: AppColors.primary, size: 30),
                        SizedBox(height: 4),
                        Text(
                          'Agregar',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Existing images
              ...allImages.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.backgroundCard,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: item.file != null
                            ? Image.file(item.file!, fit: BoxFit.cover)
                            : CachedNetworkImage(
                                imageUrl: item.url!,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          if (i < _existingGalleryUrls.length) {
                            _existingGalleryUrls.removeAt(i);
                          } else {
                            _galleryFiles.removeAt(i - _existingGalleryUrls.length);
                          }
                        }),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  static const _categoryItems = [
    (CommerceCategory.restaurants, '🍽️ Restaurante'),
    (CommerceCategory.cafes, '☕ Cafetería'),
    (CommerceCategory.fastFood, '🍔 Comida Rápida'),
    (CommerceCategory.bar, '🍺 Bar / Pub'),
    (CommerceCategory.bakery, '🥐 Panadería'),
    (CommerceCategory.pharmacies, '💊 Farmacia'),
    (CommerceCategory.health, '🏥 Salud'),
    (CommerceCategory.beauty, '💄 Belleza'),
    (CommerceCategory.clothing, '👕 Ropa / Indumentaria'),
    (CommerceCategory.supermarket, '🛒 Supermercado'),
    (CommerceCategory.hardware, '🔩 Ferretería'),
    (CommerceCategory.jewelry, '💎 Joyería'),
    (CommerceCategory.market, '🏪 Feria / Mercado'),
    (CommerceCategory.streetVendor, '🛍️ Vendedor Ambulante'),
    (CommerceCategory.entrepreneur, '🚀 Emprendimiento'),
    (CommerceCategory.services, '🔧 Servicios generales'),
    (CommerceCategory.automotive, '🚗 Automotriz'),
    (CommerceCategory.education, '📚 Educación'),
    (CommerceCategory.technology, '💻 Tecnología'),
    (CommerceCategory.entertainment, '🎭 Entretenimiento'),
    (CommerceCategory.sports, '⚽ Deportes'),
    (CommerceCategory.tourism, '✈️ Turismo'),
    (CommerceCategory.pets, '🐾 Mascotas'),
    (CommerceCategory.other, '📦 Otros'),
  ];
}

class _GalleryItem {
  final File? file;
  final String? url;
  const _GalleryItem({this.file, this.url});
}

extension on Map {
  dynamic get(String key) => this[key];
}
