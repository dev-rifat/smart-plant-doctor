import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/features/onboarding/data/farmer_profile_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:plant_health/core/navigation/app_router.dart';
import 'package:plant_health/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:plant_health/features/auth/presentation/cubit/auth_state.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final Future<PackageInfo> _packageInfoFuture;

  /// Name, district and crop from the voice setup (kept on the phone).
  late final Future<FarmerProfile?> _profileFuture =
      getIt<FarmerProfileRepository>().load().catchError((_) => null);

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FarmerProfile?>(
      future: _profileFuture,
      builder: (context, snap) => _build(context, snap.data),
    );
  }

  Widget _build(BuildContext context, FarmerProfile? farmer) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
        farmer?.name ??
        (user?.displayName?.trim().isNotEmpty == true
            ? user!.displayName!
            : 'ব্যবহারকারী');
    final phoneNumber = _phoneFromEmail(user?.email);

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthFailure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }

        if (state is AuthLoggedOut) {
          // Logging out also forgets the voice-setup profile, so the next
          // person on this phone starts with the spoken setup.
          getIt<FarmerProfileRepository>().clear().whenComplete(() {
            if (!context.mounted) return;
            Navigator.of(
              context,
              rootNavigator: true,
            ).pushNamedAndRemoveUntil(AppRouter.onboarding, (route) => false);
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('আমার তথ্য')),
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF4F9F4), Color(0xFFEAF5EC)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: BlocBuilder<AuthCubit, AuthState>(
                        builder: (context, state) {
                          final isLoading = state is AuthLoading;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const CircleAvatar(
                                radius: 38,
                                backgroundColor: Color(0xFFE2F3E6),
                                child: Icon(
                                  Icons.person,
                                  size: 42,
                                  color: Color(0xFF2F8F57),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                displayName,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              if (farmer != null && farmer.district.isNotEmpty)
                                Text(
                                  '${farmer.district} জেলা • ${farmer.primaryCrop} চাষি',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                )
                              else if (phoneNumber != '-')
                                Text(
                                  'নাম্বার: $phoneNumber',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              const SizedBox(height: 18),
                              _ProfileInfoTile(
                                icon: Icons.person_outline_rounded,
                                title: 'নাম',
                                value: displayName,
                              ),
                              if (farmer != null) ...[
                                const SizedBox(height: 10),
                                _ProfileInfoTile(
                                  icon: Icons.location_on_outlined,
                                  title: 'জেলা',
                                  value: farmer.district,
                                ),
                                const SizedBox(height: 10),
                                _ProfileInfoTile(
                                  icon: Icons.grass_rounded,
                                  title: 'প্রধান ফসল',
                                  value: farmer.primaryCrop,
                                ),
                              ],
                              if (phoneNumber != '-') ...[
                                const SizedBox(height: 10),
                                _ProfileInfoTile(
                                  icon: Icons.phone_android_rounded,
                                  title: 'মোবাইল নাম্বার',
                                  value: phoneNumber,
                                ),
                              ],
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        _showLogoutDialog(context);
                                      },
                                icon: isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.logout_rounded),
                                label: const Text('নতুন করে শুরু করুন'),
                              ),
                              const SizedBox(height: 12),
                              FutureBuilder<PackageInfo>(
                                future: _packageInfoFuture,
                                builder: (context, snapshot) => Text(
                                  snapshot.hasData
                                      ? 'কৃষিসাথী সংস্করণ ${snapshot.data!.version}'
                                      : '',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _phoneFromEmail(String? email) {
    if (email == null || !email.contains('@')) return '-';
    return email.split('@').first;
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('নতুন করে শুরু করবেন?'),
        content: const Text(
          'আপনার নাম, জেলা ও ফসলের তথ্য মুছে যাবে। আবার কথা বলে বা লিখে দিতে হবে।',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('বাতিল'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AuthCubit>().logout();
            },
            child: const Text(
              'মুছে ফেলুন',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  const _ProfileInfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FCF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1EEE2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2F8F57)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5E7A64),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF1E4926),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
