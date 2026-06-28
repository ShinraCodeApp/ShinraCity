import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../services/image_upload_service.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/shinra_text_field.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  File? _avatarFile;
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = _currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  UserEntity? get _currentUser {
    final state = context.read<AuthBloc>().state;
    return state is AuthAuthenticated ? state.user : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Editar perfil',
          style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated && _saving) {
            setState(() => _saving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Perfil actualizado'),
                backgroundColor: AppColors.success,
              ),
            );
            context.pop();
          }
          if (state is AuthError && _saving) {
            setState(() => _saving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final user = state is AuthAuthenticated ? state.user : null;
          if (user == null) return const SizedBox.shrink();
          return _buildBody(user);
        },
      ),
    );
  }

  Widget _buildBody(UserEntity user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAvatarPicker(user),
            const SizedBox(height: 32),
            _buildSection('Información personal', [
              ShinraTextField(
                controller: _nameController,
                label: 'Nombre completo',
                prefixIcon: Icons.person_outline,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requerido';
                  if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ShinraTextField(
                controller: _phoneController,
                label: 'Teléfono (opcional)',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('Cuenta', [
              _buildReadOnlyTile(
                icon: Icons.email_outlined,
                label: 'Email',
                value: user.email,
                note: 'No se puede cambiar',
              ),
              const SizedBox(height: 12),
              _buildReadOnlyTile(
                icon: Icons.shield_outlined,
                label: 'Proveedor',
                value: _providerLabel(user.authProvider),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('Preferencias', [
              _buildSwitchTile(
                icon: Icons.notifications_outlined,
                label: 'Notificaciones',
                value: user.notificationsEnabled,
                onChanged: (_) {}, // managed via system settings
                readOnly: true,
              ),
              const SizedBox(height: 4),
              _buildSwitchTile(
                icon: Icons.location_on_outlined,
                label: 'Geolocalización',
                value: user.locationEnabled,
                onChanged: (_) {},
                readOnly: true,
              ),
            ]),
            const SizedBox(height: 32),
            GradientButton(
              onPressed: _saving ? null : _save,
              isLoading: _saving,
              child: Text(
                'Guardar cambios',
                style: AppTextStyles.labelLarge
                    .copyWith(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _showDeleteAccountDialog,
              child: Text(
                'Eliminar cuenta',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPicker(UserEntity user) {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickAvatar,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.5), width: 2),
                  color: AppColors.backgroundSurface,
                ),
                child: ClipOval(
                  child: _uploadingAvatar
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary, strokeWidth: 2),
                        )
                      : _avatarFile != null
                          ? Image.file(_avatarFile!, fit: BoxFit.cover)
                          : user.photoUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: user.photoUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      _avatarPlaceholder(user),
                                )
                              : _avatarPlaceholder(user),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ).animate().scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
        const SizedBox(height: 10),
        Text(
          'Cambiar foto',
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _avatarPlaceholder(UserEntity user) {
    final initials = (user.displayName?.isNotEmpty == true)
        ? user.displayName![0].toUpperCase()
        : user.email[0].toUpperCase();
    return Container(
      color: AppColors.backgroundSurface,
      child: Center(
        child: Text(
          initials,
          style: AppTextStyles.headlineMedium
              .copyWith(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondaryDark,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...children,
      ],
    ).animate().fadeIn().slideY(begin: 0.05, end: 0);
  }

  Widget _buildReadOnlyTile({
    required IconData icon,
    required String label,
    required String value,
    String? note,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.backgroundSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondaryDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textSecondaryDark)),
                const SizedBox(height: 2),
                Text(value,
                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
              ],
            ),
          ),
          if (note != null)
            Text(note,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondaryDark)),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool readOnly = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.backgroundSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondaryDark),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: readOnly ? null : onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final svc = GetIt.instance<ImageUploadService>();

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondaryDark.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.photo_camera, color: AppColors.primary),
              ),
              title: Text('Cámara',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final file = await svc.pickFromCamera(maxDim: 400);
                if (file != null && mounted) setState(() => _avatarFile = file);
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.photo_library, color: AppColors.primary),
              ),
              title: Text('Galería',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final file = await svc.pickFromGallery(maxDim: 400);
                if (file != null && mounted) setState(() => _avatarFile = file);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _currentUser;
    if (user == null) return;

    setState(() => _saving = true);

    String? newPhotoUrl;

    if (_avatarFile != null) {
      setState(() => _uploadingAvatar = true);
      try {
        final svc = GetIt.instance<ImageUploadService>();
        newPhotoUrl = await svc.uploadUserAvatar(
          userId: user.id,
          file: _avatarFile!,
        );
      } catch (_) {
        // non-fatal — proceed without updating photo
      } finally {
        if (mounted) setState(() => _uploadingAvatar = false);
      }
    }

    if (!mounted) return;

    context.read<AuthBloc>().add(
          UpdateProfileEvent(
            displayName: _nameController.text.trim(),
            phoneNumber: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            photoUrl: newPhotoUrl,
          ),
        );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: Text(
          '¿Eliminar cuenta?',
          style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
        ),
        content: Text(
          'Esta acción es irreversible. Se eliminarán todos tus datos, cupones y puntos.',
          style:
              AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(DeleteAccountEvent());
            },
            child: Text('Eliminar',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _providerLabel(AuthProvider provider) {
    switch (provider) {
      case AuthProvider.email:
        return 'Email / contraseña';
      case AuthProvider.google:
        return 'Google';
      case AuthProvider.apple:
        return 'Apple';
      case AuthProvider.facebook:
        return 'Facebook';
    }
  }
}
