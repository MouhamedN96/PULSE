import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool notifications = true;
  bool locationSharing = true;
  bool dataCollection = false;
  bool publicProfile = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Explorer Dossier',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Profile Card
            _buildProfileCard(),
            
            const SizedBox(height: 24),
            
            // Preferences
            _buildPreferencesCard(),
            
            const SizedBox(height: 16),
            
            // Settings
            _buildSettingsCard(),
            
            const SizedBox(height: 16),
            
            // Legal
            _buildLegalCard(),
            
            const SizedBox(height: 32),
            
            // Logout
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded),
                    SizedBox(width: 8),
                    Text('Log Out', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            const Text(
              'STROLL v1.0.0 • Made with 💜',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Cover
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                // Avatar
                Transform.translate(
                  offset: const Offset(0, -56),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).colorScheme.surface, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const CircleAvatar(
                          radius: 46,
                          backgroundImage: NetworkImage(
                            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Alex Chen',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Foodie, traveler, and adventure seeker. Always looking for the next great experience!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_rounded, size: 16, color: Theme.of(context).colorScheme.secondary),
                            const SizedBox(width: 6),
                            const Text(
                              'Shanghai, China',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Column(
                    children: [
                      Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), height: 32),
                      
                      // Stats
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatItem(value: '89', label: 'Experiences'),
                          _StatItem(value: '342', label: 'Followers'),
                          _StatItem(value: '128', label: 'Following'),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Edit Profile
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Edit Dossier'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, color: Theme.of(context).colorScheme.secondary, size: 20),
                const SizedBox(width: 12),
                const Text(
                  'Your Preferences',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: [
                Chip(
                  label: const Text('culinary'),
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  side: BorderSide.none,
                ),
                Chip(
                  label: const Text('wellness'),
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  side: BorderSide.none,
                ),
                Chip(
                  label: const Text('culture'),
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  side: BorderSide.none,
                ),
                ActionChip(
                  label: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  onPressed: () {},
                  backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                  side: BorderSide.none,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_rounded, color: Theme.of(context).colorScheme.secondary, size: 20),
                const SizedBox(width: 12),
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingTile(
              icon: Icons.notifications_active_rounded,
              title: 'Notifications',
              subtitle: 'Alerts for curated activities',
              value: notifications,
              onChanged: (v) => setState(() => notifications = v),
            ),
            Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), height: 32),
            _SettingTile(
              icon: Icons.my_location_rounded,
              title: 'Location Sharing',
              subtitle: 'Crucial for precise routing',
              value: locationSharing,
              onChanged: (v) => setState(() => locationSharing = v),
            ),
            Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), height: 32),
            _SettingTile(
              icon: Icons.security_rounded,
              title: 'Data Collection',
              subtitle: 'Allow AI model to optimize',
              value: dataCollection,
              onChanged: (v) => setState(() => dataCollection = v),
            ),
            Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), height: 32),
            _SettingTile(
              icon: Icons.public_rounded,
              title: 'Public Dossier',
              subtitle: 'Visible to the network',
              value: publicProfile,
              onChanged: (v) => setState(() => publicProfile = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
              children: [
                Icon(Icons.gavel_rounded, color: Theme.of(context).colorScheme.secondary, size: 20),
                const SizedBox(width: 12),
                const Text(
                  'Legal',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _LegalTile(
              icon: Icons.description_rounded,
              title: 'Terms of Service',
              onTap: () {},
            ),
            Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), height: 16),
            _LegalTile(
              icon: Icons.privacy_tip_rounded,
              title: 'Privacy Policy',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }
}

class _LegalTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _LegalTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white38,
            ),
          ],
        ),
      ),
    );
  }
}
