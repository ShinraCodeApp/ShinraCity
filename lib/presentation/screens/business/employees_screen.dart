import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/commerce_repository.dart';

class EmployeesScreen extends StatefulWidget {
  final String commerceId;

  const EmployeesScreen({super.key, required this.commerceId});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final _commerceRepo = GetIt.instance<CommerceRepository>();
  final _authRepo = GetIt.instance<AuthRepository>();

  bool _loading = true;
  String? _error;
  final List<UserEntity> _employees = [];
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _employees.clear();
    });

    final result = await _commerceRepo.getCommerce(widget.commerceId);
    if (!mounted) return;

    await result.fold(
      (f) async => setState(() {
        _error = f.message;
        _loading = false;
      }),
      (commerce) async {
        final futures = commerce.authorizedEmployeeIds
            .map((id) => _authRepo.getUserById(id));
        final results = await Future.wait(futures);
        if (!mounted) return;
        for (final r in results) {
          r.fold((_) => null, (u) {
            if (u != null) _employees.add(u);
          });
        }
        setState(() => _loading = false);
      },
    );
  }

  Future<void> _addEmployee() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _loading = true);

    final lookupResult = await _authRepo.getUserByEmail(email);
    if (!mounted) return;

    await lookupResult.fold(
      (f) async {
        setState(() => _loading = false);
        _showError('Error al buscar usuario: ${f.message}');
      },
      (user) async {
        if (user == null) {
          setState(() => _loading = false);
          _showError('No existe un usuario con ese email');
          return;
        }
        if (_employees.any((e) => e.id == user.id)) {
          setState(() => _loading = false);
          _showError('Este usuario ya es empleado');
          return;
        }
        final addResult = await _commerceRepo.addEmployee(
          commerceId: widget.commerceId,
          employeeId: user.id,
        );
        if (!mounted) return;
        addResult.fold(
          (f) {
            setState(() => _loading = false);
            _showError('Error al agregar empleado: ${f.message}');
          },
          (_) {
            _emailController.clear();
            _load();
          },
        );
      },
    );
  }

  Future<void> _removeEmployee(UserEntity employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: Text(
          'Eliminar empleado',
          style: AppTextStyles.titleSmall.copyWith(color: Colors.white),
        ),
        content: Text(
          '¿Quitar a ${employee.displayName ?? employee.email} del equipo?',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondaryDark),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Eliminar',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    final result = await _commerceRepo.removeEmployee(
      commerceId: widget.commerceId,
      employeeId: employee.id,
    );
    if (!mounted) return;
    result.fold(
      (f) {
        setState(() => _loading = false);
        _showError('Error al eliminar empleado: ${f.message}');
      },
      (_) => _load(),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAddDialog() {
    _emailController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: Text(
          'Agregar empleado',
          style: AppTextStyles.titleSmall.copyWith(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ingresá el email del usuario que quieras agregar como empleado.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondaryDark),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'email@ejemplo.com',
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondaryDark),
                filled: true,
                fillColor: AppColors.backgroundSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.email_outlined,
                    color: AppColors.textSecondaryDark),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondaryDark),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _addEmployee();
            },
            child: Text(
              'Agregar',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        title: Text(
          'Gestión de empleados',
          style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_outlined, color: Colors.white),
        label: Text(
          'Agregar',
          style: AppTextStyles.titleSmall.copyWith(color: Colors.white),
        ),
      ),
      body: _loading
          ? _buildShimmer()
          : _error != null
              ? _buildError()
              : _buildList(),
    );
  }

  Widget _buildList() {
    if (_employees.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.textSecondaryDark.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Sin empleados registrados',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondaryDark),
            ),
            const SizedBox(height: 8),
            Text(
              'Usá el botón "Agregar" para dar acceso\na un colaborador para escanear cupones.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondaryDark.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: _employees.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildEmployeeTile(_employees[i]),
    );
  }

  Widget _buildEmployeeTile(UserEntity employee) {
    final initials = (employee.displayName?.isNotEmpty == true)
        ? employee.displayName!
            .split(' ')
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : employee.email[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withOpacity(0.15),
            backgroundImage: employee.photoUrl != null
                ? NetworkImage(employee.photoUrl!)
                : null,
            child: employee.photoUrl == null
                ? Text(
                    initials,
                    style: AppTextStyles.titleSmall
                        .copyWith(color: AppColors.primary),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.displayName ?? 'Sin nombre',
                  style: AppTextStyles.titleSmall
                      .copyWith(color: Colors.white),
                ),
                Text(
                  employee.email,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondaryDark),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Empleado',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.success),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                color: AppColors.error, size: 20),
            onPressed: () => _removeEmployee(employee),
            tooltip: 'Eliminar',
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 48,
              color: AppColors.textSecondaryDark.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Error al cargar empleados',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondaryDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _load,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.backgroundCard,
      highlightColor: AppColors.backgroundSurface,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          height: 68,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
